import Foundation

/// The authoring shape. Blockers reference titles, not ids, so a human or an agent can write it by hand.
public struct PathDraft: Codable, Equatable, Sendable {
    public struct NodeDraft: Codable, Equatable, Sendable {
        public var kind: NodeKind
        public var title: String
        public var cue: Cue
        public var after: String?

        public init(kind: NodeKind, title: String, cue: Cue = .anytime, after: String? = nil) {
            self.kind = kind
            self.title = title
            self.cue = cue
            self.after = after
        }
    }

    public var name: String
    public var identity: String
    public var glyph: String
    public var role: Role
    public var deadline: Day?
    public var milestones: [String]
    public var nodes: [NodeDraft]

    public init(name: String, identity: String, glyph: String, role: Role, deadline: Day? = nil, milestones: [String], nodes: [NodeDraft]) {
        self.name = name
        self.identity = identity
        self.glyph = glyph
        self.role = role
        self.deadline = deadline
        self.milestones = milestones
        self.nodes = nodes
    }

    public enum DraftError: Error, Equatable {
        case unknownBlocker(node: String, after: String)
        case duplicateTitle(String)
    }

    /// Resolve titles to ids. Fails loudly on a typo in `after` rather than silently dropping the blocker.
    public func instantiate(on day: Day) throws -> Path {
        var ids: [String: UUID] = [:]
        for n in nodes {
            guard ids[n.title] == nil else { throw DraftError.duplicateTitle(n.title) }
            ids[n.title] = UUID()
        }
        let built = try nodes.map { d -> Node in
            var after: UUID? = nil
            if let a = d.after {
                guard let id = ids[a] else { throw DraftError.unknownBlocker(node: d.title, after: a) }
                after = id
            }
            return Node(id: ids[d.title]!, kind: d.kind, title: d.title, cue: d.cue, after: after, createdOn: day)
        }
        return Path(
            name: name, identity: identity, glyph: glyph, role: role, deadline: deadline,
            milestones: milestones.map { Milestone(text: $0) },
            nodes: built
        )
    }
}

/// One file under `templates/`.
public struct Template: Codable, Sendable {
    public var id: String
    public var title: String
    public var path: PathDraft
}

/// One file under `testdata/` or a phase 2 export.
public struct PathBundle: Codable, Sendable {
    public var paths: [PathDraft]

    public init(paths: [PathDraft]) {
        self.paths = paths
    }
}

public enum JSONFiles {
    public static func decoder() -> JSONDecoder {
        JSONDecoder()
    }

    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}
