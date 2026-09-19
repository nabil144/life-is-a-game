import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A perfect maze of walkable cells and multi-cell rooms. Walls are the closed
/// boundaries; routes traverse open doorways, never the wall geometry.
public struct WorldMaze: Sendable {
    public struct Segment: Equatable, Sendable {
        public var from: CGPoint
        public var to: CGPoint
    }
    public struct Door: Equatable, Sendable {
        public var a: Int
        public var b: Int
    }
    public var walls: [Segment] = []
    public var passages: [Door] = []
    public var routes: [String: [CGPoint]] = [:]
    public var reveals: [String: WorldReveal] = [:]
    public var roomFrames: [String: CGRect] = [:]
    public var cellSize: CGFloat = 16
    public private(set) var ownershipRouted = true
    public var columns: Int = 0
    public var rows: Int = 0
    /// Cells in a chamber share one node. Every other cell is a separate node.
    public var owners: [Int] = []
    public var size: CGSize { CGSize(width: CGFloat(columns) * cellSize, height: CGFloat(rows) * cellSize) }
    public func center(of cell: Int) -> CGPoint {
        CGPoint(x: (CGFloat(cell % columns) + 0.5) * cellSize,
                y: (CGFloat(cell / columns) + 0.5) * cellSize)
    }

    private struct Edge: Hashable {
        var a: Int
        var b: Int
        init(_ a: Int, _ b: Int) { self.a = min(a,b); self.b = max(a,b) }
    }
    private struct Random {
        var seed: UInt64 = 0x4D415A4557414C4C
        mutating func next(_ count: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int((seed >> 32) % UInt64(count))
        }
        mutating func shuffle<T>(_ values: inout [T]) {
            guard values.count > 1 else { return }
            for i in stride(from: values.count - 1, through: 1, by: -1) { values.swapAt(i, next(i+1)) }
        }
    }
    private struct Forest {
        var parent: [Int]
        var size: [Int]
        init(_ count: Int) { parent = Array(0..<count); size = Array(repeating: 1, count: count) }
        mutating func root(_ value: Int) -> Int {
            var x = value
            while parent[x] != x { parent[x] = parent[parent[x]]; x = parent[x] }
            return x
        }
        mutating func join(_ a: Int, _ b: Int) -> Bool {
            var x = root(a), y = root(b)
            guard x != y else { return false }
            if size[x] < size[y] { swap(&x,&y) }
            parent[y] = x; size[x] += size[y]; return true
        }
    }

    public init(layout: WorldLayout) {
        self.init(layout: layout, wandering: true)
        if !ownershipRouted && !Task.isCancelled {
            self.init(layout: layout, wandering: false)
        }
    }

    private init(layout: WorldLayout, wandering: Bool) {
        columns = max(12, Int(ceil(layout.size.width / cellSize)))
        rows = max(8, Int(ceil(layout.size.height / cellSize)))
        let count = columns * rows
        owners = Array(0..<count)
        var roomNodes: [String: Int] = [:]
        var roomCenters: [Int: Int] = [:]
        for (index, room) in layout.rooms.enumerated() {
            let halfColumns = Int(ceil(room.size.width / cellSize)) / 2
            let halfRows = Int(ceil(room.size.height / cellSize)) / 2
            let x = min(columns-halfColumns-1, max(halfColumns, Int(room.center.x / cellSize)))
            let y = min(rows-halfRows-1, max(halfRows, Int(room.center.y / cellSize)))
            let node = count + index
            roomNodes[room.id] = node
            roomCenters[node] = y * columns + x
            roomFrames[room.id] = CGRect(x: CGFloat(x-halfColumns)*cellSize, y: CGFloat(y-halfRows)*cellSize,
                                         width: CGFloat(2*halfColumns+1)*cellSize, height: CGFloat(2*halfRows+1)*cellSize)
            for row in (y-halfRows)...(y+halfRows) {
                for col in (x-halfColumns)...(x+halfColumns) { owners[row*columns+col] = node }
            }
        }
        // Keep detailed cells around rooms, but use larger chambers in the distant
        // wilderness of very large worlds. This bounds vector complexity at overview.
        let block = max(1, Int(ceil(sqrt(Double(count) / 16000))))
        if block > 1 {
            var detailed = Set<Int>()
            for corridor in layout.corridors {
                for (a,b) in zip(corridor.points,corridor.points.dropFirst()) {
                    let ax = Int(a.x/cellSize), ay = Int(a.y/cellSize)
                    let bx = Int(b.x/cellSize), by = Int(b.y/cellSize)
                    for y in max(0,min(ay,by)-2)...min(rows-1,max(ay,by)+2) {
                        for x in max(0,min(ax,bx)-2)...min(columns-1,max(ax,bx)+2) { detailed.insert(y*columns+x) }
                    }
                }
            }
            for y in stride(from: 0, to: rows, by: block) {
                for x in stride(from: 0, to: columns, by: block) {
                    let cells = (y..<min(rows,y+block)).flatMap { row in
                        (x..<min(columns,x+block)).map { row*columns+$0 }
                    }
                    if cells.allSatisfy({ owners[$0] < count && !detailed.contains($0) }), let first = cells.first {
                        for cell in cells { owners[cell] = first }
                    }
                }
            }
        }
        var random = Random()
        var doors: [Edge: Door] = [:]
        var edges: [Edge] = []
        var neighbors = Array(repeating: [Int](), count: count + layout.rooms.count)
        func offer(_ a: Int, _ b: Int) {
            let edge = Edge(owners[a], owners[b])
            guard edge.a != edge.b, doors[edge] == nil else { return }
            doors[edge] = Door(a: a, b: b); edges.append(edge)
            neighbors[edge.a].append(edge.b); neighbors[edge.b].append(edge.a)
        }
        for y in 0..<rows { for x in 0..<columns {
            let at = y*columns+x
            if x+1 < columns { offer(at,at+1) }
            if y+1 < rows { offer(at,at+columns) }
        } }
        for node in neighbors.indices { random.shuffle(&neighbors[node]) }
        let root = roomNodes["you"]!
        var used: Set<Int> = [root]
        var roots: Set<Int> = [root]
        var branches: [UUID: Set<Int>] = [:]
        var tree = Set<Edge>()

        // Route through a narrow, irregular area around the compact ownership layout.
        // Random depth-first walks add real corners; a breadth-first fallback handles
        // crowded chambers. Joining the existing family once preserves unique ancestry.
        func connect(_ corridor: WorldLayout.Corridor) -> Bool {
            let targetName = corridor.workID.map { "work-\($0)" } ?? "path-\(corridor.pathID)"
            guard let target = roomNodes[targetName],
                  let parent = roomNodes[corridor.workID == nil ? "you" : "path-\(corridor.pathID)"] else { return false }
            var sources = corridor.workID == nil ? roots : (branches[corridor.pathID] ?? [])
            sources.insert(parent)
            var guide = Set<Int>()
            for (a,b) in zip(corridor.points,corridor.points.dropFirst()) {
                let ax = Int(a.x/cellSize), ay = Int(a.y/cellSize)
                let bx = Int(b.x/cellSize), by = Int(b.y/cellSize)
                for y in max(1,min(ay,by)-2)...min(rows-2,max(ay,by)+2) {
                    for x in max(1,min(ax,bx)-2)...min(columns-2,max(ax,bx)+2) { guide.insert(owners[y*columns+x]) }
                }
            }
            func allowed(_ node: Int, narrow: Bool) -> Bool {
                if node >= count { return node == target || node == parent }
                if used.contains(node) { return sources.contains(node) }
                let x = node % columns, y = node / columns
                return x > 0 && y > 0 && x < columns-1 && y < rows-1 && (!narrow || guide.contains(node))
            }
            func search(narrow: Bool) -> [Int]? {
                var previous: [Int: Int] = [target: target]
                var frontier = [target], head = 0
                while narrow && wandering ? !frontier.isEmpty : head < frontier.count {
                    let at: Int
                    if narrow && wandering { at = frontier.removeLast() } else { at = frontier[head]; head += 1 }
                    if sources.contains(at) {
                        var journey = [at], cursor = at
                        while cursor != target { cursor = previous[cursor]!; journey.append(cursor) }
                        return journey
                    }
                    for next in neighbors[at] where previous[next] == nil && allowed(next,narrow: narrow) {
                        previous[next] = at; frontier.append(next)
                    }
                }
                return nil
            }
            guard let journey = search(narrow: true) ?? search(narrow: false) else { return false }
            for (a,b) in zip(journey,journey.dropFirst()) { tree.insert(Edge(a,b)) }
            used.formUnion(journey)
            let outside = journey.filter { $0 < count }
            if corridor.workID == nil { roots.formUnion(outside) }
            else { branches[corridor.pathID, default: []].formUnion(outside) }
            return true
        }
        var routed = true
        for corridor in layout.corridors.filter({ $0.workID == nil }) + layout.corridors.filter({ $0.workID != nil }) {
            if Task.isCancelled { return }
            if !connect(corridor) { routed = false; break }
        }
        // Preserve all carved journeys, then remove additional walls until every cell
        // belongs to one tree. Unchosen neighboring cells retain a separating wall.
        var forest = Forest(count + layout.rooms.count)
        for edge in tree { _ = forest.join(edge.a,edge.b) }
        random.shuffle(&edges)
        for edge in edges where forest.join(edge.a,edge.b) { tree.insert(edge) }
        // Order output independently of Set/Dictionary iteration.
        let ordered = tree.sorted { $0.a == $1.a ? $0.b < $1.b : $0.a < $1.a }
        var open = Set<Edge>()
        var carved = Array(repeating: [Int](), count: neighbors.count)
        for edge in ordered {
            guard let door = doors[edge] else { continue }
            passages.append(door); open.insert(Edge(door.a,door.b))
            carved[edge.a].append(edge.b); carved[edge.b].append(edge.a)
        }
        // Walls are cell boundaries, including capped dead ends and the outer border.
        // Chamber interiors have no walls; entrances use the same open-door data.
        for y in 0...rows {
            if Task.isCancelled { return }
            var start: Int?
            for x in 0...columns {
                let closed: Bool
                if x == columns { closed = false }
                else if y == 0 || y == rows { closed = true }
                else {
                    let a = (y-1)*columns+x, b = y*columns+x
                    closed = owners[a] != owners[b] && !open.contains(Edge(a,b))
                }
                if closed && start == nil { start = x }
                if !closed, let begin = start {
                    walls.append(Segment(from: CGPoint(x: CGFloat(begin)*cellSize,y: CGFloat(y)*cellSize),
                                         to: CGPoint(x: CGFloat(x)*cellSize,y: CGFloat(y)*cellSize)))
                    start = nil
                }
            }
        }
        for x in 0...columns {
            if Task.isCancelled { return }
            var start: Int?
            for y in 0...rows {
                let closed: Bool
                if y == rows { closed = false }
                else if x == 0 || x == columns { closed = true }
                else {
                    let a = y*columns+x-1, b = y*columns+x
                    closed = owners[a] != owners[b] && !open.contains(Edge(a,b))
                }
                if closed && start == nil { start = y }
                if !closed, let begin = start {
                    walls.append(Segment(from: CGPoint(x: CGFloat(x)*cellSize,y: CGFloat(begin)*cellSize),
                                         to: CGPoint(x: CGFloat(x)*cellSize,y: CGFloat(y)*cellSize)))
                    start = nil
                }
            }
        }
        var ancestors = [root: root], stack = [root]
        while let at = stack.popLast() {
            for next in carved[at] where ancestors[next] == nil { ancestors[next] = at; stack.append(next) }
        }
        for room in layout.rooms {
            guard let target = roomNodes[room.id], ancestors[target] != nil else { continue }
            var nodes = [target], at = target
            while at != root { at = ancestors[at]!; nodes.append(at) }
            nodes.reverse()
            var points = [center(of: roomCenters[root]!)]
            for (a,b) in zip(nodes,nodes.dropFirst()) {
                let door = doors[Edge(a,b)]!
                let entry = owners[door.a] == a ? door.a : door.b
                let exit = entry == door.a ? door.b : door.a
                appendInsideRoom(center(of: entry), to: &points)
                points.append(center(of: exit))
                if let middle = roomCenters[b] { appendInsideRoom(center(of: middle), to: &points) }
            }
            routes[room.id] = simplify(points)
        }
        for room in layout.rooms {
            if Task.isCancelled { return }
            guard let route = routes[room.id] else { continue }
            var journeys = [route]
            if room.workID == nil, let pathID = room.pathID {
                journeys += layout.rooms.filter { $0.pathID == pathID && $0.workID != nil }.compactMap { routes[$0.id] }
            }
            reveals[room.id] = WorldReveal(routes: journeys, step: cellSize)
        }
        // Exposed for invariants: every child must retain its ownership gateway.
        // The tests exercise crowded layouts as well as empty/small worlds.
        ownershipRouted = routed
    }

    private func appendInsideRoom(_ point: CGPoint, to points: inout [CGPoint]) {
        if let last = points.last, last.x != point.x && last.y != point.y {
            points.append(CGPoint(x: point.x,y: last.y))
        }
        if points.last != point { points.append(point) }
    }
    private func simplify(_ points: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []
        for point in points {
            if result.count >= 2 {
                let a = result[result.count-2], b = result[result.count-1]
                if ((a.x == b.x && b.x == point.x) || (a.y == b.y && b.y == point.y)),
                   (b.x-a.x)*(point.x-b.x)+(b.y-a.y)*(point.y-b.y) >= 0 { result.removeLast() }
            }
            result.append(point)
        }
        return result
    }
}
