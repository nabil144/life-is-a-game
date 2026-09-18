import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Shared route prefixes light once; branches begin when the light reaches their junction.
public struct WorldReveal: Sendable {
    public struct Stroke: Sendable {
        public var points: [CGPoint]
        public var start: CGFloat
        public var length: CGFloat
    }
    public var strokes: [Stroke] = []
    public var distance: CGFloat = 0

    private struct Point: Hashable {
        var x: Int
        var y: Int
        init(_ point: CGPoint) { x = Int(point.x.rounded()); y = Int(point.y.rounded()) }
        var cg: CGPoint { CGPoint(x: x,y: y) }
    }
    private struct Branch {
        var at: Point
        var distance: CGFloat
        var children: [Point: Int] = [:]
        var order: [Int] = []
    }

    public init(routes: [[CGPoint]], step: CGFloat = 16) {
        guard let first = routes.first?.first else { return }
        var tree = [Branch(at: Point(first), distance: 0)]
        for route in routes where route.first == first {
            var node = 0
            for (a,b) in zip(route,route.dropFirst()) {
                let length = abs(a.x-b.x)+abs(a.y-b.y)
                guard length > 0 else { continue }
                let count = max(1,Int(ceil(length/step)))
                for i in 1...count {
                    let fraction = CGFloat(i)/CGFloat(count)
                    let point = Point(CGPoint(x: a.x+(b.x-a.x)*fraction,y: a.y+(b.y-a.y)*fraction))
                    if let existing = tree[node].children[point] { node = existing }
                    else {
                        let index = tree.count
                        let travel = abs(point.cg.x-tree[node].at.cg.x)+abs(point.cg.y-tree[node].at.cg.y)
                        let distance = tree[node].distance+travel
                        tree[node].children[point] = index; tree[node].order.append(index)
                        tree.append(Branch(at: point,distance: distance)); node = index
                    }
                }
            }
        }
        for index in tree.indices where index == 0 || tree[index].order.count != 1 {
            for child in tree[index].order {
                var points = [tree[index].at.cg,tree[child].at.cg], end = child
                while tree[end].order.count == 1 {
                    end = tree[end].order[0]
                    let point = tree[end].at.cg
                    let a = points[points.count-2], b = points[points.count-1]
                    if ((a.x == b.x && b.x == point.x) || (a.y == b.y && b.y == point.y)),
                       (b.x-a.x)*(point.x-b.x)+(b.y-a.y)*(point.y-b.y) >= 0 { points.removeLast() }
                    points.append(point)
                }
                let finish = tree[end].distance
                strokes.append(Stroke(points: points,start: tree[index].distance,length: finish-tree[index].distance))
                distance = max(distance,finish)
            }
        }
    }
}
