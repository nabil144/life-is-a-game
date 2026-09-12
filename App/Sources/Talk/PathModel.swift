import Foundation
import LifeEngine

/// What the model fills in each turn. The whole path so far, then the next question.
struct Turn: Codable {
    var path: Sketch
    var question: String

    /// One JSON Schema for both providers. Closed objects, every property required, no count constraints (Anthropic drops them).
    static var schema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "What they are evolving, in their words, two to six words. Empty until said."],
                        "identity": ["type": "string", "description": "Who they are on this path, one or two words like Guitarist. Empty until it is clear."],
                        "kind": ["type": "string", "enum": ["hobby", "craft", "decision", "lab", "work"], "description": "hobby for their own joy, craft to get good at, decision with a deadline, lab to tinker in, work."],
                        "milestones": ["type": "array", "items": ["type": "string"], "description": "Sentences that will be true when this has moved, their words. At most four."],
                        "quests": ["type": "array", "items": ["type": "string"], "description": "Small things they could do in one sitting, their words. At most five."],
                        "practices": ["type": "array", "items": ["type": "string"], "description": "Things they return to regularly, their words. At most three."],
                    ],
                    "required": ["name", "identity", "kind", "milestones", "quests", "practices"],
                    "additionalProperties": false,
                ],
                "question": ["type": "string", "description": "One short question. Once there is a name, a milestone, and a quest, ask only if there is anything else."],
            ],
            "required": ["path", "question"],
            "additionalProperties": false,
        ]
    }
}

struct Sketch: Codable {
    var name: String
    var identity: String
    var kind: String
    var milestones: [String]
    var quests: [String]
    var practices: [String]

    var draft: PathDraft {
        PathDraft(
            name: name, identity: identity, glyph: "", role: Role(rawValue: kind.lowercased()) ?? .hobby, deadline: nil,
            milestones: milestones,
            nodes: quests.map { .init(kind: .quest, title: $0) }
                + practices.map { .init(kind: .practice, title: $0, cue: Cue(window: .evening)) }
        )
    }
}

struct ChatMessage {
    enum Role: String { case user, assistant }
    var role: Role
    var text: String
}

/// One plain sentence per failure. The draft is never lost over any of these.
enum TalkError: Error {
    case offline
    case badKey
    case busy
    case refused(String)
    case unreadable

    var sentence: String {
        switch self {
        case .offline: "No connection. Your words are kept. Try again when you are back online."
        case .badKey: "The API key was not accepted. Check it in Settings."
        case .busy: "The model is busy. Wait a moment and send again."
        case .refused(let why): "The model could not answer. \(why)"
        case .unreadable: "Could not read the model's answer. Say it again, or press Begin with what is here."
        }
    }
}

protocol PathModel {
    func respond(_ messages: [ChatMessage]) async throws -> Turn
}

/// Bring your own key. The phone talks to the provider directly, nothing in between.
enum Provider: String, CaseIterable, Identifiable {
    case openAI
    case anthropic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: "gpt-5.6-terra"
        case .anthropic: "claude-haiku-4-5"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openAI: "sk-..."
        case .anthropic: "sk-ant-..."
        }
    }

    var keysURL: URL {
        switch self {
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")!
        }
    }

    var endpoint: URL {
        switch self {
        case .openAI: URL(string: "https://api.openai.com/v1/responses")!
        case .anthropic: URL(string: "https://api.anthropic.com/v1/messages")!
        }
    }

    func request(key: String, model: String, instructions: String, messages: [ChatMessage]) throws -> URLRequest {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let turns = messages.map { ["role": $0.role.rawValue, "content": $0.text] }
        let body: [String: Any]
        switch self {
        case .openAI:
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            body = [
                "model": model,
                "instructions": instructions,
                "input": turns,
                "text": ["format": ["type": "json_schema", "name": "turn", "strict": true, "schema": Turn.schema]],
            ]
        case .anthropic:
            req.setValue(key, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            body = [
                "model": model,
                "max_tokens": 1024,
                "system": instructions,
                "messages": turns,
                "output_config": ["format": ["type": "json_schema", "schema": Turn.schema]],
            ]
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    /// The model's JSON text, out of each provider's envelope.
    func outputText(in data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        switch self {
        case .openAI:
            for item in json["output"] as? [[String: Any]] ?? [] where item["type"] as? String == "message" {
                for part in item["content"] as? [[String: Any]] ?? [] where part["type"] as? String == "output_text" {
                    return part["text"] as? String
                }
            }
            return nil
        case .anthropic:
            for part in json["content"] as? [[String: Any]] ?? [] where part["type"] as? String == "text" {
                return part["text"] as? String
            }
            return nil
        }
    }

    static func errorMessage(in data: Data) -> String? {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["error"] as? [String: Any])?["message"] as? String
    }
}

struct CloudPathModel: PathModel {
    var provider: Provider
    var key: String
    var model: String

    func respond(_ messages: [ChatMessage]) async throws -> Turn {
        let req = try provider.request(key: key, model: model, instructions: Talk.instructions, messages: messages)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw TalkError.offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200...299: break
        case 401, 403: throw TalkError.badKey
        case 429: throw TalkError.busy
        default: throw TalkError.refused(Provider.errorMessage(in: data) ?? "HTTP \(status).")
        }
        guard let text = provider.outputText(in: data),
              let turn = try? JSONDecoder().decode(Turn.self, from: Data(text.utf8)) else {
            throw TalkError.unreadable
        }
        return turn
    }
}
