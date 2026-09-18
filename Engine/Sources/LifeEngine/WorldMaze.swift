import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// One deterministic tree: the journeys and the unused branches share the same roads.
/// Generated only when rooms change, never while panning or selecting.
public struct WorldMaze: Sendable {
    public struct Segment: Equatable, Sendable {
        public var from: CGPoint
        public var to: CGPoint
    }
    public var segments: [Segment] = []
    public var routes: [String: [CGPoint]] = [:]

    private struct Cell: Hashable, Comparable {
        var x: Int
        var y: Int
        init(_ point: CGPoint) { x = Int((point.x / 4).rounded()); y = Int((point.y / 4).rounded()) }
        init(_ x: Int, _ y: Int) { self.x = x; self.y = y }
        var point: CGPoint { CGPoint(x: x * 4, y: y * 4) }
        static func < (a: Self, b: Self) -> Bool { a.y == b.y ? a.x < b.x : a.y < b.y }
    }
    private struct Edge: Hashable, Comparable {
        var a: Cell
        var b: Cell
        init(_ a: Cell, _ b: Cell) { self.a = min(a, b); self.b = max(a, b) }
        static func < (a: Self, b: Self) -> Bool { a.a == b.a ? a.b < b.b : a.a < b.a }
    }
    private struct Random {
        var seed: UInt64 = 0x4D415A454C494645
        mutating func next(_ count: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int((seed >> 32) % UInt64(count))
        }
        mutating func shuffle<T>(_ values: inout [T]) {
            guard values.count > 1 else { return }
            for i in stride(from: values.count - 1, through: 1, by: -1) {
                values.swapAt(i, next(i + 1))
            }
        }
    }
    private struct Forest {
        var ids: [Cell: Int] = [:]
        var parents: [Int] = []
        var sizes: [Int] = []
        mutating func root(_ cell: Cell) -> Int {
            let index: Int
            if let existing = ids[cell] { index = existing }
            else {
                index = parents.count; ids[cell] = index
                parents.append(index); sizes.append(1)
            }
            var current = index
            while parents[current] != current {
                parents[current] = parents[parents[current]]
                current = parents[current]
            }
            return current
        }
        mutating func join(_ a: Cell, _ b: Cell) -> Bool {
            var x = root(a), y = root(b)
            guard x != y else { return false }
            if sizes[x] < sizes[y] { swap(&x, &y) }
            parents[y] = x; sizes[x] += sizes[y]
            return true
        }
    }

    private static func cells(_ a: Cell, _ b: Cell) -> [Cell] {
        let dx = a.x == b.x ? 0 : (a.x < b.x ? 1 : -1)
        let dy = a.y == b.y ? 0 : (a.y < b.y ? 1 : -1)
        let length = abs(b.x - a.x) + abs(b.y - a.y)
        return (0...length).map { Cell(a.x + dx * $0, a.y + dy * $0) }
    }

    public init(layout: WorldLayout) {
        var random = Random()
        var backbone = Set<Edge>()
        for corridor in layout.corridors {
            for (a, b) in zip(corridor.points, corridor.points.dropFirst()) {
                let line = Self.cells(Cell(a), Cell(b))
                for (a, b) in zip(line, line.dropFirst()) { backbone.insert(Edge(a, b)) }
            }
        }
        if backbone.isEmpty {
            let root = Cell(layout.center)
            let line = Self.cells(root, Cell(root.x + 22, root.y))
            for (a, b) in zip(line, line.dropFirst()) { backbone.insert(Edge(a, b)) }
        }
        var occupied = Set(backbone.flatMap { [$0.a, $0.b] })
        occupied.insert(Cell(layout.center))
        // Raster masks keep collision checks independent of the number of rooms.
        var rooms = Set<Cell>()
        for room in layout.rooms {
            let rect = room.frame.insetBy(dx: -4, dy: -4)
            for y in Int(rect.minY / 4)...Int(rect.maxY / 4) {
                for x in Int(rect.minX / 4)...Int(rect.maxX / 4) { rooms.insert(Cell(x, y)) }
            }
        }
        var neighbors: [Cell: [Cell]] = [:]
        for edge in backbone.sorted() {
            neighbors[edge.a, default: []].append(edge.b)
            neighbors[edge.b, default: []].append(edge.a)
        }
        // Bend straight runs into U-shaped excursions where there is clearance.
        // Junctions stay in place, so room ownership and shared trunks are preserved.
        let anchors = Set(neighbors.keys.filter { cell in
            let links = neighbors[cell]!
            return links.count != 2 || (links[0].x != links[1].x && links[0].y != links[1].y)
        })
        for start in anchors.sorted() {
            if Task.isCancelled { return }
            for first in neighbors[start] ?? [] {
                var run = [start, first]
                while let last = run.last, !anchors.contains(last) {
                    let previous = run[run.count - 2]
                    guard let next = neighbors[last]?.first(where: { $0 != previous }) else { break }
                    run.append(next)
                }
                guard let end = run.last, start < end, run.count >= 5 else { continue }
                // Use the longest exposed part of the run, leaving room interiors alone.
                var best: [Cell] = [], current: [Cell] = []
                for cell in run.dropFirst().dropLast() {
                    if rooms.contains(cell) {
                        if current.count > best.count { best = current }; current = []
                    } else { current.append(cell) }
                }
                if current.count > best.count { best = current }
                guard best.count >= 5 else { continue }
                best = Array(best.dropFirst().dropLast())
                guard let a = best.first, let b = best.last else { continue }
                let original = Set(best)
                let connections = Set(run.filter { cell in
                    abs(cell.x-a.x) + abs(cell.y-a.y) <= 1 || abs(cell.x-b.x) + abs(cell.y-b.y) <= 1
                })
                let sign = random.next(2) == 0 ? 1 : -1
                for direction in [sign, -sign] {
                    let distance = 6 + random.next(3) * 2 // 24–40 points off the direct road.
                    let dx = a.x == b.x ? direction * distance : 0
                    let dy = a.y == b.y ? direction * distance : 0
                    let c = Cell(a.x + dx, a.y + dy), d = Cell(b.x + dx, b.y + dy)
                    let detour = Self.cells(a, c) + Self.cells(c, d).dropFirst() + Self.cells(d, b).dropFirst()
                    let valid = detour.allSatisfy { cell in
                        guard cell.x > 1, cell.y > 1,
                              cell.point.x < layout.size.width - 8, cell.point.y < layout.size.height - 8,
                              !rooms.contains(cell) else { return false }
                        for y in -1...1 { for x in -1...1 {
                            let near = Cell(cell.x + x, cell.y + y)
                            if occupied.contains(near), !original.contains(near), !connections.contains(near) { return false }
                        } }
                        return true
                    }
                    guard valid else { continue }
                    let old = best
                    for (a, b) in zip(old, old.dropFirst()) { backbone.remove(Edge(a, b)) }
                    occupied.subtract(original.subtracting([a, b]))
                    for (a, b) in zip(detour, detour.dropFirst()) { backbone.insert(Edge(a, b)) }
                    occupied.formUnion(detour)
                    break
                }
            }
        }

        var forest = Forest()
        var tree: [Edge] = []
        var roads = backbone.sorted()
        random.shuffle(&roads)
        for edge in roads where forest.join(edge.a, edge.b) { tree.append(edge) }
        _ = forest.root(Cell(layout.center))

        // Coarse maze grid fills the world. Split crossings at exact backbone cells,
        // then graft branches with Kruskal: never a shortcut or a second route.
        let step = max(6, Int(ceil(sqrt(layout.size.width * layout.size.height / 8000) / 4)))
        let width = Int(layout.size.width / 4), height = Int(layout.size.height / 4)
        var candidates: [Edge] = []
        func offer(_ a: Cell, _ b: Cell) {
            let line = Self.cells(a, b)
            guard line.allSatisfy({ !rooms.contains($0) }) else { return }
            var previous = a
            for cell in line.dropFirst() where occupied.contains(cell) || cell == b {
                candidates.append(Edge(previous, cell)); previous = cell
            }
        }
        for y in stride(from: step / 2, to: height - step / 2, by: step) {
            if Task.isCancelled { return }
            for x in stride(from: step / 2, to: width - step / 2, by: step) {
                let at = Cell(x, y)
                if x + step < width - step / 2 { offer(at, Cell(x + step, y)) }
                if y + step < height - step / 2 { offer(at, Cell(x, y + step)) }
            }
        }
        random.shuffle(&candidates)
        for edge in candidates where forest.join(edge.a, edge.b) { tree.append(edge) }

        let root = Cell(layout.center)
        let component = forest.root(root)
        tree = tree.filter { forest.root($0.a) == component }
        neighbors = [:]
        for edge in tree {
            neighbors[edge.a, default: []].append(edge.b)
            neighbors[edge.b, default: []].append(edge.a)
        }
        var parents: [Cell: Cell] = [root: root]
        var stack = [root]
        while let cell = stack.popLast() {
            for next in neighbors[cell] ?? [] where parents[next] == nil {
                parents[next] = cell; stack.append(next)
            }
        }
        for room in layout.rooms {
            var cell = Cell(room.center)
            guard parents[cell] != nil else { continue }
            var route = [cell.point]
            while cell != root {
                cell = parents[cell]!
                route.append(cell.point)
            }
            routes[room.id] = Self.simplify(Array(route.reversed()))
        }
        // Collapse straight runs for small native vector paths, even in large worlds.
        let endpoints = Set(neighbors.keys.filter { cell in
            let links = neighbors[cell]!
            return links.count != 2 || (links[0].x != links[1].x && links[0].y != links[1].y)
        })
        for start in endpoints.sorted() {
            for first in neighbors[start] ?? [] {
                var previous = start, end = first
                while !endpoints.contains(end) {
                    guard let next = neighbors[end]?.first(where: { $0 != previous }) else { break }
                    previous = end; end = next
                }
                if start < end { segments.append(Segment(from: start.point, to: end.point)) }
            }
        }
    }

    private static func simplify(_ points: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []
        for point in points {
            if result.count >= 2 {
                let a = result[result.count - 2], b = result[result.count - 1]
                if (a.x == b.x && b.x == point.x) || (a.y == b.y && b.y == point.y) { result.removeLast() }
            }
            result.append(point)
        }
        return result
    }
}
