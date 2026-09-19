import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A single corridor journey, trimmed so the traveller stays outside both rooms.
public struct WorldRoad: Sendable {
    public var points: [CGPoint]
    public var distances: [CGFloat]
    public var length: CGFloat { distances.last ?? 0 }

    public init(points: [CGPoint], source: CGRect, destination: CGRect, clearance: CGFloat = 6) {
        func trim(_ points: [CGPoint], outside rect: CGRect) -> [CGPoint] {
            var result = points
            while result.count > 1, rect.contains(result[0]) {
                let a = result[0], b = result[1]
                if rect.contains(b) { result.removeFirst(); continue }
                let dx = b.x-a.x, dy = b.y-a.y
                var t: CGFloat = 1
                if dx > 0 { t = min(t, (rect.maxX-a.x)/dx) }
                if dx < 0 { t = min(t, (rect.minX-a.x)/dx) }
                if dy > 0 { t = min(t, (rect.maxY-a.y)/dy) }
                if dy < 0 { t = min(t, (rect.minY-a.y)/dy) }
                result[0] = CGPoint(x: a.x+dx*t,y: a.y+dy*t)
                break
            }
            return result
        }
        let outgoing = trim(points, outside: source.insetBy(dx: -clearance,dy: -clearance))
        let incoming = trim(Array(outgoing.reversed()), outside: destination.insetBy(dx: -clearance,dy: -clearance))
        self.points = []
        for point in incoming.reversed() where self.points.last != point { self.points.append(point) }
        distances = self.points.isEmpty ? [] : [0]
        for (a,b) in zip(self.points,self.points.dropFirst()) {
            distances.append((distances.last ?? 0) + hypot(b.x-a.x,b.y-a.y))
        }
    }
}
