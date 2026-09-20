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
    @State private var newMilestone = ""

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
                    PixelMenuPicker("Kind", selection: $role, options: Role.allCases.map { .init(title: $0.label, value: $0) })
                    if role == .decision {
                        PixelDatePicker("Decide by", selection: $deadline, in: Date()..., displayedComponents: .date)
                    }
                    PixelMenuPicker("Glyph", selection: $glyph, options: [.init(title: "Automatic", value: role.glyph, glyph: role.glyph)] + Role.glyphs.filter { $0 != role.glyph }.map { .init(title: $0.replacingOccurrences(of: ".", with: " "), value: $0, glyph: $0) })
                }
                Section {
                    ForEach($milestones) { $m in
                        TextField("A sentence that will be true, e.g. It holds tune", text: $m.text, axis: .vertical)
                    }
                    .onDelete { milestones.remove(atOffsets: $0) }
                    .onMove { milestones.move(fromOffsets: $0, toOffset: $1) }
                    HStack {
                        TextField("Add a milestone as a sentence", text: $newMilestone)
                        Button("Add") {
                            milestones.append(Milestone(text: newMilestone.trimmingCharacters(in: .whitespacesAndNewlines)))
                            newMilestone = ""
                        }
                        .disabled(newMilestone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Milestones")
                }
                Text("Tap a milestone on the path to tick it. Here you change the words, the order, or drop one.")
                    .font(.caption)
                    .foregroundStyle(Color.gray.opacity(0.85))
                    .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .navigationTitle("This path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                PixelToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
                PixelToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
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
