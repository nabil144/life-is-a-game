import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A maze of walkable cells and multi-cell rooms, with optional alternate roads. Walls are the closed
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
    public var alternateRoutes: [String: [[CGPoint]]] = [:]
    public var reveals: [String: WorldReveal] = [:]
    public var roomFrames: [String: CGRect] = [:]
    public var cellSize: CGFloat = 16
    public private(set) var ownershipRouted = true
    public private(set) var separateRoadsRouted = false
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

    public init(layout: WorldLayout, seed: UInt64 = 0x4D415A4557414C4C, alternatives: Bool = false) {
        self.init(layout: layout, seed: seed, wandering: true)
        if !ownershipRouted && !Task.isCancelled {
            self.init(layout: layout, seed: seed, wandering: false)
        }
        // A fixed-size center has a finite number of door cells. Preserve a valid
        // connected maze if an exceptionally large level exhausts those doorways.
        if !ownershipRouted && layout.separateRoads && !Task.isCancelled {
            var shared = layout
            shared.separateRoads = false
            self.init(layout: shared, seed: seed, wandering: false)
        }
        if alternatives && !Task.isCancelled { addAlternatives(layout: layout, seed: seed) }
    }

    private init(layout: WorldLayout, seed: UInt64, wandering: Bool) {
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
            if layout.separateRoads {
                for room in layout.rooms {
                    let cx = Int(room.center.x / cellSize), cy = Int(room.center.y / cellSize)
                    let radius = room.id == "you" ? 16 : 6
                    for y in max(0,cy-radius)...min(rows-1,cy+radius) {
                        for x in max(0,cx-radius)...min(columns-1,cx+radius) { detailed.insert(y*columns+x) }
                    }
                }
            }
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
        var random = Random(seed: seed)
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
            var sources = corridor.workID == nil ? (layout.separateRoads ? [root] : roots) : (branches[corridor.pathID] ?? [])
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
        // Greedy wandering can trap a later road. Reroute all single-level roads
        // together using vertex capacity: every floor node belongs to at most one road.
        if layout.separateRoads && !routed {
            struct FlowEdge { var to: Int; var capacity: Int }
            let sink = neighbors.count * 2
            let source = root * 2 + 1
            var graph = Array(repeating: [Int](), count: sink + 1)
            var flowEdges: [FlowEdge] = []
            var physical: [(index: Int, a: Int, b: Int)] = []
            func add(_ a: Int, _ b: Int) -> Int {
                let index = flowEdges.count
                flowEdges.append(FlowEdge(to: b, capacity: 1))
                flowEdges.append(FlowEdge(to: a, capacity: 0))
                graph[a].append(index); graph[b].append(index + 1)
                return index
            }
            for at in neighbors.indices where !neighbors[at].isEmpty {
                if at >= count && at != root {
                    _ = add(at * 2, sink)
                    continue
                }
                if at != root { _ = add(at * 2, at * 2 + 1) }
                for next in neighbors[at] where next != root {
                    let index = add(at * 2 + 1, next * 2)
                    physical.append((index,at,next))
                }
            }
            var connected = 0
            while connected < layout.rooms.count - 1 {
                if Task.isCancelled { return }
                var previous = Array(repeating: -1, count: graph.count)
                previous[source] = -2
                var queue = [source], head = 0
                while head < queue.count && previous[sink] == -1 {
                    let at = queue[head]; head += 1
                    for edge in graph[at] where flowEdges[edge].capacity > 0 {
                        let next = flowEdges[edge].to
                        guard previous[next] == -1 else { continue }
                        previous[next] = edge; queue.append(next)
                    }
                }
                guard previous[sink] != -1 else { break }
                var at = sink
                while at != source {
                    let edge = previous[at]
                    flowEdges[edge].capacity -= 1
                    flowEdges[edge ^ 1].capacity += 1
                    at = flowEdges[edge ^ 1].to
                }
                connected += 1
            }
            if connected == layout.rooms.count - 1 {
                tree.removeAll()
                for link in physical where flowEdges[link.index].capacity == 0 {
                    tree.insert(Edge(link.a,link.b))
                }
                routed = true
            }
        }
        if layout.separateRoads && routed {
            // Add bounded side excursions after allocating every road. Reserving the
            // complete tree first prevents a detour from stealing another room's road.
            var routeNeighbors: [Int:[Int]] = [:]
            var occupied = Set<Int>()
            for edge in tree.sorted(by: { $0.a == $1.a ? $0.b < $1.b : $0.a < $1.a }) {
                routeNeighbors[edge.a,default: []].append(edge.b)
                routeNeighbors[edge.b,default: []].append(edge.a)
                occupied.insert(edge.a); occupied.insert(edge.b)
            }
            var parent = [root: root], frontier = [root]
            while let at = frontier.popLast() {
                for next in routeNeighbors[at] ?? [] where parent[next] == nil {
                    parent[next] = at; frontier.append(next)
                }
            }
            for room in layout.rooms where room.id != "you" {
                if Task.isCancelled { return }
                guard let target = roomNodes[room.id], parent[target] != nil else { continue }
                var journey = [target], cursor = target
                while cursor != root { cursor = parent[cursor]!; journey.append(cursor) }
                journey.reverse()
                var candidates = Array(zip(journey,journey.dropFirst()))
                random.shuffle(&candidates)
                var added: CGFloat = 0
                // A few deliberate U-bends, rather than making short journeys endless.
                let budget: CGFloat = 192
                for (a,b) in candidates where a < count && b < count && added < budget {
                    let ax = a % columns, ay = a / columns, bx = b % columns, by = b / columns
                    guard abs(ax-bx)+abs(ay-by) == 1 else { continue }
                    var signs = [-1,1]; random.shuffle(&signs)
                    var inserted = false
                    for sign in signs {
                        let dx = (by-ay)*sign, dy = (bx-ax)*sign
                        for depth in [3,2,1] {
                            var cells = [a]
                            for step in 1...depth { cells.append((ay+dy*step)*columns+ax+dx*step) }
                            for step in stride(from: depth, through: 0, by: -1) { cells.append((by+dy*step)*columns+bx+dx*step) }
                            let inside = cells.dropFirst().dropLast()
                            var valid = true
                            for step in 1...depth {
                                let x1 = ax + dx * step, y1 = ay + dy * step
                                let x2 = bx + dx * step, y2 = by + dy * step
                                if x1 < 1 || x1 >= columns-1 || y1 < 1 || y1 >= rows-1 { valid = false }
                                if x2 < 1 || x2 >= columns-1 || y2 < 1 || y2 >= rows-1 { valid = false }
                            }
                            guard valid else { continue }
                            guard inside.allSatisfy({ owners[$0] == $0 && !occupied.contains($0) }) else { continue }
                            guard zip(cells,cells.dropFirst()).allSatisfy({ doors[Edge($0.0,$0.1)] != nil }) else { continue }
                            tree.remove(Edge(a,b))
                            for (from,to) in zip(cells,cells.dropFirst()) { tree.insert(Edge(from,to)) }
                            occupied.formUnion(inside)
                            added += CGFloat(2*depth)*cellSize
                            inserted = true
                            break
                        }
                        if inserted { break }
                    }
                }
            }
        }
        separateRoadsRouted = layout.separateRoads && routed
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
        buildWalls(open: open)
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

    private mutating func buildWalls(open: Set<Edge>) {
        walls.removeAll(keepingCapacity: true)
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
    }

    private mutating func addAlternatives(layout: WorldLayout, seed: UInt64) {
        alternateRoutes = routes.mapValues { [$0] }
        let count = columns * rows
        var open = Set(passages.map { Edge($0.a,$0.b) })
        var doors: [Edge:Door] = [:]
        var graph = Array(repeating: [Int](),count: count + layout.rooms.count)
        for door in passages {
            let a = owners[door.a], b = owners[door.b]
            doors[Edge(a,b)] = door
            graph[a].append(b); graph[b].append(a)
        }
        // Keep the original tree. A pair of branches can become a long alternate
        // journey by opening just one wall between them, rather than overlaying mazes.
        var candidates: [Door] = []
        for y in 1..<rows-1 {
            for x in 1..<columns-1 {
                let a = y*columns+x
                for b in [a+1,a+columns] where owners[a] != owners[b] {
                    if owners[a] < count && owners[b] < count && doors[Edge(owners[a],owners[b])] == nil {
                        candidates.append(Door(a: a,b: b))
                    }
                }
            }
        }
        var random = Random(seed: seed &+ 0x9E3779B97F4A7C15)
        random.shuffle(&candidates)
        func nodes(for points: [CGPoint]) -> [Int] {
            var result: [Int] = []
            for (a,b) in zip(points,points.dropFirst()) {
                let steps = Int((abs(a.x-b.x)+abs(a.y-b.y))/cellSize)
                guard steps > 0 else { continue }
                for i in 0...steps {
                    let t = CGFloat(i)/CGFloat(steps)
                    let x = Int((a.x+(b.x-a.x)*t)/cellSize)
                    let y = Int((a.y+(b.y-a.y)*t)/cellSize)
                    let node = owners[y*columns+x]
                    if result.last != node { result.append(node) }
                }
            }
            return result
        }
        for room in layout.rooms where room.id != "you" {
            if Task.isCancelled { return }
            guard let original = routes[room.id], let first = original.first, let last = original.last else { continue }
            let spine = nodes(for: original)
            var attachment = Array(repeating: -1,count: graph.count)
            var parent = Array(repeating: -1,count: graph.count)
            var depth = Array(repeating: 0,count: graph.count)
            var queue = spine, head = 0
            for (index,node) in spine.enumerated() { attachment[node] = index; parent[node] = node }
            while head < queue.count {
                let at = queue[head]; head += 1
                for next in graph[at] where attachment[next] == -1 && next < count {
                    attachment[next] = attachment[at]; parent[next] = at
                    depth[next] = depth[at] + 1; queue.append(next)
                }
            }
            let originalLength = WorldRoad(points: original).length
            var chosen = [Set(spine)]
            func appendChoice(connection originalConnection: [Int], openings: [Door]) -> Bool {
                var connection = originalConnection
                if attachment[connection.first!] > attachment[connection.last!] { connection.reverse() }
                let a = connection.first!, b = connection.last!
                let low = attachment[a], high = attachment[b]
                if low == high && spine[low] >= count { return false }
                var left = [a], right = [b]
                while parent[left.last!] != left.last! { left.append(parent[left.last!]) }
                while parent[right.last!] != right.last! { right.append(parent[right.last!]) }
                let middle = Array(connection.dropFirst().dropLast())
                let journey = Array(spine.prefix(low)) + Array(left.reversed()) + middle + right + Array(spine.dropFirst(high+1))
                let occupied = Set(journey)
                guard chosen.allSatisfy({ old in
                    Double(old.symmetricDifference(occupied).count) / Double(old.union(occupied).count) >= 0.2
                }) else { return false }
                let extra = Dictionary(uniqueKeysWithValues: openings.map { (Edge(owners[$0.a],owners[$0.b]),$0) })
                var points = [first]
                for (from,to) in zip(journey,journey.dropFirst()) {
                    let edge = Edge(from,to)
                    guard let crossing = extra[edge] ?? doors[edge] else { return false }
                    let entry = owners[crossing.a] == from ? crossing.a : crossing.b
                    let exit = entry == crossing.a ? crossing.b : crossing.a
                    appendInsideRoom(center(of: entry),to: &points)
                    points.append(center(of: exit))
                }
                appendInsideRoom(last,to: &points)
                points = simplify(points)
                let length = WorldRoad(points: points).length
                guard length >= originalLength + max(128,originalLength*0.3),
                      length <= originalLength*3 + 512 else { return false }
                chosen.append(occupied)
                alternateRoutes[room.id,default: []].append(points)
                for door in openings {
                    if open.insert(Edge(door.a,door.b)).inserted { passages.append(door) }
                }
                return true
            }
            for allowLoop in [false,true] {
                if allowLoop && chosen.count > 1 { break }
                for door in candidates {
                    if Task.isCancelled { return }
                    let a = owners[door.a], b = owners[door.b]
                    guard attachment[a] >= 0, attachment[b] >= 0 else { continue }
                    let gap = abs(attachment[a]-attachment[b])
                    guard (allowLoop || gap > 0), depth[a]+depth[b]+1 > gap+4 else { continue }
                    _ = appendChoice(connection: [a,b],openings: [door])
                    if chosen.count == 3 { break }
                }
            }
            // A crowded road can be isolated from large filler branches by rooms.
            // Two doorways let it visit one of those existing branches without
            // entering any foreign room or clearing a strip of walls.
            if chosen.count == 1 {
                var entrances: [(known: Int, unknown: Int, door: Door)] = []
                var exits: [Int:[(known: Int, door: Door)]] = [:]
                for door in candidates {
                    var a = owners[door.a], b = owners[door.b]
                    if attachment[a] == -1 { swap(&a,&b) }
                    if attachment[a] >= 0 && attachment[b] == -1 {
                        entrances.append((a,b,door)); exits[b,default: []].append((a,door))
                    }
                }
                for entrance in entrances {
                    if Task.isCancelled { return }
                    var previous = [entrance.unknown: entrance.unknown]
                    var pending = [entrance.unknown], nextIndex = 0
                    while nextIndex < pending.count && chosen.count < 3 {
                        let at = pending[nextIndex]; nextIndex += 1
                        for exit in exits[at] ?? [] where Edge(owners[exit.door.a],owners[exit.door.b]) != Edge(owners[entrance.door.a],owners[entrance.door.b]) {
                            var through = [at]
                            while through.last! != entrance.unknown { through.append(previous[through.last!]!) }
                            let connection = [entrance.known] + Array(through.reversed()) + [exit.known]
                            _ = appendChoice(connection: connection,openings: [entrance.door,exit.door])
                            if chosen.count == 3 { break }
                        }
                        for next in graph[at] where next < count && attachment[next] == -1 && previous[next] == nil {
                            previous[next] = at; pending.append(next)
                        }
                    }
                    if chosen.count >= 2 { break }
                }
            }
        }
        buildWalls(open: open)
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
