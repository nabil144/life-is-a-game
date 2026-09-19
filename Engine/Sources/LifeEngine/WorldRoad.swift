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
        self.init(points: Array(incoming.reversed()))
    }

    public init(points: [CGPoint]) {
        self.points = []
        for point in points where self.points.last != point { self.points.append(point) }
        distances = self.points.isEmpty ? [] : [0]
        for (a,b) in zip(self.points,self.points.dropFirst()) {
            distances.append((distances.last ?? 0) + hypot(b.x-a.x,b.y-a.y))
        }
    }

    public func position(at distance: CGFloat) -> CGPoint? {
        guard let first = points.first else { return nil }
        if distance <= 0 { return first }
        if distance >= length { return points.last }
        var low = 1, high = distances.count - 1
        while low < high {
            let mid = (low + high) / 2
            if distances[mid] < distance { low = mid + 1 } else { high = mid }
        }
        let a = points[low-1], b = points[low]
        let t = (distance-distances[low-1]) / (distances[low]-distances[low-1])
        return CGPoint(x: a.x+(b.x-a.x)*t,y: a.y+(b.y-a.y)*t)
    }

    /// Reverse only the distance already travelled, preserving every corridor corner.
    public func returning(after distance: CGFloat) -> WorldRoad {
        guard let first = points.first else { return WorldRoad(points: []) }
        let target = min(length, max(0, distance))
        var prefix = [first]
        for index in 1..<points.count {
            if distances[index] <= target { prefix.append(points[index]); continue }
            let a = points[index-1], b = points[index]
            let t = (target-distances[index-1]) / (distances[index]-distances[index-1])
            prefix.append(CGPoint(x: a.x+(b.x-a.x)*t,y: a.y+(b.y-a.y)*t))
            break
        }
        return WorldRoad(points: Array(prefix.reversed()))
    }
}
