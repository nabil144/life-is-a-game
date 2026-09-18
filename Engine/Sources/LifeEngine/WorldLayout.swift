import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A shallow ownership tree laid out as four outward-growing, grid-aligned regions.
/// Independent of the viewport and selection; no physics or per-frame layout work.
public struct WorldLayout {
    public struct Input: Equatable {
        public var id: UUID
        public var work: [UUID]
        public init(id: UUID, work: [UUID]) { self.id = id; self.work = work }
    }
    public struct Room: Identifiable {
        public var id: String
        public var pathID: UUID?
        public var workID: UUID?
        public var center: CGPoint
        public var frame: CGRect {
            CGRect(x: center.x - 68, y: center.y - 36, width: 136, height: 72)
        }
    }
    public struct Corridor {
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
            var rank: Int
        }
        var lanes: [Lane] = []
        for side in 0..<4 {
            let group = paths.enumerated().filter { $0.offset % 4 == side }.map(\.element)
            let pitch: CGFloat = side % 2 == 0 ? 96 : 152
            var ends: [CGFloat] = [0, 0]
            for (index, input) in group.enumerated() {
                let count = max(1, input.work.count)
                if group.count == 1 {
                    let values = (0..<count).map { (CGFloat($0) - CGFloat(count - 1) / 2) * pitch }
                    lanes.append(Lane(input: input, side: side, values: values, parentY: 0, rank: 0))
                } else {
                    let signIndex = index % 2
                    let sign: CGFloat = signIndex == 0 ? 1 : -1
                    let rank = index / 2
                    let parentY = (CGFloat(rank) + 0.5) * pitch
                    let start = max(parentY, ends[signIndex])
                    let values = (0..<count).map { sign * (start + CGFloat($0) * pitch) }
                    ends[signIndex] = start + CGFloat(count + 1) * pitch
                    lanes.append(Lane(input: input, side: side, values: values,
                                      parentY: sign * parentY, rank: rank))
                }
            }
        }
        // Only the number of PATH rooms determines their distance from You.
        // Crowded quest fans expand the outer layer, never this inner layer.
        let parentExtent = lanes.map { abs($0.parentY) }.max() ?? 0
        let radius = max(160, parentExtent + 112)
        let childExtent = lanes.flatMap(\.values).map { abs($0) }.max() ?? 0
        let outerBase = max(radius + 96, childExtent + 112)
        let ranks = (lanes.map(\.rank).max() ?? 0) + 1
        let outerEdge = outerBase + CGFloat(ranks - 1) * 24 + 96
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
            // Nested lanes let compressed parents reach disjoint outer fans without crossing.
            let trunk = outerBase + CGFloat(ranks - lane.rank - 1) * 24
            let at = rotate(radius, y, lane.side)
            rooms.append(Room(id: "path-\(lane.input.id)", pathID: lane.input.id, center: at))
            corridors.append(Corridor(pathID: lane.input.id, points: [
                .zero, rotate(radius - 80, 0, lane.side), rotate(radius - 80, y, lane.side), at
            ]))
            for (index, work) in lane.input.work.enumerated() {
                let target = rotate(outerEdge, lane.values[index], lane.side)
                rooms.append(Room(id: "work-\(work)", pathID: lane.input.id, workID: work, center: target))
                corridors.append(Corridor(pathID: lane.input.id, workID: work, points: [
                    at, rotate(trunk, y, lane.side),
                    rotate(trunk, lane.values[index], lane.side), target
                ]))
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
