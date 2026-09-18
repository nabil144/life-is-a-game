import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A shallow ownership tree laid out as four outward-growing, grid-aligned regions.
/// Independent of the viewport and selection; no physics or per-frame layout work.
public struct WorldLayout: Sendable {
    public struct Input: Equatable, Sendable {
        public var id: UUID
        public var work: [UUID]
        public init(id: UUID, work: [UUID]) { self.id = id; self.work = work }
    }
    public struct Room: Identifiable, Sendable {
        public var id: String
        public var pathID: UUID?
        public var workID: UUID?
        public var center: CGPoint
        public var frame: CGRect {
            CGRect(x: center.x - 68, y: center.y - 36, width: 136, height: 72)
        }
    }
    public struct Corridor: Sendable {
        public var pathID: UUID
        public var workID: UUID?
        public var points: [CGPoint]
    }
    public var rooms: [Room] = []
    public var corridors: [Corridor] = []
    public var size: CGSize = .zero
    public var center: CGPoint = .zero

    public init(paths: [Input]) {
        struct Lane {
            var input: Input
            var side: Int
            var values: [CGFloat]
            var parentY: CGFloat
            var columns: [Int]
            var rank: Int
            var rankCount: Int
        }
        func noise(_ id: UUID) -> Int {
            Int(id.uuidString.utf8.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1)) &* 1099511628211 } % 997)
        }
        func station(_ index: Int, salt: Int) -> (row: Int, column: Int) {
            var shell = 0, remaining = index
            while remaining > shell { remaining -= shell + 1; shell += 1 }
            let row = salt % 2 == 0 ? remaining : shell - remaining
            return (row, shell - row)
        }
        var lanes: [Lane] = []
        for side in 0..<4 {
            let group = paths.enumerated().filter { $0.offset % 4 == side }.map(\.element)
            let pitch: CGFloat = side % 2 == 0 ? 104 : 168
            var ends: [CGFloat] = [0, 0]
            for (index, input) in group.enumerated() {
                let count = max(1, input.work.count)
                let stations = (0..<count).map { station($0, salt: noise(input.id)) }
                let maxRow = stations.map(\.row).max() ?? 0
                var rowOffsets: [CGFloat] = [0]
                if maxRow > 0 {
                    for row in 1...maxRow {
                        rowOffsets.append(rowOffsets.last! + pitch + CGFloat((noise(input.id) + row * 7) % 3 * 8))
                    }
                }
                let offsets = stations.map { rowOffsets[$0.row] + 16 }
                let columns = stations.map(\.column)
                if group.count == 1 {
                    let sign: CGFloat = noise(input.id) % 2 == 0 ? 1 : -1
                    let parentY = sign * CGFloat(16 + noise(input.id) % 3 * 8)
                    let values = offsets.map { parentY + sign * $0 }
                    lanes.append(Lane(input: input, side: side, values: values, parentY: parentY, columns: columns, rank: 0, rankCount: 1))
                } else {
                    let signIndex = index % 2
                    let sign: CGFloat = signIndex == 0 ? 1 : -1
                    let rank = index / 2
                    let parentY = (CGFloat(rank) + 0.5) * pitch
                    let start = max(parentY, ends[signIndex])
                    let values = offsets.map { sign * (start + $0) }
                    ends[signIndex] = start + (offsets.max() ?? 0) + pitch * 2
                    lanes.append(Lane(input: input, side: side, values: values,
                                      parentY: sign * parentY, columns: columns, rank: rank, rankCount: (group.count + 1) / 2))
                }
            }
        }
        // Only the number of PATH rooms determines their distance from You.
        // Crowded quest fans expand the outer layer, never this inner layer.
        let parentExtent = lanes.map { abs($0.parentY) }.max() ?? 0
        let radius = max(160, parentExtent + 112)
        func rotate(_ x: CGFloat, _ y: CGFloat, _ side: Int) -> CGPoint {
            switch side {
            case 0: return CGPoint(x: x, y: y)
            case 1: return CGPoint(x: -y, y: x)
            case 2: return CGPoint(x: -x, y: -y)
            default: return CGPoint(x: y, y: -x)
            }
        }
        rooms.append(Room(id: "you", center: .zero))
        for lane in lanes {
            let y = lane.parentY
            let pathRadius = radius + CGFloat(noise(lane.input.id) % 4 * 8)
            let at = rotate(pathRadius, y, lane.side)
            rooms.append(Room(id: "path-\(lane.input.id)", pathID: lane.input.id, center: at))
            corridors.append(Corridor(pathID: lane.input.id, points: [
                .zero, rotate(radius - 80, 0, lane.side), rotate(radius - 80, y, lane.side), at
            ]))
            for (index, work) in lane.input.work.enumerated() {
                let sign: CGFloat = lane.values[index] >= 0 ? 1 : -1
                let corridorY = lane.values[index]
                let offset: CGFloat = lane.side % 2 == 0 ? 52 : 84
                let targetY = corridorY + sign * (offset + CGFloat(noise(work) % 2 * 8))
                // Follow a narrow outward staircase, then branch sideways into a room.
                // Its reach depends on THIS quest, never the widest fan elsewhere.
                let startX = pathRadius + 80 + CGFloat(lane.rankCount - lane.rank - 1) * 48
                var points = [at, rotate(startX, y, lane.side)]
                var currentY = y
                var currentX = startX
                while abs(corridorY - currentY) > 0.001 {
                    let step = min(16, abs(corridorY - currentY))
                    currentY += sign * step
                    points.append(rotate(currentX, currentY, lane.side))
                    currentX = startX + max(0, abs(currentY - y) - 128)
                    points.append(rotate(currentX, currentY, lane.side))
                }
                let columnPitch: CGFloat = lane.side % 2 == 0 ? 176 : 112
                let halfAlong: CGFloat = lane.side % 2 == 0 ? 68 : 36
                let halfAcross: CGFloat = lane.side % 2 == 0 ? 36 : 68
                let stemClearance = max(0, abs(targetY - y) + halfAcross - 128)
                let targetX = startX + stemClearance + halfAlong + 16
                    + CGFloat(lane.columns[index]) * columnPitch + CGFloat(noise(work) % 3 * 8)
                let target = rotate(targetX, targetY, lane.side)
                points.append(rotate(targetX, corridorY, lane.side))
                points.append(target)
                rooms.append(Room(id: "work-\(work)", pathID: lane.input.id, workID: work, center: target))
                corridors.append(Corridor(pathID: lane.input.id, workID: work, points: points))
            }
        }

        let bounds = rooms.reduce(CGRect.null) { $0.union($1.frame) }.insetBy(dx: -64, dy: -64)
        center = CGPoint(x: -bounds.minX, y: -bounds.minY)
        size = bounds.size
        for i in rooms.indices {
            rooms[i].center.x += center.x
            rooms[i].center.y += center.y
        }
        for i in corridors.indices {
            corridors[i].points = corridors[i].points.map {
                CGPoint(x: $0.x + center.x, y: $0.y + center.y)
            }
        }
    }
}
