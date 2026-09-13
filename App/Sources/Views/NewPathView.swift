import SwiftUI
import LifeEngine

/// Loads the bundled `templates/*.json`. They are examples the user edits, never a curriculum.
enum Templates {
    static func all() -> [Template] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "templates") else { return [] }
        return urls.compactMap { url in
            (try? Data(contentsOf: url)).flatMap { try? JSONFiles.decoder().decode(Template.self, from: $0) }
        }.sorted { $0.id < $1.id }
    }
}

extension PathDraft {
    static let blank = PathDraft(name: "", identity: "", glyph: "", role: .hobby, deadline: nil, milestones: [], nodes: [])

    var isBeginnable: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && milestones.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Fills what the form and the chat leave open, drops blank lines, then resolves blockers.
    func begun(on day: Day) throws -> Path {
        var d = self
        d.name = d.name.trimmingCharacters(in: .whitespaces)
        d.identity = d.identity.trimmingCharacters(in: .whitespaces)
        if d.identity.isEmpty { d.identity = d.name }
        if d.glyph.isEmpty { d.glyph = d.role.glyph }
        d.milestones = d.milestones.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        d.nodes = d.nodes.compactMap { n in
            var n = n
            n.title = n.title.trimmingCharacters(in: .whitespaces)
            return n.title.isEmpty ? nil : n
        }
        let titles = Set(d.nodes.map(\.title))
        d.nodes = d.nodes.map { n in
            var n = n
            if let a = n.after, !titles.contains(a) { n.after = nil }
            return n
        }
        return try d.instantiate(on: day)
    }
}

extension Role {
    var label: String {
        switch self {
        case .hobby: "A hobby"
        case .craft: "A craft"
        case .decision: "A decision"
        case .lab: "A lab"
        case .work: "Work"
        }
    }

    var glyph: String {
        switch self {
        case .hobby: "star"
        case .craft: "hammer"
        case .decision: "signpost.right.and.left"
        case .lab: "cpu"
        case .work: "laptopcomputer"
        }
    }

    static let glyphs = ["star", "guitars", "wand.and.stars", "laptopcomputer", "car", "book", "figure.run", "paintpalette", "camera", "hammer", "leaf", "music.note", "cpu", "wrench.and.screwdriver", "signpost.right.and.left", "sparkles"]
}

struct NewPathView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var talk: Talk.State?
    var talkInstead: () -> Void = {}

    @State private var draft: PathDraft = { var d = PathDraft.blank; d.milestones = [""]; return d }()
    @State private var deadline = Date().addingTimeInterval(60 * 60 * 24 * 60)
    @State private var more = false
    let templates = Templates.all()

    var body: some View {
        NavigationStack {
            Form {
                switch talk {
                case .ready:
                    Section {
                        Button(action: talkInstead) {
                            Label("Talk it through instead", systemImage: "bubble.left.and.text.bubble.right")
                        }
                    } footer: {
                        Text("Your own key, your own model. It asks, you answer, it writes down your words.")
                    }
                case .off(let reason):
                    Section {
                        NavigationLink {
                            KeySetupView()
                        } label: {
                            Label(reason, systemImage: "key").foregroundStyle(.secondary)
                        }
                    }
                case nil:
                    EmptyView()
                }
                Section {
                    TextField("What are you evolving?", text: $draft.name)
                    ForEach(draft.milestones.indices, id: \.self) { i in
                        TextField("A sentence that will be true, e.g. It holds tune", text: $draft.milestones[i])
                    }
                    .onDelete { draft.milestones.remove(atOffsets: $0) }
                    Button("Add another milestone") { draft.milestones.append("") }
                } header: {
                    Text("Name it, then one milestone")
                }
                Section {
                    Menu {
                        ForEach(templates, id: \.id) { t in
                            Button(t.title, systemImage: t.path.glyph) {
                                draft = t.path
                                if draft.milestones.isEmpty { draft.milestones = [""] }
                                more = true
                            }
                        }
                    } label: {
                        Label("Start from an example", systemImage: "doc.text")
                    }
                } footer: {
                    Text("Examples are yours to edit or delete.")
                }
                Section {
                    DisclosureGroup("More", isExpanded: $more) {
                        TextField("Who are you on this path? e.g. Guitarist", text: $draft.identity)
                        Picker("What kind of path is this?", selection: $draft.role) {
                            ForEach(Role.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        if draft.role == .decision {
                            DatePicker("Decide by", selection: $deadline, in: Date()..., displayedComponents: .date)
                        }
                        Picker("Glyph", selection: $draft.glyph) {
                            Label("Follows the kind", systemImage: draft.role.glyph).tag("")
                            ForEach(Role.glyphs, id: \.self) { Image(systemName: $0).tag($0) }
                        }
                        .pickerStyle(.navigationLink)
                        ForEach(draft.nodes.indices, id: \.self) { i in
                            HStack {
                                Image(systemName: draft.nodes[i].kind == .quest ? "diamond" : "arrow.trianglehead.2.clockwise").foregroundStyle(.secondary)
                                TextField("Something small", text: $draft.nodes[i].title)
                            }
                        }
                        .onDelete { draft.nodes.remove(atOffsets: $0) }
                        Button("Add a quest") { draft.nodes.append(.init(kind: .quest, title: "")) }
                        Button("Add a practice") { draft.nodes.append(.init(kind: .practice, title: "", cue: Cue(window: .evening))) }
                    }
                } footer: {
                    Text("All of this is optional. Quests can be added from the path any time.")
                }
            }
            .navigationTitle("New path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Begin") { save() }.disabled(!draft.isBeginnable)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    func save() {
        var d = draft
        d.deadline = d.role == .decision ? Day(deadline) : nil
        guard let path = try? d.begun(on: store.today) else { return }
        store.add(path)
        dismiss()
    }
}

/// First launch. A short why, then straight into New path.
struct OnboardingView: View {
    @Environment(Notifier.self) private var notifier
    @State private var begin = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "leaf").font(.system(size: 64)).foregroundStyle(.tint)
            Text("Life is a game.").font(.largeTitle.bold())
            Text("Not with points. With paths you write yourself, and one objective a day that finds you when the moment is right.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal, 24)
            Spacer()
            Button {
                Task { _ = await notifier.requestPermission(); begin = true }
            } label: {
                Text("Begin").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).padding(.horizontal, 24)
            RestoreFileButton(title: "I already have a copy")
                .padding(.horizontal, 24)
            Text("One notification a day at most. Never the same one twice in a week.")
                .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 24)
        }
        .foregroundStyle(Ink.words)
        .background(Ink.ground)
        .sheet(isPresented: $begin) { NewPathView().interactiveDismissDisabled() }
    }
}
