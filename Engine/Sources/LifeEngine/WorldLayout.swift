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
        }
        var lanes: [Lane] = []
        for side in 0..<4 {
            let group = paths.enumerated().filter { $0.offset % 4 == side }.map(\.element)
            let slots = group.reduce(0) { $0 + max(1, $1.work.count) + 1 }
            var cursor = -CGFloat(max(0, slots - 2)) * 80
            for input in group {
                let count = max(1, input.work.count)
                let values = (0..<count).map { cursor + CGFloat($0) * 160 }
                lanes.append(Lane(input: input, side: side, values: values))
                cursor += CGFloat(count + 1) * 160
            }
        }
        let extent = lanes.flatMap(\.values).map { abs($0) }.max() ?? 0
        let radius = max(256, extent + 224)
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
            let lo = lane.values.first!, hi = lane.values.last!
            // Closest transverse point to You: every child then travels outward.
            let y: CGFloat = lo > 0 ? lo : (hi < 0 ? hi : 0)
            let at = rotate(radius, y, lane.side)
            rooms.append(Room(id: "path-\(lane.input.id)", pathID: lane.input.id, center: at))
            corridors.append(Corridor(pathID: lane.input.id, points: [
                .zero, rotate(radius - 96, 0, lane.side), rotate(radius - 96, y, lane.side), at
            ]))
            for (index, work) in lane.input.work.enumerated() {
                let target = rotate(radius + 288, lane.values[index], lane.side)
                rooms.append(Room(id: "work-\(work)", pathID: lane.input.id, workID: work, center: target))
                corridors.append(Corridor(pathID: lane.input.id, workID: work, points: [
                    at, rotate(radius + 144, y, lane.side),
                    rotate(radius + 144, lane.values[index], lane.side), target
                ]))
            }
        }
        let bounds = rooms.reduce(CGRect.null) { $0.union($1.frame) }.insetBy(dx: -96, dy: -96)
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
