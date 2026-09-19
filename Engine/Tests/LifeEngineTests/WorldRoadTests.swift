import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import LifeEngine

final class WorldRoadTests: XCTestCase {
    func testTravellerStartsAndStopsOutsideDoorsAndKeepsCorners() {
        let road = WorldRoad(points: [.init(x: 0,y: 0),.init(x: 100,y: 0),.init(x: 100,y: 100)],
                             source: CGRect(x: -40,y: -40,width: 80,height: 80),
                             destination: CGRect(x: 60,y: 60,width: 80,height: 80))
        XCTAssertEqual(road.points,[.init(x: 46,y: 0),.init(x: 100,y: 0),.init(x: 100,y: 54)])
        XCTAssertEqual(road.distances,[0,54,108])
    }

    func testRealMazeRoadsStayOutsideChambersAndOnSingleSelectedRoute() {
        for count in [1,4,9] {
            let inputs = (0..<count).map { _ in WorldLayout.Input(id: UUID(),work: []) }
            let maze = WorldMaze(layout: WorldLayout(paths: inputs,portrait: true,compactCenter: true))
            for (id,points) in maze.routes where id != "you" {
                let source = maze.roomFrames["you"]!, target = maze.roomFrames[id]!
                let road = WorldRoad(points: points,source: source,destination: target)
                XCTAssertGreaterThan(road.length,0)
                XCTAssertFalse(source.insetBy(dx: -5,dy: -5).contains(road.points.first!))
                XCTAssertFalse(target.insetBy(dx: -5,dy: -5).contains(road.points.last!))
                for (a,b) in zip(road.points,road.points.dropFirst()) {
                    XCTAssertTrue(a.x == b.x || a.y == b.y)
                    let samples = max(1,Int(hypot(b.x-a.x,b.y-a.y)))
                    for i in 0...samples {
                        let t = CGFloat(i)/CGFloat(samples)
                        let p = CGPoint(x: a.x+(b.x-a.x)*t,y: a.y+(b.y-a.y)*t)
                        XCTAssertFalse(source.contains(p)); XCTAssertFalse(target.contains(p))
                    }
                }
                XCTAssertEqual(road.distances.count,road.points.count)
            }
        }
    }

    func testInterruptedTravellerRetracesOnlyVisitedCorridors() {
        let road = WorldRoad(points: [.zero,.init(x: 100,y: 0),.init(x: 100,y: 100)])
        let returning = road.returning(after: 140)
        XCTAssertEqual(returning.points,[.init(x: 100,y: 40),.init(x: 100,y: 0),.zero])
        XCTAssertEqual(returning.length,140)
        XCTAssertEqual(returning.points.first,road.position(at: 140))
        XCTAssertEqual(road.returning(after: 1000).points,Array(road.points.reversed()))
        XCTAssertEqual(road.returning(after: 0).length,0)
        XCTAssertEqual(road.returning(after: -10).length,0)
        XCTAssertEqual(road.position(at: 100),CGPoint(x: 100,y: 0))
        XCTAssertEqual(road.position(at: 120),CGPoint(x: 100,y: 20))
        XCTAssertEqual(road.position(at: 300),CGPoint(x: 100,y: 100))
    }

    func testEmptyAndDuplicatePointsAreSafe() {
        let rect = CGRect(x: -40,y: -40,width: 80,height: 80)
        XCTAssertEqual(WorldRoad(points: [],source: rect,destination: rect).length,0)
        XCTAssertEqual(WorldRoad(points: [.zero,.zero],source: rect,destination: rect).length,0)
    }
}
