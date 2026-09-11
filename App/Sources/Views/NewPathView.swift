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

struct NewPathView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft = PathDraft(name: "", identity: "", glyph: "star", role: .hobby, deadline: nil, milestones: [""], nodes: [])
    @State private var deadline = Date().addingTimeInterval(60 * 60 * 24 * 60)
    @State private var chosen: String?
    let templates = Templates.all()
    let glyphs = ["star", "guitars", "wand.and.stars", "laptopcomputer", "car", "book", "figure.run", "paintpalette", "camera", "hammer", "leaf", "music.note", "cpu", "wrench.and.screwdriver", "signpost.right.and.left", "sparkles"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Start from an example") {
                    ForEach(templates, id: \.id) { t in
                        Button {
                            chosen = t.id
                            draft = t.path
                            if t.path.milestones.isEmpty { draft.milestones = [""] }
                        } label: {
                            HStack {
                                Label(t.title, systemImage: t.path.glyph).foregroundStyle(.primary)
                                Spacer()
                                if chosen == t.id { Image(systemName: "checkmark").foregroundStyle(.tint) }
                            }
                        }
                    }
                    Text("Examples are yours to edit or delete.").font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    TextField("What are you evolving?", text: $draft.name)
                    TextField("Who are you on this path? e.g. Guitarist", text: $draft.identity)
                    Picker("What kind of path is this?", selection: $draft.role) {
                        Text("A hobby").tag(Role.hobby)
                        Text("A craft").tag(Role.craft)
                        Text("A decision").tag(Role.decision)
                        Text("A lab").tag(Role.lab)
                        Text("Work").tag(Role.work)
                    }
                    if draft.role == .decision {
                        DatePicker("Decide by", selection: $deadline, in: Date()..., displayedComponents: .date)
                    }
                    Picker("Glyph", selection: $draft.glyph) {
                        ForEach(glyphs, id: \.self) { Image(systemName: $0).tag($0) }
                    }
                    .pickerStyle(.navigationLink)
                }
                Section("Milestones, as sentences that will be true") {
                    ForEach(draft.milestones.indices, id: \.self) { i in
                        TextField("e.g. It holds tune", text: $draft.milestones[i])
                    }
                    .onDelete { draft.milestones.remove(atOffsets: $0) }
                    Button("Add another") { draft.milestones.append("") }
                }
                Section("First quests") {
                    ForEach(draft.nodes.indices, id: \.self) { i in
                        HStack {
                            Image(systemName: draft.nodes[i].kind == .quest ? "diamond" : "arrow.trianglehead.2.clockwise").foregroundStyle(.secondary)
                            TextField("Something small", text: $draft.nodes[i].title)
                        }
                    }
                    .onDelete { draft.nodes.remove(atOffsets: $0) }
                    Button("Add a quest") { draft.nodes.append(.init(kind: .quest, title: "")) }
                    Button("Add a practice") { draft.nodes.append(.init(kind: .practice, title: "", cue: Cue(window: .evening))) }
                    Text("You can set when each can happen from the path later.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Begin") { save() }.disabled(!valid)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    var valid: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            && draft.milestones.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    func save() {
        var d = draft
        d.identity = d.identity.isEmpty ? d.name : d.identity
        d.deadline = d.role == .decision ? Day(deadline) : nil
        d.milestones = d.milestones.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        d.nodes = d.nodes.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        d.nodes = d.nodes.map { n in
            var n = n
            if let a = n.after, !d.nodes.contains(where: { $0.title == a }) { n.after = nil }
            return n
        }
        guard let path = try? d.instantiate(on: store.today) else { return }
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
            Text("One notification a day at most. Never the same one twice in a week.")
                .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 24)
        }
        .sheet(isPresented: $begin) { NewPathView().interactiveDismissDisabled() }
    }
}
