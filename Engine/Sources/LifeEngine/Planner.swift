import Foundation

public struct PlannerConfig: Sendable {
    /// `Calendar.weekday` values that count as weekend. Default Saturday and Sunday.
    public var weekendWeekdays: Set<Int> = [1, 7]
    public var repeatCooldownDays = 7
    public var staleAfterDays = 30
    public var notTakenAfterDays = 7
    public var decisionCadenceDays = 7
    public var decisionFinalDays = 3

    public init() {}
}

/// Pure rules. Today lists every node that is due. Notifications still pick one. Never touches storage.
public struct Planner: Sendable {
    public var config: PlannerConfig

    public init(config: PlannerConfig = PlannerConfig()) {
        self.config = config
    }

    public func isWeekend(_ day: Day) -> Bool {
        config.weekendWeekdays.contains(day.weekday)
    }

    /// The window a role may surface in on this day. `nil` means the role is silent that day.
    public func roleWindow(_ role: Role, on day: Day) -> Window? {
        let weekend = isWeekend(day)
        switch role {
        case .hobby, .craft, .decision: return weekend ? .morning : .evening
        case .lab: return weekend ? .morning : nil
        case .work: return weekend ? nil : .morning
        }
    }

    // MARK: Picking

    public func objective(for day: Day, paths: [Path], history: [Surfacing]) -> Objective? {
        candidates(for: day, paths: paths, history: history).first
    }

    /// Everything that can be done on this day. No seven-day cooldown. A practice waits `cue.every` days after lastDone, then the next day that still matches its cue.
    public func due(on day: Day, paths: [Path]) -> [Objective] {
        var found: [Objective] = []
        for path in paths {
            guard path.status == .active, !path.isEvolved else { continue }
            let baseWindow = roleWindow(path.role, on: day)
            let finalDays = isInFinalDays(path, on: day)
            let cadenceAllows = path.role != .decision || finalDays || decisionCadenceAllows(path, on: day, history: [])

            for node in path.nodes {
                guard node.isOpen else { continue }
                if !practiceReady(node, on: day) { continue }
                if let after = node.after, let blocker = path.node(after), !blocker.isDone { continue }
                guard cueMatchesDay(node.cue, day: day) else { continue }
                // An exact date overrides hidden day/time choices and the path's
                // usual cadence. Keep those preferences intact for date mode off.
                guard node.cue.on != nil || (baseWindow != nil && cadenceAllows) else { continue }
                let window: Window = node.cue.on != nil ? .any
                    : (node.cue.window == .any ? (baseWindow ?? .any) : node.cue.window)
                found.append(Objective(day: day, window: window, pathID: path.id, nodeID: node.id, kind: .objective))
            }
        }
        return found
    }

    /// Outing highlights respect the same dates, path status and blockers as Today.
    public func outsideQuests(on day: Day, paths: [Path]) -> [Objective] {
        let ids = Set(paths.flatMap(\.nodes).filter(\.isOutsideQuest).map(\.id))
        return due(on: day, paths: paths).filter { ids.contains($0.nodeID) }
    }

    /// Plan several days ahead. Each pick is fed back as history so the same node is not chosen twice in a row.
    public func plan(days: [Day], paths: [Path], history: [Surfacing]) -> [Objective] {
        var paths = paths
        var history = history
        var out: [Objective] = []
        for day in days.sorted() {
            guard let o = objective(for: day, paths: paths, history: history) else { continue }
            out.append(o)
            history.append(o.asSurfacing)
            record(o, in: &paths)
        }
        return out
    }

    /// Side effects of a surfacing the app has committed to. Call this when the notification is scheduled or shown.
    public func record(_ objective: Objective, in paths: inout [Path]) {
        guard objective.kind == .staleCheck,
              let p = paths.firstIndex(where: { $0.id == objective.pathID }),
              let n = paths[p].nodes.firstIndex(where: { $0.id == objective.nodeID }) else { return }
        paths[p].nodes[n].staleCheckOn = objective.day
    }

    struct Candidate {
        var objective: Objective
        var finalDaysDecision: Bool
        var rotates: Bool
        var neverSurfaced: Bool
        var lastSurfaced: Day?
        var order: (Int, Int)
    }

    func candidates(for day: Day, paths: [Path], history: [Surfacing]) -> [Objective] {
        let lastPath = history.max(by: { $0.day < $1.day })?.pathID
        var found: [Candidate] = []

        for (pi, path) in paths.enumerated() {
            guard path.status == .active, !path.isEvolved else { continue }
            let baseWindow = roleWindow(path.role, on: day)
            let finalDays = isInFinalDays(path, on: day)
            let cadenceAllows = path.role != .decision || finalDays || decisionCadenceAllows(path, on: day, history: history)

            for (ni, node) in path.nodes.enumerated() {
                guard node.isOpen else { continue }
                if !practiceReady(node, on: day) { continue }
                if let after = node.after, let blocker = path.node(after), !blocker.isDone { continue }
                guard cueMatchesDay(node.cue, day: day) else { continue }
                // An exact date overrides hidden day/time choices and the path's
                // usual cadence. Keep those preferences intact for date mode off.
                guard node.cue.on != nil || (baseWindow != nil && cadenceAllows) else { continue }
                let window: Window = node.cue.on != nil ? .any
                    : (node.cue.window == .any ? (baseWindow ?? .any) : node.cue.window)

                let surfacings = history.filter { $0.nodeID == node.id }
                let last = surfacings.map(\.day).max()
                if let last, day.days(since: last) < config.repeatCooldownDays { continue }

                let kind: ObjectiveKind = isStale(node, on: day, surfacings: surfacings) ? .staleCheck : .objective
                found.append(Candidate(
                    objective: Objective(day: day, window: window, pathID: path.id, nodeID: node.id, kind: kind),
                    finalDaysDecision: finalDays,
                    rotates: lastPath == nil || lastPath != path.id,
                    neverSurfaced: last == nil,
                    lastSurfaced: last,
                    order: (pi, ni)
                ))
            }
        }

        return found.sorted(by: rank).map(\.objective)
    }

    func rank(_ a: Candidate, _ b: Candidate) -> Bool {
        if a.finalDaysDecision != b.finalDaysDecision { return a.finalDaysDecision }
        if a.rotates != b.rotates { return a.rotates }
        if a.neverSurfaced != b.neverSurfaced { return a.neverSurfaced }
        if let la = a.lastSurfaced, let lb = b.lastSurfaced, la != lb { return la < lb }
        return a.order < b.order
    }

    func practiceReady(_ node: Node, on day: Day) -> Bool {
        guard node.kind == .practice else { return true }
        guard let last = node.lastDone else { return true }
        return day.days(since: last) >= max(node.cue.every, 1)
    }

    func cueMatchesDay(_ cue: Cue, day: Day) -> Bool {
        if let on = cue.on { return on == day }
        switch cue.days {
        case .any: return true
        case .weekday: return !isWeekend(day)
        case .weekend: return isWeekend(day)
        }
    }

    func isInFinalDays(_ path: Path, on day: Day) -> Bool {
        guard path.role == .decision, let deadline = path.deadline else { return false }
        let left = deadline.days(since: day)
        return left >= 0 && left <= config.decisionFinalDays
    }

    func decisionCadenceAllows(_ path: Path, on day: Day, history: [Surfacing]) -> Bool {
        guard let last = history.filter({ $0.pathID == path.id }).map(\.day).max() else { return true }
        return day.days(since: last) >= config.decisionCadenceDays
    }

    /// Untouched for a month and surfaced at least once since the last touch. Time to ask instead of push.
    func isStale(_ node: Node, on day: Day, surfacings: [Surfacing]) -> Bool {
        guard node.staleCheckOn == nil else { return false }
        guard day.days(since: node.touchedOn) >= config.staleAfterDays else { return false }
        return surfacings.contains { $0.day > node.touchedOn }
    }

    // MARK: Responding

    public func apply(_ action: Action, to node: inout Node, on day: Day) {
        switch action {
        case .done:
            switch node.kind {
            case .quest: node.state = .done(day)
            case .practice: node.lastDone = day
            }
            node.consecutiveSkips = 0
        case .notNow:
            node.consecutiveSkips += 1
            if node.consecutiveSkips >= 2 { node.state = .paused }
        case .tooBig:
            break
        case .keep:
            break
        case .letGo:
            node.state = .notTaken
            return
        case .reopen:
            node.state = .todo
            node.consecutiveSkips = 0
        }
        node.touchedOn = day
        node.staleCheckOn = nil
    }

    /// Time-based transitions the user did not trigger. Run on app open and daily refresh.
    public func reconcile(_ paths: [Path], on day: Day) -> [Path] {
        paths.map { path in
            var path = path
            for i in path.nodes.indices {
                let n = path.nodes[i]
                guard n.isOpen, let asked = n.staleCheckOn, n.touchedOn < asked else { continue }
                if day.days(since: asked) >= config.notTakenAfterDays {
                    path.nodes[i].state = .notTaken
                }
            }
            return path
        }
    }
}
