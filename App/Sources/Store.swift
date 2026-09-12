import Foundation
import Observation
import LifeEngine

/// SwiftUI also exports a `Path` (the drawing shape). This app never draws one, so the engine's Path wins module-wide.
typealias Path = LifeEngine.Path

struct LogEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var day: Day
    var pathID: UUID
    var nodeID: UUID?
    var milestoneID: UUID?
    var text: String
    var photoFile: String?
}

/// Everything the app knows, as one document.
struct World: Codable {
    var paths: [Path] = []
    var history: [Surfacing] = []
    var log: [LogEntry] = []
    var onboarded = false
}

@Observable
final class Store {
    private(set) var world = World()
    let planner = Planner()
    private let fileURL: URL
    private let photosURL: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LifeIsAGame", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("world.json")
        photosURL = base.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosURL, withIntermediateDirectories: true)
        load()
    }

    var today: Day { Day(Date()) }
    var paths: [Path] { world.paths }
    var activePaths: [Path] { world.paths.filter { $0.status != .archived } }

    // MARK: Persistence

    /// A file that does not decode is moved aside, never overwritten. The data outlives the bug.
    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            world = try JSONFiles.decoder().decode(World.self, from: data)
        } catch {
            let aside = fileURL.deletingLastPathComponent()
                .appendingPathComponent("world.broken-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: aside)
            print("world.json did not decode, kept at \(aside.lastPathComponent): \(error)")
        }
    }

    private func save() {
        guard let data = try? JSONFiles.encoder().encode(world) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func exportBundle() throws -> Data {
        let drafts = world.paths.map { p in
            PathDraft(name: p.name, identity: p.identity, glyph: p.glyph, role: p.role, deadline: p.deadline,
                      milestones: p.milestones.map(\.text),
                      nodes: p.nodes.filter(\.isOpen).map { n in
                          .init(kind: n.kind, title: n.title, cue: n.cue, after: n.after.flatMap { p.node($0)?.title })
                      })
        }
        return try JSONFiles.encoder().encode(PathBundle(paths: drafts))
    }

    // MARK: Lookups

    func path(_ id: UUID) -> Path? { world.paths.first { $0.id == id } }

    func node(_ nodeID: UUID) -> (Path, Node)? {
        for p in world.paths { if let n = p.node(nodeID) { return (p, n) } }
        return nil
    }

    func todaysObjective() -> Objective? {
        let day = today
        guard let s = world.history.last(where: { $0.day == day }) else { return nil }
        guard let (p, n) = node(s.nodeID), n.isOpen, p.status == .active else { return nil }
        let window = n.cue.window == .any ? (planner.roleWindow(p.role, on: day) ?? .any) : n.cue.window
        return Objective(day: day, window: window, pathID: s.pathID, nodeID: s.nodeID, kind: s.kind)
    }

    func log(for pathID: UUID) -> [LogEntry] {
        world.log.filter { $0.pathID == pathID }.sorted { $0.day > $1.day }
    }

    func recentLog(limit: Int = 5) -> [LogEntry] {
        Array(world.log.sorted { $0.day > $1.day }.prefix(limit))
    }

    // MARK: Mutations

    private func mutate(_ change: (inout World) -> Void) {
        change(&world)
        save()
    }

    func add(_ path: Path) {
        mutate { $0.paths.append(path); $0.onboarded = true }
    }

    func update(_ path: Path) {
        mutate { w in
            if let i = w.paths.firstIndex(where: { $0.id == path.id }) { w.paths[i] = path }
        }
    }

    func addNode(_ node: Node, to pathID: UUID) {
        mutate { w in
            guard let i = w.paths.firstIndex(where: { $0.id == pathID }) else { return }
            w.paths[i].nodes.append(node)
        }
    }

    func tickMilestone(_ milestoneID: UUID, in pathID: UUID) {
        let day = today
        mutate { w in
            guard let p = w.paths.firstIndex(where: { $0.id == pathID }),
                  let m = w.paths[p].milestones.firstIndex(where: { $0.id == milestoneID }) else { return }
            let already = w.paths[p].milestones[m].tickedOn != nil
            w.paths[p].milestones[m].tickedOn = already ? nil : day
            if !already {
                w.log.append(LogEntry(day: day, pathID: pathID, milestoneID: milestoneID, text: w.paths[p].milestones[m].text))
            }
        }
    }

    /// Respond to an objective. Returns the node after the change so the UI can react.
    @discardableResult
    func respond(_ action: Action, nodeID: UUID, note: String? = nil, photo: Data? = nil) -> Node? {
        let day = today
        guard let pathID = node(nodeID)?.0.id else { return nil }
        var result: Node?
        mutate { w in
            guard let p = w.paths.firstIndex(where: { $0.id == pathID }),
                  let n = w.paths[p].nodes.firstIndex(where: { $0.id == nodeID }) else { return }
            planner.apply(action, to: &w.paths[p].nodes[n], on: day)
            result = w.paths[p].nodes[n]
            if action == .done {
                var entry = LogEntry(day: day, pathID: w.paths[p].id, nodeID: nodeID, text: note ?? w.paths[p].nodes[n].title)
                if let photo { entry.photoFile = savePhoto(photo) }
                w.log.append(entry)
            }
        }
        return result
    }

    private func savePhoto(_ data: Data) -> String? {
        let name = UUID().uuidString + ".jpg"
        return (try? data.write(to: photosURL.appendingPathComponent(name))) == nil ? nil : name
    }

    func photoURL(_ file: String) -> URL { photosURL.appendingPathComponent(file) }

    // MARK: Planning

    /// Idempotent. Drops any future plan, reconciles time-based transitions, plans the next seven days, returns them for scheduling.
    func refreshPlan(days: Int = 7) -> [Objective] {
        let day = today
        var planned: [Objective] = []
        mutate { w in
            w.paths = planner.reconcile(w.paths, on: day)
            w.history.removeAll { $0.day > day }
            for p in w.paths.indices {
                for n in w.paths[p].nodes.indices where (w.paths[p].nodes[n].staleCheckOn ?? day) > day {
                    w.paths[p].nodes[n].staleCheckOn = nil
                }
            }
            let start = w.history.contains { $0.day == day } ? 1 : 0
            let horizon = (start..<days).map { day.adding(days: $0) }
            planned = planner.plan(days: horizon, paths: w.paths, history: w.history)
            for o in planned {
                w.history.append(o.asSurfacing)
                planner.record(o, in: &w.paths)
            }
        }
        return planned
    }

    func upcoming() -> [Objective] {
        let day = today
        return world.history.filter { $0.day > day }.compactMap { s in
            guard let (p, n) = node(s.nodeID) else { return nil }
            let window = n.cue.window == .any ? (planner.roleWindow(p.role, on: s.day) ?? .any) : n.cue.window
            return Objective(day: s.day, window: window, pathID: s.pathID, nodeID: s.nodeID, kind: s.kind)
        }
    }
}
