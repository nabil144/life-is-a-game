import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A bounded, deterministic maze forest in unused space. Never an interactive route.
public struct WorldDecoration {
    public struct Segment: Equatable {
        public var from: CGPoint
        public var to: CGPoint
    }
    public var segments: [Segment] = []

    public init(layout: WorldLayout) {
        // Coarsen very large worlds instead of allocating an unbounded background.
        let step = max(24, ceil(sqrt(layout.size.width * layout.size.height / 8000) / 8) * 8)
        let columns = max(1, Int(layout.size.width / step))
        let rows = max(1, Int(layout.size.height / step))
        var blocked = Array(repeating: false, count: columns * rows)
        func point(_ index: Int) -> CGPoint {
            CGPoint(x: (CGFloat(index % columns) + 0.5) * step,
                    y: (CGFloat(index / columns) + 0.5) * step)
        }
        func block(_ rect: CGRect) {
            let x0 = max(0, Int(floor(rect.minX / step)))
            let x1 = min(columns - 1, Int(floor(rect.maxX / step)))
            let y0 = max(0, Int(floor(rect.minY / step)))
            let y1 = min(rows - 1, Int(floor(rect.maxY / step)))
            guard x0 <= x1, y0 <= y1 else { return }
            for y in y0...y1 { for x in x0...x1 { blocked[y * columns + x] = true } }
        }
        for room in layout.rooms { block(room.frame.insetBy(dx: -16, dy: -16)) }
        for edge in layout.corridors {
            for (a, b) in zip(edge.points, edge.points.dropFirst()) {
                block(CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                             width: abs(a.x-b.x), height: abs(a.y-b.y)).insetBy(dx: -14, dy: -14))
            }
        }
        var visited = blocked
        var seed: UInt64 = 0x4C494645
        func next(_ count: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int((seed >> 32) % UInt64(count))
        }
        // Iterative depth-first traversal gives branching corridors and dead ends,
        // without recursive stack growth or a per-frame random generator.
        for start in visited.indices where !visited[start] {
            visited[start] = true
            var stack = [start]
            while let current = stack.last {
                let x = current % columns, y = current / columns
                var candidates: [Int] = []
                if x > 0 && !visited[current - 1] { candidates.append(current - 1) }
                if x + 1 < columns && !visited[current + 1] { candidates.append(current + 1) }
                if y > 0 && !visited[current - columns] { candidates.append(current - columns) }
                if y + 1 < rows && !visited[current + columns] { candidates.append(current + columns) }
                guard !candidates.isEmpty else { stack.removeLast(); continue }
                let target = candidates[next(candidates.count)]
                visited[target] = true
                segments.append(Segment(from: point(current), to: point(target)))
                stack.append(target)
            }
        }
    }
}
