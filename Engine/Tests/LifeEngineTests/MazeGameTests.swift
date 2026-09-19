import XCTest
@testable import LifeEngine

final class MazeGameTests: XCTestCase {
    private func fixture() throws -> (WorldMaze, MazeGameBoard) {
        let layout = WorldLayout(paths: (0..<4).map { _ in .init(id: UUID(), work: []) }, portrait: true, compactCenter: true)
        let maze = WorldMaze(layout: layout, seed: 42, alternatives: true)
        return (maze, try XCTUnwrap(MazeGameBoard(maze: maze)))
    }
    private func step(_ game: inout MazeGame) {
        game.advance(seconds: 0.1)
        game.advance(seconds: 0.1)
        game.advance(seconds: Double(game.board.cellSize)/72 - 0.2)
    }
    func testPlayableCellsFollowRealPassagesAndExcludeOtherRoomsAndOuterBorder() throws {
        let (maze, board) = try fixture()
        XCTAssertGreaterThan(board.neighbors.count, 10)
        let open = Set(maze.passages.map { "\(min($0.a,$0.b)):\(max($0.a,$0.b))" })
        for (cell, neighbors) in board.neighbors {
            let point = board.center(cell)
            XCTAssertGreaterThanOrEqual(point.x, 64)
            XCTAssertGreaterThanOrEqual(point.y, 64)
            for (id, room) in maze.roomFrames where id != "you" { XCTAssertFalse(room.contains(point)) }
            for next in neighbors {
                XCTAssertTrue(open.contains("\(min(cell,next)):\(max(cell,next))") || maze.owners[cell] == maze.owners[next])
                XCTAssertTrue(board.neighbors[next]?.contains(cell) == true)
            }
        }
    }
    func testBrainInteriorAndEveryDoorwayAreReachable() throws {
        let (maze, board) = try fixture()
        let home = try XCTUnwrap(maze.roomFrames["you"])
        let center = Int(home.midY / maze.cellSize) * maze.columns + Int(home.midX / maze.cellSize)
        let owner = maze.owners[center]
        var seen: Set<Int> = [center], queue = [center], index = 0
        while index < queue.count {
            let cell = queue[index]; index += 1
            for next in board.neighbors[cell] ?? [] where seen.insert(next).inserted { queue.append(next) }
        }
        XCTAssertEqual(seen, Set(board.neighbors.keys))
        for cell in maze.owners.indices where maze.owners[cell] == owner {
            XCTAssertNotNil(board.neighbors[cell], "Brain interior must be walkable")
        }
        for door in maze.passages where maze.owners[door.a] == owner || maze.owners[door.b] == owner {
            XCTAssertTrue(board.neighbors[door.a]?.contains(door.b) == true)
            XCTAssertTrue(board.neighbors[door.b]?.contains(door.a) == true)
        }
    }
    func testMovementCollectsOnceAndCanReverseAtJunctions() throws {
        let (_, board) = try fixture()
        var game = MazeGame(board: board)
        step(&game)
        XCTAssertEqual(game.score, 1)
        let direction = try XCTUnwrap(MazeGameBoard.Direction.allCases.first { board.next(from: board.spawn, direction: $0) != nil })
        let next = try XCTUnwrap(board.next(from: board.spawn, direction: direction))
        game.steer(direction); step(&game)
        XCTAssertEqual(game.cell, next)
        XCTAssertEqual(game.score, 2)
        let back = try XCTUnwrap(MazeGameBoard.Direction.allCases.first { board.next(from: next, direction: $0) == board.spawn })
        game.steer(back); step(&game)
        XCTAssertEqual(game.cell, board.spawn)
        XCTAssertEqual(game.score, 2)
    }
    func testTurnIsBufferedUntilCellCenterAndLongFrameCannotTeleport() throws {
        let (_, board) = try fixture()
        var game = MazeGame(board: board)
        let start = game.position
        game.steer(.left)
        game.advance(seconds: 30)
        XCTAssertEqual(game.direction, board.initialDirection)
        let moved = hypot(game.position.x-start.x, game.position.y-start.y)
        XCTAssertEqual(moved, 7.2, accuracy: 0.001)
        XCTAssertEqual(game.score, 0)
        XCTAssertEqual(game.requested, .left)
    }
    func testDeadEndStopsAgainstWall() throws {
        let (_, board) = try fixture()
        let destination = try XCTUnwrap(board.neighbors.keys.first { board.neighbors[$0]?.count == 1 })
        var parent = [board.spawn: board.spawn], queue = [board.spawn], index = 0
        while index < queue.count && parent[destination] == nil {
            let cell = queue[index]; index += 1
            for next in board.neighbors[cell] ?? [] where parent[next] == nil { parent[next] = cell; queue.append(next) }
        }
        var route = [destination]
        while route.last! != board.spawn { route.append(try XCTUnwrap(parent[route.last!])) }
        var game = MazeGame(board: board); step(&game)
        for cell in route.reversed().dropFirst() {
            let direction = try XCTUnwrap(MazeGameBoard.Direction.allCases.first { board.next(from: game.cell, direction: $0) == cell })
            game.steer(direction); step(&game)
        }
        let position = game.position
        for _ in 0..<20 { game.advance(seconds: 0.1) }
        XCTAssertEqual(game.position.x, position.x, accuracy: 0.001)
        XCTAssertEqual(game.position.y, position.y, accuracy: 0.001)
    }
}
