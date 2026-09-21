import XCTest
@testable import LifeEngine

final class MazeJoystickTests: XCTestCase {
    func testCenterAndSmallThumbMovementsStop() {
        for point in [CGPoint.zero, CGPoint(x: 3, y: 4), CGPoint(x: 8, y: 0)] {
            let input = MazeJoystick(displacement: point)
            XCTAssertNil(input.direction)
            XCTAssertEqual(input.speed, 0)
            XCTAssertEqual(input.offset, .zero)
        }
    }

    func testThumbDirectionUsesDominantAxis() {
        let cases: [(CGPoint, MazeGameBoard.Direction)] = [
            (CGPoint(x: 30, y: 12), .right), (CGPoint(x: -30, y: 12), .left),
            (CGPoint(x: 12, y: -30), .up), (CGPoint(x: 12, y: 30), .down)
        ]
        for (point, direction) in cases {
            XCTAssertEqual(MazeJoystick(displacement: point).direction, direction)
        }
    }

    func testPullingFartherIncreasesSpeedAndClampsKnob() {
        let near = MazeJoystick(displacement: CGPoint(x: 12, y: 0))
        let far = MazeJoystick(displacement: CGPoint(x: 44, y: 0))
        let beyond = MazeJoystick(displacement: CGPoint(x: 300, y: 400))
        XCTAssertGreaterThan(near.speed, 0)
        XCTAssertLessThan(near.speed, far.speed)
        XCTAssertEqual(far.speed, 1)
        XCTAssertEqual(beyond.speed, 1)
        XCTAssertEqual(hypot(beyond.offset.x, beyond.offset.y), 44, accuracy: 0.001)
    }

    func testReleaseStopsMidPassageAndHoldingResumesWithoutTeleporting() throws {
        let layout = WorldLayout(paths: [.init(id: UUID(), work: [])], portrait: true, compactCenter: true)
        let maze = WorldMaze(layout: layout, seed: 42, alternatives: true)
        let board = try XCTUnwrap(MazeGameBoard(maze: maze))
        var game = MazeGame(board: board)
        let held = MazeJoystick(displacement: CGPoint(x: 44, y: 0))
        game.advance(seconds: 0.05 * held.speed)
        let position = game.position
        let score = game.score
        let released = MazeJoystick(displacement: .zero)
        for _ in 0..<20 { game.advance(seconds: 0.1 * released.speed) }
        XCTAssertEqual(game.position, position)
        XCTAssertEqual(game.score, score)
        game.advance(seconds: 0.05 * held.speed)
        XCTAssertEqual(hypot(game.position.x - position.x, game.position.y - position.y), 3.6, accuracy: 0.001)
    }
}
