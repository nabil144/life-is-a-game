import SwiftUI
import FoundationModels
import LifeEngine

/// The on-device model, and the one-line reason when it cannot answer.
enum Talk {
    /// `ready` opens the chat. `off` is something the person can change. `never` is this hardware.
    enum State {
        case ready
        case off(String)
        case never(String)

        var reason: String? {
            switch self {
            case .ready: nil
            case .off(let s), .never(let s): s
            }
        }
    }

    static var state: State {
        switch SystemLanguageModel.default.availability {
        case .available:
            .ready
        case .unavailable(.deviceNotEligible):
            .never("This iPhone cannot run the on-device model. The form stays.")
        case .unavailable(.appleIntelligenceNotEnabled):
            .off("Turn on Apple Intelligence in iOS Settings to create paths by talking.")
        case .unavailable(.modelNotReady):
            .off("The on-device model is still downloading. Try again later.")
        case .unavailable:
            .off("The on-device model is not available right now.")
        @unknown default:
            .off("The on-device model is not available right now.")
        }
    }

    static let opening = "What is the thing? Say it however it comes."
    static let trouble = "Could not take that in. Say it another way, or press Begin with what is here."

    static let instructions = """
        You help a person write down a path: something they want to get better at or finish, for their own reasons. \
        You ask one short question at a time and you write down what they say, in their words. \
        Never praise, cheer, encourage, or motivate. No exclamation marks. Plain, warm, curious. \
        Do not invent milestones or quests they did not say or clearly imply. Ask instead. \
        A path has a name (their words), one or more milestones (a sentence that will be true when it has moved, like "It holds tune" or "I played it for someone"), \
        and small quests (things finishable in one sitting) or practices (things they return to). \
        Good questions: what would be true when this has moved? what is one small thing you could do on a free evening? \
        is this a hobby, a craft, a decision with a deadline, a lab to tinker in, or work? \
        Once there is a name, one milestone, and one quest, ask only whether there is anything else.
        """
}

/// What the model fills in each turn. The whole path so far, then the next question.
@Generable(description: "The path so far and the next question")
struct Turn {
    @Guide(description: "The path so far, only from what the person said")
    var path: Sketch
    @Guide(description: "One short question. Once there is a name, a milestone, and a quest, ask only if there is anything else")
    var question: String
}

@Generable(description: "A path a person is evolving, in their words")
struct Sketch {
    @Guide(description: "What they are evolving, in their words, two to six words")
    var name: String
    @Guide(description: "Who they are on this path, one or two words like Guitarist. Empty until it is clear")
    var identity: String
    var kind: Kind
    @Guide(description: "Sentences that will be true when this has moved, their words", .maximumCount(4))
    var milestones: [String]
    @Guide(description: "Small things they could do in one sitting, their words", .maximumCount(5))
    var quests: [String]
    @Guide(description: "Things they return to regularly, their words", .maximumCount(3))
    var practices: [String]

    @Generable(description: "hobby for their own joy, craft to get good at, decision with a deadline, lab to tinker in, work")
    enum Kind: String {
        case hobby, craft, decision, lab, work
    }

    var draft: PathDraft {
        PathDraft(
            name: name, identity: identity, glyph: "", role: Role(rawValue: kind.rawValue) ?? .hobby, deadline: nil,
            milestones: milestones,
            nodes: quests.map { .init(kind: .quest, title: $0) }
                + practices.map { .init(kind: .practice, title: $0, cue: Cue(window: .evening)) }
        )
    }
}

extension PathDraft {
    /// The draft as plain lines, for the model to read back after a hand edit.
    var spoken: String {
        var lines = ["Name: \(name)", "Who: \(identity)", "Kind: \(role.rawValue)"]
        if !milestones.isEmpty { lines.append("Milestones: " + milestones.joined(separator: "; ")) }
        let quests = nodes.filter { $0.kind == .quest }.map(\.title)
        let practices = nodes.filter { $0.kind == .practice }.map(\.title)
        if !quests.isEmpty { lines.append("Quests: " + quests.joined(separator: "; ")) }
        if !practices.isEmpty { lines.append("Practices: " + practices.joined(separator: "; ")) }
        return lines.joined(separator: "\n")
    }

    var isEmptySketch: Bool {
        name.isEmpty && identity.isEmpty && milestones.isEmpty && nodes.isEmpty
    }
}

/// Picks the New path surface. The Settings toggle decides which opens first; both offer the other.
struct NewPathSheet: View {
    @AppStorage(Prefs.talkKey) private var talk = false
    @State private var talking: Bool?

    var body: some View {
        let state = Talk.state
        if case .ready = state, talking ?? talk {
            TalkPathView(typeInstead: { talking = false })
        } else {
            NewPathView(talk: state, talkInstead: { talking = true })
        }
    }
}

struct TalkPathView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let typeInstead: () -> Void

    @State private var session = LanguageModelSession(instructions: Talk.instructions)
    @State private var lines = [Line(mine: false, text: Talk.opening)]
    @State private var input = ""
    @State private var draft = PathDraft.blank
    @State private var heard = PathDraft.blank
    @State private var trouble: String?
    @FocusState private var composing: Bool

    struct Line: Identifiable {
        let id = UUID()
        let mine: Bool
        let text: String
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(lines) { line in
                                Bubble(line: line)
                            }
                            if session.isResponding {
                                ProgressView().padding(.horizontal, 8)
                            }
                            if let trouble {
                                Text(trouble).font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 8)
                            }
                            if !draft.isEmptySketch {
                                SketchCard(draft: $draft)
                            }
                            Color.clear.frame(height: 1).id("end")
                        }
                        .padding()
                    }
                    .onChange(of: lines.count) { _, _ in
                        withAnimation { proxy.scrollTo("end", anchor: .bottom) }
                    }
                }
                composer
            }
            .navigationTitle("New path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Begin") { begin() }.disabled(!draft.isBeginnable)
                }
            }
            .onAppear { composing = true }
        }
    }

    private var composer: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom) {
                TextField("Say it however it comes", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .focused($composing)
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isResponding)
            }
            Button("Type it instead", action: typeInstead)
                .font(.footnote)
        }
        .padding()
        .background(.bar)
    }

    private func send() {
        let said = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !said.isEmpty, !session.isResponding else { return }
        input = ""
        trouble = nil
        let first = lines.count == 1
        let prompt = draft == heard
            ? said
            : said + "\n\nThe person edited the path by hand. Build on this version:\n" + draft.spoken
        lines.append(Line(mine: true, text: said))
        Task {
            do {
                let turn = try await session.respond(to: prompt, generating: Turn.self, includeSchemaInPrompt: first).content
                draft = turn.path.draft
                heard = draft
                lines.append(Line(mine: false, text: turn.question))
            } catch {
                trouble = Talk.trouble
            }
        }
    }

    private func begin() {
        guard let path = try? draft.begun(on: store.today) else { return }
        store.add(path)
        dismiss()
    }
}

private struct Bubble: View {
    let line: TalkPathView.Line

    var body: some View {
        HStack {
            if line.mine { Spacer(minLength: 40) }
            Text(line.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(line.mine ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(uiColor: .secondarySystemFill)), in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(line.mine ? .white : .primary)
            if !line.mine { Spacer(minLength: 40) }
        }
    }
}

/// The path so far. Every line is a text field, so a tap edits it.
private struct SketchCard: View {
    @Binding var draft: PathDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: draft.glyph.isEmpty ? draft.role.glyph : draft.glyph).foregroundStyle(.tint)
                TextField("What are you evolving?", text: $draft.name).font(.headline)
            }
            TextField("Who are you on this path?", text: $draft.identity)
                .font(.subheadline).foregroundStyle(.secondary)
            Picker("Kind", selection: $draft.role) {
                ForEach(Role.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            if !draft.milestones.isEmpty {
                Text("Milestones").font(.caption).foregroundStyle(.secondary)
                ForEach(draft.milestones.indices, id: \.self) { i in
                    HStack(alignment: .top) {
                        Image(systemName: "circle").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                        TextField("", text: $draft.milestones[i], axis: .vertical)
                    }
                }
            }
            if !draft.nodes.isEmpty {
                Text("Quests and practices").font(.caption).foregroundStyle(.secondary)
                ForEach(draft.nodes.indices, id: \.self) { i in
                    HStack(alignment: .top) {
                        Image(systemName: draft.nodes[i].kind == .quest ? "diamond" : "arrow.trianglehead.2.clockwise")
                            .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                        TextField("", text: $draft.nodes[i].title, axis: .vertical)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
