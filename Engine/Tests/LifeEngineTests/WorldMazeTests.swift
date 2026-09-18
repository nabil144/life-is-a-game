import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import LifeEngine

final class WorldMazeTests: XCTestCase {
    private func inputs(_ counts: [Int], salt: Int = 0) -> [WorldLayout.Input] {
        var number = 1 + salt*10000
        func id() -> UUID {
            defer { number += 1 }
            return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
        }
        return counts.map { count in .init(id: id(), work: (0..<count).map { _ in id() }) }
    }
    private func lies(_ point: CGPoint, on route: [CGPoint]) -> Bool {
        zip(route,route.dropFirst()).contains { a,b in
            (point.x == a.x && a.x == b.x && point.y >= min(a.y,b.y) && point.y <= max(a.y,b.y)) ||
            (point.y == a.y && a.y == b.y && point.x >= min(a.x,b.x) && point.x <= max(a.x,b.x))
        }
    }
    private func key(_ p: CGPoint) -> String { "\(Int(p.x)),\(Int(p.y))" }
    private func wallCenters(_ maze: WorldMaze) -> Set<String> {
        var result = Set<String>()
        for wall in maze.walls {
            let steps = Int((abs(wall.from.x-wall.to.x)+abs(wall.from.y-wall.to.y))/maze.cellSize)
            for i in 0..<steps {
                let t = (CGFloat(i)+0.5)/CGFloat(steps)
                result.insert(key(CGPoint(x: wall.from.x+(wall.to.x-wall.from.x)*t,y: wall.from.y+(wall.to.y-wall.from.y)*t)))
            }
        }
        return result
    }
    func testJourneysTraverseFloorThroughTheirOwnPath() {
        for counts in [[], [0], [3], [2,5,0,3,1], [8,1,2,4,0,3,2,1], [30,2,1,0], Array(repeating: 8,count: 12)] {
            for salt in 0..<3 {
                let layout = WorldLayout(paths: inputs(counts,salt: salt))
                let maze = WorldMaze(layout: layout)
                XCTAssertEqual(maze.routes.count,layout.rooms.count)
                XCTAssertTrue(maze.ownershipRouted)
                let barriers = wallCenters(maze)
                for room in layout.rooms {
                    guard let route = maze.routes[room.id], let bounds = maze.roomFrames[room.id] else { XCTFail(); continue }
                    XCTAssertEqual(route.last,CGPoint(x: bounds.midX,y: bounds.midY))
                    if room.workID != nil, let parent = maze.roomFrames["path-\(room.pathID!)"] {
                        XCTAssertTrue(lies(CGPoint(x: parent.midX,y: parent.midY),on: route), "Bypassed parent: \(counts), salt \(salt), \(room.id)")
                    }
                    for (a,b) in zip(route,route.dropFirst()) {
                        XCTAssertTrue(a.x == b.x || a.y == b.y)
                        let steps = Int((abs(a.x-b.x)+abs(a.y-b.y))/maze.cellSize)
                        for i in 0..<steps {
                            let t = (CGFloat(i)+0.5)/CGFloat(steps)
                            let midpoint = CGPoint(x: a.x+(b.x-a.x)*t,y: a.y+(b.y-a.y)*t)
                            XCTAssertFalse(barriers.contains(key(midpoint)),"Highlight crosses a wall")
                        }
                        // Cell centers are 8 points from their side walls; a 12-point
                        // floor highlight leaves clearance on both sides.
                        XCTAssertEqual(a.x.truncatingRemainder(dividingBy: maze.cellSize),maze.cellSize/2)
                        XCTAssertEqual(a.y.truncatingRemainder(dividingBy: maze.cellSize),maze.cellSize/2)
                    }
                }
            }
        }
    }
    func testOneRouteToEveryCellAndClosedWallsMatchDoors() {
        let maze = WorldMaze(layout: WorldLayout(paths: inputs([3,5,2,4])))
        let barriers = wallCenters(maze)
        var graph: [Int: Set<Int>] = [:]
        for owner in maze.owners { graph[owner] = [] }
        for door in maze.passages {
            let a = maze.owners[door.a], b = maze.owners[door.b]
            graph[a,default: []].insert(b); graph[b,default: []].insert(a)
            let center = CGPoint(x: (maze.center(of: door.a).x+maze.center(of: door.b).x)/2,
                                 y: (maze.center(of: door.a).y+maze.center(of: door.b).y)/2)
            XCTAssertFalse(barriers.contains(key(center)))
        }
        var seen = Set<Int>(), stack = [maze.owners[0]]
        while let at = stack.popLast() { if seen.insert(at).inserted { stack.append(contentsOf: graph[at] ?? []) } }
        XCTAssertEqual(seen.count,graph.count)
        XCTAssertEqual(maze.passages.count,graph.count-1,"One traversable route, no loops")
        let open = Set(maze.passages.map { "\(min($0.a,$0.b)),\(max($0.a,$0.b))" })
        for cell in maze.owners.indices {
            for next in [cell+1,cell+maze.columns] where next < maze.owners.count {
                if next == cell+1 && next/maze.columns != cell/maze.columns { continue }
                if maze.owners[cell] == maze.owners[next] { continue }
                let point = CGPoint(x: (maze.center(of: cell).x+maze.center(of: next).x)/2,
                                    y: (maze.center(of: cell).y+maze.center(of: next).y)/2)
                let hasWall = barriers.contains(key(point))
                XCTAssertEqual(hasWall,!open.contains("\(cell),\(next)"))
            }
        }
    }
    func testDeterministicAndWinding() {
        let layout = WorldLayout(paths: inputs([4,3,5,2]))
        let maze = WorldMaze(layout: layout), again = WorldMaze(layout: layout)
        XCTAssertEqual(maze.walls,again.walls)
        XCTAssertEqual(maze.passages,again.passages)
        XCTAssertEqual(maze.routes,again.routes)
        XCTAssertTrue(maze.routes.values.contains { route in
            guard let a = route.first,let b = route.last else { return false }
            var distance: CGFloat = 0
            for (x,y) in zip(route,route.dropFirst()) { distance += abs(x.x-y.x)+abs(x.y-y.y) }
            return distance > abs(a.x-b.x)+abs(a.y-b.y)+maze.cellSize*4
        })
        let frames = Array(maze.roomFrames.values)
        for (i,frame) in frames.enumerated() { for other in frames.dropFirst(i+1) {
            XCTAssertFalse(frame.insetBy(dx: 0.1,dy: 0.1).intersects(other))
        } }
    }
    func testVariedFamiliesKeepTheirGateways() {
        for salt in 0..<24 {
            let counts = (0..<(salt%12+1)).map { ($0*7+salt*3)%17 }
            let layout = WorldLayout(paths: inputs(counts,salt: salt+10))
            let maze = WorldMaze(layout: layout)
            XCTAssertTrue(maze.ownershipRouted,"\(counts), salt \(salt)")
            for room in layout.rooms where room.workID != nil {
                let parent = maze.roomFrames["path-\(room.pathID!)"]!
                XCTAssertTrue(lies(CGPoint(x: parent.midX,y: parent.midY),on: maze.routes[room.id] ?? []))
            }
        }
    }
    func testLargeWorld() {
        let layout = WorldLayout(paths: inputs(Array(repeating: 50,count: 20)))
        let start = Date(), maze = WorldMaze(layout: layout)
        print("1000-item walled maze: \(Date().timeIntervalSince(start))s, \(maze.walls.count) walls")
        XCTAssertEqual(maze.routes.count,layout.rooms.count)
        XCTAssertTrue(maze.ownershipRouted)
        XCTAssertLessThan(maze.walls.count,100000)
        for room in layout.rooms where room.workID != nil {
            let parent = maze.roomFrames["path-\(room.pathID!)"]!
            XCTAssertTrue(lies(CGPoint(x: parent.midX,y: parent.midY),on: maze.routes[room.id] ?? []),"Bypassed parent in large world")
        }
    }
}
