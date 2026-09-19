import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import LifeEngine

final class WorldAlternativesTests: XCTestCase {
    private func layout(_ count: Int, compactCenter: Bool = true) -> WorldLayout {
        WorldLayout(paths: (0..<count).map { .init(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0+1))!,work: []) },portrait: true,compactCenter: compactCenter)
    }
    func testFreshSeedChangesMazeButNeverMovesRooms() {
        let layout = layout(4)
        let a = WorldMaze(layout: layout,seed: 123,alternatives: true)
        let b = WorldMaze(layout: layout,seed: 456,alternatives: true)
        XCTAssertEqual(a.roomFrames,b.roomFrames)
        XCTAssertNotEqual(a.walls.map { [$0.from,$0.to] },b.walls.map { [$0.from,$0.to] })
        XCTAssertNotEqual(a.routes,b.routes)
        XCTAssertEqual(a.alternateRoutes,WorldMaze(layout: layout,seed: 123,alternatives: true).alternateRoutes)
    }
    func testDistantFloorKeepsTheSameCellResolutionInBothScenes() {
        for compactCenter in [true, false] {
            let shape = layout(9, compactCenter: compactCenter)
            let maze = WorldMaze(layout: shape, seed: 42, alternatives: true)
            let count = maze.columns * maze.rows
            XCTAssertGreaterThan(count, 16000)
            for cell in 0..<count where maze.owners[cell] < count {
                XCTAssertEqual(maze.owners[cell], cell, "Distant floor must not merge into open chambers")
            }
        }
    }
    func testAlternativesUseRealOpenFloorAndAvoidOtherRooms() {
        for count in [1,4,9,16] {
            for seed: UInt64 in [7,42,91] {
                let maze = WorldMaze(layout: layout(count),seed: seed,alternatives: true)
                let doors = Set(maze.passages.map { "\(min($0.a,$0.b)):\(max($0.a,$0.b))" })
                for (id,choices) in maze.alternateRoutes where id != "you" {
                    XCTAssertGreaterThanOrEqual(choices.count,2,"No alternate for \(id), count \(count), seed \(seed)")
                    XCTAssertLessThanOrEqual(choices.count,3)
                    for points in choices {
                        XCTAssertEqual(points.first,maze.routes[id]?.first)
                        XCTAssertEqual(points.last,maze.routes[id]?.last)
                        for (a,b) in zip(points,points.dropFirst()) {
                            XCTAssertTrue(a.x == b.x || a.y == b.y)
                            let steps = Int((abs(a.x-b.x)+abs(a.y-b.y))/maze.cellSize)
                            var previous: Int?
                            for i in 0...max(1,steps) {
                                let t = CGFloat(i)/CGFloat(max(1,steps))
                                let p = CGPoint(x: a.x+(b.x-a.x)*t,y: a.y+(b.y-a.y)*t)
                                for (other,room) in maze.roomFrames where other != "you" && other != id {
                                    XCTAssertFalse(room.contains(p),"Alternate crosses another room")
                                }
                                let cell = Int(p.y/maze.cellSize)*maze.columns+Int(p.x/maze.cellSize)
                                if let old = previous, old != cell, maze.owners[old] != maze.owners[cell] {
                                    XCTAssertTrue(doors.contains("\(min(old,cell)):\(max(old,cell))"),"Road crosses a wall")
                                }
                                previous = cell
                            }
                        }
                    }
                }
            }
        }
    }
    func testLongAlternativesPreserveTheOriginalWallDensity() {
        for count in [1,4,9,16] {
            let shape = layout(count)
            let base = WorldMaze(layout: shape,seed: 42)
            let maze = WorldMaze(layout: shape,seed: 42,alternatives: true)
            let extraDoors = maze.passages.count - base.passages.count
            XCTAssertGreaterThan(extraDoors,0)
            XCTAssertLessThanOrEqual(extraDoors,count*4,"Alternatives must not carve large portions of the maze")
            func wallLength(_ maze: WorldMaze) -> CGFloat {
                maze.walls.reduce(0) { $0 + abs($1.to.x-$1.from.x) + abs($1.to.y-$1.from.y) }
            }
            XCTAssertEqual(wallLength(base)-wallLength(maze),CGFloat(extraDoors)*maze.cellSize,accuracy: 0.01)
            XCTAssertGreaterThan(wallLength(maze)/wallLength(base),0.99)
            for (id, choices) in maze.alternateRoutes where id != "you" {
                let direct = WorldRoad(points: choices[0]).length
                XCTAssertGreaterThanOrEqual(choices.count,2,"count \(count), room \(id)")
                for points in choices.dropFirst() {
                    XCTAssertGreaterThanOrEqual(WorldRoad(points: points).length,direct + max(128,direct*0.3))
                }
            }
        }
    }

    func testTrafficDetectsCrossingsAndSharedCorridors() {
        let road = WorldRoad(points: [.init(x: 8,y: 8),.init(x: 104,y: 8)])
        XCTAssertTrue(road.sharesFloor(with: WorldRoad(points: [.init(x: 56,y: -40),.init(x: 56,y: 56)])))
        XCTAssertTrue(road.sharesFloor(with: road.returning(after: 64)))
        XCTAssertFalse(road.sharesFloor(with: WorldRoad(points: [.init(x: 8,y: 40),.init(x: 104,y: 40)])))
    }
}
