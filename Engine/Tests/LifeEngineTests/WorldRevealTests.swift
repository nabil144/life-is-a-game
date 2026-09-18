import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import LifeEngine

final class WorldRevealTests: XCTestCase {
    func testSharedTrunkLightsOnceBeforeBothBranches() {
        let root = CGPoint(x: 8,y: 8), fork = CGPoint(x: 40,y: 8)
        let reveal = WorldReveal(routes: [
            [root,fork,CGPoint(x: 40,y: 40)],
            [root,fork,CGPoint(x: 72,y: 8)]
        ])
        XCTAssertEqual(reveal.strokes.count,3)
        XCTAssertEqual(reveal.strokes.filter { $0.start == 0 }.count,1)
        XCTAssertEqual(reveal.strokes.filter { $0.start == 32 }.count,2)
        XCTAssertEqual(reveal.distance,64)
        XCTAssertEqual(reveal.strokes.reduce(0) { $0+$1.length },96)
    }
    func testDuplicateRoutesDoNotReplayAndCornersRemain() {
        let route = [CGPoint(x: 8,y: 8),CGPoint(x: 8,y: 40),CGPoint(x: 56,y: 40)]
        let reveal = WorldReveal(routes: [route,route])
        XCTAssertEqual(reveal.strokes.count,1)
        XCTAssertEqual(reveal.distance,80)
        XCTAssertTrue(reveal.strokes[0].points.contains(CGPoint(x: 8,y: 40)))
        XCTAssertEqual(reveal.strokes[0].points.last,route.last)
    }
    func testBalancedSpacingAndCenteredYou() {
        let layout = WorldLayout(paths: (0..<4).map { index in
            .init(id: UUID(),work: (0..<(index == 0 ? 12 : 2)).map { _ in UUID() })
        })
        XCTAssertEqual(layout.center.x,layout.size.width/2)
        XCTAssertEqual(layout.center.y,layout.size.height/2)
        for room in layout.rooms where room.workID == nil && room.pathID != nil {
            XCTAssertEqual(hypot(room.center.x-layout.center.x,room.center.y-layout.center.y),176)
        }
        let maze = WorldMaze(layout: layout)
        let you = maze.roomFrames["you"]!
        XCTAssertEqual(you.midX,maze.size.width/2)
        XCTAssertEqual(you.midY,maze.size.height/2)
    }
}
