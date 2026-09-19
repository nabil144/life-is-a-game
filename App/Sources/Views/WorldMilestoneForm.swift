import SwiftUI
import LifeEngine

/// Creating or opening an unreached milestone never marks it reached implicitly.
struct WorldMilestoneForm: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let pathID: UUID
    let milestone: Milestone?
    @State private var text: String

    init(pathID: UUID, milestone: Milestone?) {
        self.pathID = pathID
        self.milestone = milestone
        _text = State(initialValue: milestone?.text ?? "")
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            PixelList {
                Section("A sentence that will be true") {
                    TextField("Your milestone", text: $text, axis: .vertical)
                }
                if milestone != nil {
                    Section {
                        Button("This is true now") { save(reached: true) }
                            .disabled(trimmed.isEmpty)
                    } footer: {
                        Text("Record this milestone as reached today.")
                    }
                }
            }
            .navigationTitle(milestone == nil ? "New milestone" : "Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                PixelToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                PixelToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(reached: false) }.disabled(trimmed.isEmpty)
                }
            }
        }
    }

    private func save(reached: Bool) {
        guard !trimmed.isEmpty, var path = store.path(pathID) else { return }
        if let milestone {
            guard let index = path.milestones.firstIndex(where: { $0.id == milestone.id }) else { return }
            path.milestones[index].text = trimmed
        } else {
            path.milestones.append(Milestone(text: trimmed))
        }
        store.update(path)
        if reached, let milestone { store.tickMilestone(milestone.id, in: pathID) }
        dismiss()
    }
}
