import SwiftUI
import LifeEngine

/// Whether a path can be talked through. Ready when a key is saved for the chosen provider.
enum Talk {
    enum State {
        case ready(CloudPathModel)
        case off(String)

        var reason: String? {
            switch self {
            case .ready: nil
            case .off(let s): s
            }
        }
    }

    static var state: State {
        let provider = Prefs.provider
        guard let key = KeyStore.read(provider.rawValue) else {
            return .off("Add an API key in Settings to create paths by talking.")
        }
        return .ready(CloudPathModel(provider: provider, key: key, model: Prefs.model))
    }

    static let opening = "What is the thing? Say it however it comes."

    static let instructions = """
        You help a person write down a path: something they want to get better at or finish, for their own reasons. \
        You ask one short question at a time and you write down what they say, in their words. \
        Never praise, cheer, encourage, or motivate. No exclamation marks. Plain, warm, curious. \
        Do not invent milestones or quests they did not say or clearly imply. Ask instead. \
        A path has a name (their words), one or more milestones (a sentence that will be true when it has moved, like "It holds tune" or "I played it for someone"), \
        and small quests (things finishable in one sitting) or routines (things they return to). \
        Good questions: what would be true when this has moved? what is one small thing you could do on a free evening? \
        is this a hobby, a craft, a decision with a deadline, a lab to tinker in, or work? \
        Once there is a name, one milestone, and one quest, ask only whether there is anything else. \
        Every reply carries the whole path so far, and only what the person has said.
        """
}

extension PathDraft {
    /// The draft as plain lines, for the model to read back after a hand edit.
    var spoken: String {
        var lines = ["Name: \(name)", "Who: \(identity)", "Kind: \(role.rawValue)"]
        if !milestones.isEmpty { lines.append("Milestones: " + milestones.joined(separator: "; ")) }
        let quests = nodes.filter { $0.kind == .quest }.map(\.title)
        let routines = nodes.filter { $0.kind == .practice }.map(\.title)
        if !quests.isEmpty { lines.append("Quests: " + quests.joined(separator: "; ")) }
        if !routines.isEmpty { lines.append("Routines: " + routines.joined(separator: "; ")) }
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
        if case .ready(let model) = state, talking ?? talk {
            TalkPathView(model: model, typeInstead: { talking = false })
        } else {
            NewPathView(talk: state, talkInstead: { talking = true })
        }
    }
}

struct TalkPathView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let model: any PathModel
    let typeInstead: () -> Void

    @State private var history: [ChatMessage] = []
    @State private var responding = false
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
                            if responding {
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
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || responding)
            }
            Button("Type it instead", action: typeInstead)
                .font(.footnote)
        }
        .padding()
        .background(.bar)
    }

    private func send() {
        let said = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !said.isEmpty, !responding else { return }
        input = ""
        trouble = nil
        let prompt = draft == heard
            ? said
            : said + "\n\nThe person edited the path by hand. Build on this version:\n" + draft.spoken
        lines.append(Line(mine: true, text: said))
        history.append(ChatMessage(role: .user, text: prompt))
        responding = true
        Task {
            defer { responding = false }
            do {
                let turn = try await model.respond(history)
                if let echo = try? JSONEncoder().encode(turn) {
                    history.append(ChatMessage(role: .assistant, text: String(decoding: echo, as: UTF8.self)))
                }
                draft = turn.path.draft
                heard = draft
                lines.append(Line(mine: false, text: turn.question))
            } catch let e as TalkError {
                history.removeLast()
                trouble = e.sentence
            } catch {
                history.removeLast()
                trouble = TalkError.unreadable.sentence
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
                Text("Quests and routines").font(.caption).foregroundStyle(.secondary)
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
