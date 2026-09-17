import Foundation

public enum Role: String, Codable, CaseIterable, Sendable {
    case hobby, craft, decision, lab, work
}

public enum NodeKind: String, Codable, CaseIterable, Sendable {
    case quest, practice
}

public enum DaysCue: String, Codable, CaseIterable, Sendable {
    case any, weekday, weekend
}

public enum Window: String, Codable, CaseIterable, Sendable {
    case any, morning, evening
}

public enum PracticeRhythm: String, CaseIterable, Sendable {
    case everyday, weekdays, weekends, few, weekly
}

/// When a node may surface. `on` pins it to one date and overrides `days`.
/// `every` is how many days a practice waits after lastDone. Quests ignore it.
public struct Cue: Hashable, Sendable {
    public var days: DaysCue
    public var window: Window
    public var on: Day?
    public var every: Int

    public init(days: DaysCue = .any, window: Window = .any, on: Day? = nil, every: Int = 1) {
        self.days = days
        self.window = window
        self.on = on
        self.every = max(1, every)
    }

    public static let anytime = Cue()

    public var practiceRhythm: PracticeRhythm {
        get {
            if every >= 7 { return .weekly }
            if every >= 3 { return .few }
            switch days {
            case .weekday: return .weekdays
            case .weekend: return .weekends
            case .any: return .everyday
            }
        }
        set {
            on = nil
            switch newValue {
            case .everyday: days = .any; every = 1
            case .weekdays: days = .weekday; every = 1
            case .weekends: days = .weekend; every = 1
            case .few: days = .any; every = 3
            case .weekly: days = .any; every = 7
            }
        }
    }
}

extension Cue: Codable {
    enum CodingKeys: String, CodingKey { case days, window, on, every }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        days = try c.decodeIfPresent(DaysCue.self, forKey: .days) ?? .any
        window = try c.decodeIfPresent(Window.self, forKey: .window) ?? .any
        on = try c.decodeIfPresent(Day.self, forKey: .on)
        every = max(1, try c.decodeIfPresent(Int.self, forKey: .every) ?? 1)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(days, forKey: .days)
        try c.encode(window, forKey: .window)
        try c.encodeIfPresent(on, forKey: .on)
        if every != 1 { try c.encode(every, forKey: .every) }
    }
}

public enum NodeState: Codable, Hashable, Sendable {
    case todo
    case done(Day)
    case paused
    case notTaken
}

public struct Node: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var kind: NodeKind
    public var title: String
    public var cue: Cue
    /// A single real blocker. The node is not eligible until the blocker is done.
    public var after: UUID?
    public var state: NodeState
    public var lastDone: Day?
    public var consecutiveSkips: Int
    public var createdOn: Day
    /// Last day the user acted on this node (created, done, skipped, edited, kept).
    public var touchedOn: Day
    /// Day a "still want this?" check was surfaced, if any.
    public var staleCheckOn: Day?
    /// Optional for compatibility with existing saved worlds.
    public var outsideHome: Bool?

    public var isOutsideQuest: Bool { kind == .quest && outsideHome == true }

    public init(id: UUID = UUID(), kind: NodeKind, title: String, cue: Cue = .anytime, after: UUID? = nil, createdOn: Day) {
        self.id = id
        self.kind = kind
        self.title = title
        self.cue = cue
        self.after = after
        self.state = .todo
        self.lastDone = nil
        self.consecutiveSkips = 0
        self.createdOn = createdOn
        self.touchedOn = createdOn
        self.staleCheckOn = nil
    }

    public var isOpen: Bool {
        if case .todo = state { return true }
        return false
    }

    public var isDone: Bool {
        if case .done = state { return true }
        return false
    }
}

public struct Milestone: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var text: String
    public var tickedOn: Day?

    public init(id: UUID = UUID(), text: String, tickedOn: Day? = nil) {
        self.id = id
        self.text = text
        self.tickedOn = tickedOn
    }
}

public enum PathStatus: String, Codable, Sendable {
    case active, resting, archived
}

public struct Path: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var identity: String
    public var glyph: String
    public var role: Role
    public var deadline: Day?
    public var status: PathStatus
    public var milestones: [Milestone]
    public var nodes: [Node]

    public init(id: UUID = UUID(), name: String, identity: String, glyph: String, role: Role, deadline: Day? = nil, status: PathStatus = .active, milestones: [Milestone] = [], nodes: [Node] = []) {
        self.id = id
        self.name = name
        self.identity = identity
        self.glyph = glyph
        self.role = role
        self.deadline = deadline
        self.status = status
        self.milestones = milestones
        self.nodes = nodes
    }

    /// Every milestone ticked. An evolved path goes quiet.
    public var isEvolved: Bool {
        !milestones.isEmpty && milestones.allSatisfy { $0.tickedOn != nil }
    }

    public var nextMilestone: Milestone? {
        milestones.first { $0.tickedOn == nil }
    }

    public func node(_ id: UUID) -> Node? {
        nodes.first { $0.id == id }
    }
}

/// One row of history. The app persists these; the engine reads them to enforce cooldowns and rotation.
public struct Surfacing: Codable, Hashable, Sendable {
    public var day: Day
    public var pathID: UUID
    public var nodeID: UUID
    public var kind: ObjectiveKind

    public init(day: Day, pathID: UUID, nodeID: UUID, kind: ObjectiveKind) {
        self.day = day
        self.pathID = pathID
        self.nodeID = nodeID
        self.kind = kind
    }
}

public enum ObjectiveKind: String, Codable, Sendable {
    /// "New objective: ..."
    case objective
    /// "Still want this? ..."
    case staleCheck
}

/// What the engine hands the app for one day.
public struct Objective: Hashable, Sendable {
    public var day: Day
    public var window: Window
    public var pathID: UUID
    public var nodeID: UUID
    public var kind: ObjectiveKind

    public init(day: Day, window: Window, pathID: UUID, nodeID: UUID, kind: ObjectiveKind) {
        self.day = day
        self.window = window
        self.pathID = pathID
        self.nodeID = nodeID
        self.kind = kind
    }

    public var asSurfacing: Surfacing {
        Surfacing(day: day, pathID: pathID, nodeID: nodeID, kind: kind)
    }
}

/// What the user did in response.
public enum Action: String, Codable, Hashable, Sendable {
    case done
    case notNow
    case tooBig
    case keep
    case letGo
    case reopen
}
