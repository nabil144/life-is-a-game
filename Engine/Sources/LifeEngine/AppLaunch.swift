import Foundation

/// Optional launcher data travels with a quest or routine in normal backups.
public struct AppLaunch: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable { case shortcut, appLink }
    public var kind: Kind
    public var name: String
    public var target: String
    public init(kind: Kind, name: String = "", target: String = "") {
        self.kind = kind; self.name = name; self.target = target
    }
    public var label: String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Open app" : "Open \(clean)"
    }
    public var url: URL? {
        let clean = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        if kind == .shortcut {
            var parts = URLComponents()
            parts.scheme = "shortcuts"; parts.host = "run-shortcut"
            parts.queryItems = [URLQueryItem(name: "name", value: clean)]
            return parts.url
        }
        guard !clean.contains(where: { $0.isWhitespace }),
              let parts = URLComponents(string: clean), let scheme = parts.scheme?.lowercased(),
              !["file", "javascript", "data"].contains(scheme),
              (scheme != "https" && scheme != "http") || !(parts.host ?? "").isEmpty else { return nil }
        return parts.url
    }
}
