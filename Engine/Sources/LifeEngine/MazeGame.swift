import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Read-only gameplay projection of the real maze. The brain room is passable; other rooms remain obstacles.
public struct MazeGameBoard: Sendable {
    public enum Direction: CaseIterable, Sendable {
        case up, right, down, left
        public var delta: (Int, Int) {
            switch self { case .up: (0,-1); case .right: (1,0); case .down: (0,1); case .left: (-1,0) }
        }
        public var angle: CGFloat {
            switch self { case .up: -.pi/2; case .right: 0; case .down: .pi/2; case .left: .pi }
        }
    }
    public let columns: Int
    public let cellSize: CGFloat
    public let neighbors: [Int: [Int]]
    public let spawn: Int
    public let doorway: CGPoint
    public let initialDirection: Direction

    public init?(maze: WorldMaze) {
        let count = maze.columns * maze.rows
        guard let home = maze.roomFrames["you"] else { return nil }
        let homeCell = Int(home.midY / maze.cellSize) * maze.columns + Int(home.midX / maze.cellSize)
        let homeOwner = maze.owners[homeCell]
        func playable(_ cell: Int) -> Bool {
            let p = maze.center(of: cell)
            return (maze.owners[cell] < count || maze.owners[cell] == homeOwner) && p.x >= 64 && p.y >= 64 && p.x < maze.size.width-64 && p.y < maze.size.height-64
        }
        var graph: [Int: [Int]] = [:]
        for door in maze.passages where playable(door.a) && playable(door.b) {
            graph[door.a, default: []].append(door.b)
            graph[door.b, default: []].append(door.a)
        }
        // The brain interior and merged filler cells have no internal walls.
        for cell in 0..<count where playable(cell) {
            for next in [cell+1, cell+maze.columns] where next < count && playable(next) {
                guard (next != cell+1 || next / maze.columns == cell / maze.columns), maze.owners[cell] == maze.owners[next] else { continue }
                graph[cell, default: []].append(next)
                graph[next, default: []].append(cell)
            }
        }
        let doors = maze.passages.compactMap { door -> (inside: Int, outside: Int)? in
            if maze.owners[door.a] == homeOwner && playable(door.b) { return (door.a, door.b) }
            if maze.owners[door.b] == homeOwner && playable(door.a) { return (door.b, door.a) }
            return nil
        }
        // Prefer an entrance leading into useful filler, rather than an isolated doorway.
        var best: (inside: Int, outside: Int, cells: Set<Int>)?
        var examined = Set<Int>()
        for door in doors where !examined.contains(door.outside) {
            var seen: Set<Int> = [door.outside], queue = [door.outside], index = 0
            while index < queue.count {
                let cell = queue[index]; index += 1
                for next in graph[cell] ?? [] where seen.insert(next).inserted { queue.append(next) }
            }
            examined.formUnion(seen)
            if seen.count > (best?.cells.count ?? 0) { best = (door.inside, door.outside, seen) }
        }
        guard let best, best.cells.count > 1 else { return nil }
        columns = maze.columns; cellSize = maze.cellSize
        spawn = best.outside; doorway = maze.center(of: best.inside)
        neighbors = Dictionary(uniqueKeysWithValues: best.cells.map { ($0, graph[$0] ?? []) })
        let diff = best.outside - best.inside
        initialDirection = diff == 1 ? .right : diff == -1 ? .left : diff > 0 ? .down : .up
    }
    public func center(_ cell: Int) -> CGPoint {
        CGPoint(x: (CGFloat(cell % columns)+0.5)*cellSize, y: (CGFloat(cell / columns)+0.5)*cellSize)
    }
    public func next(from cell: Int, direction: Direction) -> Int? {
        let delta = direction.delta
        let next = cell + delta.0 + delta.1 * columns
        return neighbors[cell]?.contains(next) == true ? next : nil
    }
}

public struct MazeGame: Sendable {
    public let board: MazeGameBoard
    public private(set) var remaining: Set<Int>
    public private(set) var cell: Int
    public private(set) var direction: MazeGameBoard.Direction
    public private(set) var requested: MazeGameBoard.Direction
    private var target: Int?
    private var origin: CGPoint
    private var progress: CGFloat = 0
    public var score: Int { board.neighbors.count - remaining.count }
    public var position: CGPoint {
        guard let target else { return board.center(cell) }
        let end = board.center(target)
        return CGPoint(x: origin.x + (end.x-origin.x)*progress, y: origin.y + (end.y-origin.y)*progress)
    }
    public init(board: MazeGameBoard) {
        self.board = board; remaining = Set(board.neighbors.keys)
        cell = board.spawn; direction = board.initialDirection; requested = direction
        origin = board.doorway; target = board.spawn
    }
    public mutating func steer(_ direction: MazeGameBoard.Direction) { requested = direction }
    /// Turns are buffered until a cell center, and never cross a closed wall.
    @discardableResult public mutating func advance(seconds: Double) -> [Int] {
        var distance = CGFloat(max(0, min(seconds, 0.1))) * 72
        var eaten: [Int] = []
        while distance > 0 {
            if target == nil {
                if board.next(from: cell, direction: requested) != nil { direction = requested }
                guard let next = board.next(from: cell, direction: direction) else { break }
                origin = board.center(cell); target = next; progress = 0
            }
            let step = min(distance, (1-progress)*board.cellSize)
            progress += step / board.cellSize; distance -= step
            if progress >= 1-0.000001, let target {
                cell = target; self.target = nil; progress = 0
                if remaining.remove(cell) != nil { eaten.append(cell) }
            }
        }
        return eaten
    }
}
