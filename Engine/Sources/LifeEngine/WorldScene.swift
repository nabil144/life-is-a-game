import Foundation

/// Only one ownership level is projected into a maze. Domain nodes remain unchanged.
public enum WorldScene: Hashable, Sendable {
    case world
    case path(UUID)

    public var pathID: UUID? {
        if case .path(let id) = self { return id }
        return nil
    }

    public func inputs(paths: [Path]) -> [WorldLayout.Input] {
        let active = paths.filter { $0.status != .archived }
        switch self {
        case .world:
            return active.map { .init(id: $0.id, work: []) }
        case .path(let id):
            return (active.first { $0.id == id }?.nodes ?? [])
                .filter(\.isOpen).map { .init(id: $0.id, work: []) }
        }
    }
}
