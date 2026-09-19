import SwiftUI
import LifeEngine

/// Change the path's own words. Quests stay on the path; this is name, who, kind, glyph, deadline, milestones.
struct PathEditView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let pathID: UUID
    @State private var name: String
    @State private var identity: String
    @State private var role: Role
    @State private var glyph: String
    @State private var deadline: Date
    @State private var milestones: [Milestone]

    init(path: Path) {
        pathID = path.id
        _name = State(initialValue: path.name)
        _identity = State(initialValue: path.identity)
        _role = State(initialValue: path.role)
        _glyph = State(initialValue: path.glyph)
        let pinned = path.deadline.flatMap { Calendar.current.date(from: DateComponents(year: $0.year, month: $0.month, day: $0.day)) }
        _deadline = State(initialValue: pinned ?? Date().addingTimeInterval(60 * 60 * 24 * 60))
        _milestones = State(initialValue: path.milestones)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && milestones.contains { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        NavigationStack {
            PixelList {
                Section {
                    TextField("What are you evolving?", text: $name)
                    TextField("Who are you on this path? e.g. Guitarist", text: $identity)
                    PixelMenuPicker("Kind", selection: $role, boxed: true) {
                        ForEach(Role.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    if role == .decision {
                        DatePicker("Decide by", selection: $deadline, in: Date()..., displayedComponents: .date)
                    }
                    PixelMenuPicker("Glyph", selection: $glyph, boxed: true) {
                        Label("Automatic", systemImage: role.glyph).tag(role.glyph)
                        ForEach(Role.glyphs, id: \.self) { Image(systemName: $0).tag($0) }
                    }
                }
                Section {
                    ForEach($milestones) { $m in
                        TextField("A sentence that will be true, e.g. It holds tune", text: $m.text, axis: .vertical)
                    }
                    .onDelete { milestones.remove(atOffsets: $0) }
                    .onMove { milestones.move(fromOffsets: $0, toOffset: $1) }
                    Button("Add another milestone") { milestones.append(Milestone(text: "")) }
                } header: {
                    Text("Milestones")
                } footer: {
                    Text("Tap a milestone on the path to tick it. Here you change the words, the order, or drop one.")
                }
            }
            .navigationTitle("This path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func save() {
        guard var path = store.path(pathID) else { return }
        path.name = name.trimmingCharacters(in: .whitespaces)
        let who = identity.trimmingCharacters(in: .whitespaces)
        path.identity = who.isEmpty ? path.name : who
        path.role = role
        path.glyph = glyph.isEmpty ? role.glyph : glyph
        path.deadline = role == .decision ? Day(deadline) : nil
        path.milestones = milestones.map { m in
            var m = m
            m.text = m.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return m
        }.filter { !$0.text.isEmpty }
        store.update(path)
        dismiss()
    }
}
