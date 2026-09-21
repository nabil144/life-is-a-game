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
    var goingOutOn: Day?
    var outsideReminderAt: Date?
}

/// A Files folder the owner picked once. The bookmark dies with the app, the file does not.
enum Mirror {
    static let bookmarkKey = "worldMirrorBookmark"
    static let promptSeenKey = "mirrorPromptSeen"
    static let fileName = "world.json"

    static func folder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        if stale { try? remember(url) }
        return url
    }

    static func remember(_ url: URL) throws {
        let data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    static func forget() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    static func access<T>(_ url: URL, _ body: (URL) throws -> T) rethrows -> T {
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        return try body(url)
    }
}

enum WorldFile {
    enum Kind { case world(World), bundle(PathBundle) }
    enum ParseError: Error { case unrecognized }

    static func parse(_ data: Data) throws -> Kind {
        let dec = JSONFiles.decoder()
        if let world = try? dec.decode(World.self, from: data) { return .world(world) }
        if let bundle = try? dec.decode(PathBundle.self, from: data) { return .bundle(bundle) }
        throw ParseError.unrecognized
    }
}

@Observable
final class Store {
    private(set) var world = World()
    let planner = Planner()
    private let fileURL: URL
    private let photosURL: URL
    private let injectedMirror: URL?
    private(set) var copyGeneration = 0

    var keepsACopy: Bool {
        _ = copyGeneration
        return (injectedMirror ?? Mirror.folder()) != nil
    }

    init(directory: URL? = nil, mirrorDirectory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LifeIsAGame", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("world.json")
        photosURL = base.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosURL, withIntermediateDirectories: true)
        injectedMirror = mirrorDirectory
        load()
    }

    var today: Day { Day(Date()) }
    var paths: [Path] { world.paths }
    var activePaths: [Path] { world.paths.filter { $0.status != .archived } }

    // MARK: Persistence

    /// A file that does not decode is moved aside, never overwritten. The data outlives the bug.
    /// If the sandbox is empty, a Files copy is the next place to look.
    private func load() {
        if let data = try? Data(contentsOf: fileURL) {
            do {
                world = try JSONFiles.decoder().decode(World.self, from: data)
                return
            } catch {
                let aside = fileURL.deletingLastPathComponent()
                    .appendingPathComponent("world.broken-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: fileURL, to: aside)
                print("world.json did not decode, kept at \(aside.lastPathComponent): \(error)")
            }
        }
        if let data = readMirror() {
            do {
                world = try JSONFiles.decoder().decode(World.self, from: data)
                try? data.write(to: fileURL, options: .atomic)
            } catch {
                print("mirror world.json did not decode: \(error)")
            }
        }
    }

    private func save() {
        guard let data = try? JSONFiles.encoder().encode(world) else { return }
        try? data.write(to: fileURL, options: .atomic)
        writeMirror(data)
    }

    private func mirrorFolder() -> URL? { injectedMirror ?? Mirror.folder() }

    private func writeMirror(_ data: Data) {
        guard let folder = mirrorFolder() else { return }
        let write = { try? data.write(to: folder.appendingPathComponent(Mirror.fileName), options: .atomic) }
        if injectedMirror != nil { write(); return }
        Mirror.access(folder) { _ in write() }
    }

    private func readMirror() -> Data? {
        guard let folder = mirrorFolder() else { return nil }
        let read = { try? Data(contentsOf: folder.appendingPathComponent(Mirror.fileName)) }
        if injectedMirror != nil { return read() }
        return Mirror.access(folder) { _ in read() }
    }

    func exportWorld() throws -> Data {
        try JSONFiles.encoder().encode(world)
    }

    /// Full world if the file has one, otherwise a PathBundle of drafts. Replaces on world, appends on bundle.
    func importData(_ data: Data) throws {
        switch try WorldFile.parse(data) {
        case .world(let w):
            world = w
            if !world.paths.isEmpty { world.onboarded = true }
            save()
        case .bundle(let b):
            let added = try b.paths.map { try $0.begun(on: today) }
            world.paths.append(contentsOf: added)
            if !world.paths.isEmpty { world.onboarded = true }
            save()
        }
    }

    /// Remember a Files folder and write there on every save. If the phone is empty and the folder already has a world, restore it.
    func keepACopy(in folder: URL) throws {
        let adopt = {
            if self.injectedMirror == nil { try Mirror.remember(folder) }
            self.copyGeneration += 1
            if self.world.paths.isEmpty, let data = try? Data(contentsOf: folder.appendingPathComponent(Mirror.fileName)) {
                try self.importData(data)
            } else {
                self.save()
            }
        }
        if injectedMirror != nil { try adopt(); return }
        try Mirror.access(folder) { _ in try adopt() }
    }

    func forgetCopy() {
        Mirror.forget()
        copyGeneration += 1
    }

    // MARK: Lookups

    func path(_ id: UUID) -> Path? { world.paths.first { $0.id == id } }

    func node(_ nodeID: UUID) -> (Path, Node)? {
        for p in world.paths { if let n = p.node(nodeID) { return (p, n) } }
        return nil
    }

    func dueToday() -> [Objective] {
        planner.due(on: today, paths: activePaths)
    }

    var goingOutToday: Bool { world.goingOutOn == today }

    func outsideQuestsToday() -> [Objective] {
        planner.outsideQuests(on: today, paths: activePaths)
    }

    func setGoingOut(_ enabled: Bool) {
        let day = today
        mutate {
            $0.goingOutOn = enabled ? day : nil
            $0.outsideReminderAt = nil
        }
    }

    func setOutsideReminder(_ date: Date?) {
        mutate { $0.outsideReminderAt = date }
    }

    // A stable identity prevents rescheduling merely because another view redraws.
    var outsideReminderSignature: String {
        let items = outsideQuestsToday().compactMap { node($0.nodeID)?.1 }
        let data = (try? JSONEncoder().encode(items)) ?? Data()
        return "\(today)|\(goingOutToday)|\(world.outsideReminderAt?.timeIntervalSince1970 ?? 0)|" + data.base64EncodedString()
    }

    func isDueToday(_ nodeID: UUID) -> Bool {
        dueToday().contains { $0.nodeID == nodeID }
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

    func canUndoRoutineCompletion(_ entry: LogEntry) -> Bool {
        guard entry.milestoneID == nil, let nodeID = entry.nodeID,
              let (path, node) = node(nodeID) else { return false }
        return path.id == entry.pathID && node.kind == .practice
            && world.log.contains { $0.id == entry.id }
    }

    func undoRoutineCompletion(_ entryID: UUID) {
        guard let entry = world.log.first(where: { $0.id == entryID }),
              canUndoRoutineCompletion(entry), let nodeID = entry.nodeID else { return }
        mutate { w in
            guard let p = w.paths.firstIndex(where: { $0.id == entry.pathID }),
                  let n = w.paths[p].nodes.firstIndex(where: { $0.id == nodeID }) else { return }
            w.log.removeAll { $0.id == entryID }
            if w.paths[p].nodes[n].lastDone == entry.day {
                w.paths[p].nodes[n].lastDone = w.log
                    .filter { $0.pathID == entry.pathID && $0.nodeID == nodeID && $0.milestoneID == nil }
                    .map(\.day).max()
            }
        }
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

    func updateNode(_ node: Node, in pathID: UUID) {
        let day = today
        mutate { w in
            guard let p = w.paths.firstIndex(where: { $0.id == pathID }),
                  let n = w.paths[p].nodes.firstIndex(where: { $0.id == node.id }) else { return }
            var node = node
            node.touchedOn = day
            w.paths[p].nodes[n] = node
        }
    }

    /// First tap: the fact became true today. Later changes go through `setMilestone`.
    func tickMilestone(_ milestoneID: UUID, in pathID: UUID) {
        guard let p = path(pathID), let m = p.milestones.first(where: { $0.id == milestoneID }), m.tickedOn == nil else { return }
        setMilestone(milestoneID, in: pathID, tickedOn: today)
    }

    /// Set or clear when a milestone became true. Clearing needs a confirm in the UI. The log follows the date.
    func setMilestone(_ milestoneID: UUID, in pathID: UUID, tickedOn day: Day?) {
        mutate { w in
            guard let p = w.paths.firstIndex(where: { $0.id == pathID }),
                  let m = w.paths[p].milestones.firstIndex(where: { $0.id == milestoneID }) else { return }
            let was = w.paths[p].milestones[m].tickedOn
            w.paths[p].milestones[m].tickedOn = day
            if let day {
                if let i = w.log.lastIndex(where: { $0.milestoneID == milestoneID }) {
                    w.log[i].day = day
                } else if was == nil {
                    w.log.append(LogEntry(day: day, pathID: pathID, milestoneID: milestoneID, text: w.paths[p].milestones[m].text))
                }
            } else {
                w.log.removeAll { $0.milestoneID == milestoneID }
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
