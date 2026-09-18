import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import LifeEngine

final class WorldMazeTests: XCTestCase {
    private func inputs(_ counts: [Int]) -> [WorldLayout.Input] {
        var number = 1
        func id() -> UUID {
            defer { number += 1 }
            return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
        }
        return counts.map { count in .init(id: id(), work: (0..<count).map { _ in id() }) }
    }
    private func contains(_ point: CGPoint, on route: [CGPoint]) -> Bool {
        zip(route, route.dropFirst()).contains { a, b in
            (point.x == a.x && a.x == b.x && point.y >= min(a.y,b.y) && point.y <= max(a.y,b.y)) ||
            (point.y == a.y && a.y == b.y && point.x >= min(a.x,b.x) && point.x <= max(a.x,b.x))
        }
    }
    private func key(_ p: CGPoint) -> String { "\(Int(p.x * 2)),\(Int(p.y * 2))" }
    private func samples(_ a: CGPoint, _ b: CGPoint) -> [CGPoint] {
        let steps = Int(abs(a.x-b.x) + abs(a.y-b.y)) / 4
        guard steps > 0 else { return [] }
        return (0..<steps).map { i in
            let t = (CGFloat(i) + 0.5) / CGFloat(steps)
            return CGPoint(x: a.x+(b.x-a.x)*t, y: a.y+(b.y-a.y)*t)
        }
    }
    func testEveryDestinationUsesItsOwnPathAndVisibleMaze() {
        for counts in [[], [0], [3], [2,5,0,3,1], [8,1,2,4,0,3,2,1], [30,2,1,0], Array(repeating: 8, count: 12)] {
            let layout = WorldLayout(paths: inputs(counts))
            let maze = WorldMaze(layout: layout)
            XCTAssertEqual(maze.routes.count, layout.rooms.count, "\(counts)")
            XCTAssertFalse(maze.segments.isEmpty, "The empty world also has a maze")
            let visible = Set(maze.segments.flatMap { segment in
                samples(segment.from, segment.to).map(key)
            })
            for room in layout.rooms {
                guard let route = maze.routes[room.id] else { continue }
                XCTAssertEqual(route.first, layout.center)
                XCTAssertEqual(route.last, room.center)
                if room.workID != nil, let parent = layout.rooms.first(where: { $0.pathID == room.pathID && $0.workID == nil }) {
                    XCTAssertTrue(contains(parent.center, on: route), "Quest route bypassed its path")
                }
                for (a,b) in zip(route,route.dropFirst()) {
                    XCTAssertTrue(a.x == b.x || a.y == b.y)
                    let length = Int(abs(a.x-b.x) + abs(a.y-b.y)) / 4
                    guard length > 0 else { continue }
                    for i in 0..<length {
                        let t = (CGFloat(i) + 0.5) / CGFloat(length)
                        let point = CGPoint(x: a.x+(b.x-a.x)*t, y: a.y+(b.y-a.y)*t)
                        XCTAssertTrue(visible.contains(key(point)), "Highlight left the maze")
                    }
                }
            }
        }
    }
    func testDeterministicAndWinding() {
        let layout = WorldLayout(paths: inputs([4,3,5,2]))
        let maze = WorldMaze(layout: layout)
        XCTAssertEqual(maze.segments, WorldMaze(layout: layout).segments)
        XCTAssertEqual(maze.routes, WorldMaze(layout: layout).routes)
        func length(_ points: [CGPoint]) -> CGFloat {
            var total: CGFloat = 0
            for (a,b) in zip(points,points.dropFirst()) { total += abs(a.x-b.x) + abs(a.y-b.y) }
            return total
        }
        var longer = 0
        for room in layout.rooms where room.pathID != nil {
            let old = layout.corridors.filter { $0.pathID == room.pathID && ($0.workID == nil || $0.workID == room.workID) }
            let direct = old.reduce(CGFloat(0)) { $0 + length($1.points) }
            if length(maze.routes[room.id] ?? []) > direct + 16 { longer += 1 }
        }
        XCTAssertGreaterThan(longer, 0, "Journeys should include deliberate detours")
    }

    func testMazeIsOneTreeAndFillsOpenSpace() {
        let layout = WorldLayout(paths: inputs([3,5,2,4]))
        let maze = WorldMaze(layout: layout)
        var graph: [String: Set<String>] = [:]
        for segment in maze.segments {
            let steps = Int(abs(segment.to.x-segment.from.x) + abs(segment.to.y-segment.from.y)) / 4
            var last = key(segment.from)
            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let next = key(CGPoint(x: segment.from.x+(segment.to.x-segment.from.x)*t,
                                       y: segment.from.y+(segment.to.y-segment.from.y)*t))
                graph[last, default: []].insert(next); graph[next, default: []].insert(last)
                last = next
            }
        }
        var reached = Set<String>(), stack = [key(layout.center)]
        while let at = stack.popLast() {
            if reached.insert(at).inserted { stack.append(contentsOf: graph[at] ?? []) }
        }
        XCTAssertEqual(reached.count, graph.count, "No disconnected decorative fragments")
        XCTAssertEqual(graph.values.reduce(0) { $0 + $1.count } / 2, graph.count - 1, "Exactly one route to every point")
        var open = 0, filled = 0
        for y in stride(from: 12, to: Int(layout.size.height)-12, by: 24) {
            for x in stride(from: 12, to: Int(layout.size.width)-12, by: 24) {
                let p = CGPoint(x: x, y: y)
                guard !layout.rooms.contains(where: { $0.frame.insetBy(dx: -16, dy: -16).contains(p) }) else { continue }
                open += 1
                if maze.segments.contains(where: { segment in
                    CGRect(x: min(segment.from.x,segment.to.x), y: min(segment.from.y,segment.to.y),
                           width: abs(segment.to.x-segment.from.x), height: abs(segment.to.y-segment.from.y))
                        .insetBy(dx: -20, dy: -20).contains(p)
                }) { filled += 1 }
            }
        }
        XCTAssertGreaterThan(Double(filled) / Double(open), 0.95)
    }

    func testLargeWorldIsBounded() {
        let layout = WorldLayout(paths: inputs(Array(repeating: 50, count: 20)))
        let start = Date()
        let maze = WorldMaze(layout: layout)
        print("1000-item maze: \(Date().timeIntervalSince(start))s, \(maze.segments.count) segments")
        XCTAssertEqual(maze.routes.count, layout.rooms.count)
        XCTAssertLessThan(maze.segments.count, 40000)
    }
}
