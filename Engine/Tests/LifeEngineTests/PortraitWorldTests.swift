import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import LifeEngine

final class PortraitWorldTests: XCTestCase {
    private func inputs(_ count: Int) -> [WorldLayout.Input] {
        (0..<count).map { .init(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0 + 1))!, work: []) }
    }

    func testRoomRoadsNeverShareFloorOutsideTheirCenter() {
        for compact in [true,false] {
            for count in compact ? [1,4,9,16,20] : [4,9,16,24,28] {
                let maze = WorldMaze(layout: WorldLayout(paths: inputs(count),portrait: true,compactCenter: compact))
                XCTAssertTrue(maze.separateRoadsRouted,"Count: \(count), compact: \(compact)")
                let root = maze.roomFrames["you"]!
                var claimed: [Int:String] = [:]
                for (id, route) in maze.routes where id != "you" {
                    for (a,b) in zip(route,route.dropFirst()) {
                        let steps = Int((abs(a.x-b.x)+abs(a.y-b.y))/maze.cellSize)
                        for i in 0...max(1,steps) {
                            let t = CGFloat(i)/CGFloat(max(1,steps))
                            let point = CGPoint(x: a.x+(b.x-a.x)*t,y: a.y+(b.y-a.y)*t)
                            if root.contains(point) { continue }
                            let cell = Int(point.y/maze.cellSize)*maze.columns+Int(point.x/maze.cellSize)
                            let owner = maze.owners[cell]
                            if let existing = claimed[owner] { XCTAssertEqual(existing,id,"Room roads share floor") }
                            claimed[owner] = id
                        }
                    }
                }
            }
        }
    }

    func testExhaustedDoorwaysKeepEveryRoomReachable() {
        let maze = WorldMaze(layout: WorldLayout(paths: inputs(24),portrait: true,compactCenter: true))
        XCTAssertTrue(maze.ownershipRouted)
        XCTAssertFalse(maze.separateRoadsRouted)
        XCTAssertEqual(maze.routes.count,25)
    }

    func testBrainChamberIsCompactWhileTextChambersKeepTheirSize() {
        let destinations = inputs(4)
        let world = WorldMaze(layout: WorldLayout(paths: destinations, portrait: true, compactCenter: true))
        let inner = WorldMaze(layout: WorldLayout(paths: destinations, portrait: true))
        XCTAssertEqual(world.roomFrames["you"]?.size, CGSize(width: 80, height: 80))
        XCTAssertEqual(inner.roomFrames["you"]?.size, CGSize(width: 144, height: 80))
        XCTAssertEqual(world.roomFrames["you"]?.midX, world.size.width / 2)
        XCTAssertEqual(world.roomFrames["you"]?.midY, world.size.height / 2)
        XCTAssertTrue(world.ownershipRouted)
        XCTAssertEqual(world.routes.count, 5)
        for destination in destinations {
            XCTAssertEqual(world.roomFrames["path-\(destination.id)"]?.size, CGSize(width: 144, height: 80))
        }
    }

    func testFourDestinationsSurroundCenterDiagonally() {
        let layout = WorldLayout(paths: inputs(4), portrait: true)
        XCTAssertGreaterThan(layout.size.height, layout.size.width * 1.4)
        XCTAssertEqual(layout.center.x, layout.size.width / 2)
        XCTAssertEqual(layout.center.y, layout.size.height / 2)
        let quadrants = Set(layout.rooms.dropFirst().map {
            "\($0.center.x < layout.center.x),\($0.center.y < layout.center.y)"
        })
        XCTAssertEqual(quadrants.count, 4)
        for room in layout.rooms.dropFirst() {
            XCTAssertGreaterThan(abs(room.center.x - layout.center.x), 100)
            XCTAssertGreaterThan(abs(room.center.y - layout.center.y), 150)
        }
    }

    func testLargerWorldsKeepRoomsSeparateAndNearbyRoomsStable() {
        let small = WorldLayout(paths: inputs(4), portrait: true)
        for count in [0,1,2,3,5,9,24,100] {
            let layout = WorldLayout(paths: inputs(count), portrait: true)
            for (index, room) in layout.rooms.enumerated() {
                for other in layout.rooms.dropFirst(index + 1) {
                    XCTAssertFalse(room.frame.insetBy(dx: -8, dy: -8).intersects(other.frame))
                }
                if let old = small.rooms.first(where: { $0.id == room.id }) {
                    XCTAssertEqual(room.center.x - layout.center.x, old.center.x - small.center.x)
                    XCTAssertEqual(room.center.y - layout.center.y, old.center.y - small.center.y)
                }
            }
        }
    }

    func testPortraitRoomsHaveWalkableRoutesAndOriginalChamberSize() {
        for count in [0,1,4,9,24] {
            let layout = WorldLayout(paths: inputs(count), portrait: true)
            let maze = WorldMaze(layout: layout)
            XCTAssertTrue(maze.ownershipRouted, "Count: \(count)")
            XCTAssertEqual(maze.routes.count, count + 1)
            XCTAssertEqual(maze.roomFrames["you"]?.midX, maze.size.width / 2)
            XCTAssertEqual(maze.roomFrames["you"]?.midY, maze.size.height / 2)
            func key(_ p: CGPoint) -> String { "\(Int(p.x)),\(Int(p.y))" }
            var barriers = Set<String>()
            for wall in maze.walls {
                let length = abs(wall.to.x-wall.from.x) + abs(wall.to.y-wall.from.y)
                let steps = Int(length / maze.cellSize)
                for index in 0..<steps {
                    let t = (CGFloat(index) + 0.5) / CGFloat(steps)
                    barriers.insert(key(CGPoint(x: wall.from.x + (wall.to.x-wall.from.x)*t,
                                                y: wall.from.y + (wall.to.y-wall.from.y)*t)))
                }
            }
            for room in layout.rooms {
                let route = maze.routes[room.id]!
                for (a,b) in zip(route,route.dropFirst()) {
                    XCTAssertTrue(a.x == b.x || a.y == b.y)
                    let steps = Int((abs(a.x-b.x) + abs(a.y-b.y)) / maze.cellSize)
                    for index in 0..<steps {
                        let t = (CGFloat(index) + 0.5) / CGFloat(steps)
                        XCTAssertFalse(barriers.contains(key(CGPoint(x: a.x+(b.x-a.x)*t,y: a.y+(b.y-a.y)*t))))
                    }
                }
                let frame = maze.roomFrames[room.id]!
                XCTAssertEqual(frame.width, 144)
                XCTAssertEqual(frame.height, 80)
                XCTAssertEqual(maze.routes[room.id]?.last, CGPoint(x: frame.midX,y: frame.midY))
            }
        }
    }
}
