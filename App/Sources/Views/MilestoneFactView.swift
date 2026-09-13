import SwiftUI
import LifeEngine

/// A ticked milestone is a fact. Opening this is how you change the day or take the tick back.
struct MilestoneFactView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let pathID: UUID
    let milestoneID: UUID
    @State private var day: Date
    @State private var confirmTakeBack = false

    init(pathID: UUID, milestone: Milestone) {
        self.pathID = pathID
        self.milestoneID = milestone.id
        let pinned = milestone.tickedOn.flatMap {
            Calendar.current.date(from: DateComponents(year: $0.year, month: $0.month, day: $0.day))
        }
        _day = State(initialValue: pinned ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("It became true on", selection: $day, in: ...Date(), displayedComponents: .date)
                } footer: {
                    Text("A tap on the path should not take this back. Change the day if the app was not here yet.")
                }
                Section {
                    Button("It was not true yet", role: .destructive) { confirmTakeBack = true }
                }
            }
            .navigationTitle("The fact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Keep it") { save() }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .confirmationDialog("Take the tick back?", isPresented: $confirmTakeBack, titleVisibility: .visible) {
                Button("Take the tick back", role: .destructive) {
                    store.setMilestone(milestoneID, in: pathID, tickedOn: nil)
                    dismiss()
                }
            } message: {
                Text("The path will no longer show this as true.")
            }
        }
    }

    private func save() {
        store.setMilestone(milestoneID, in: pathID, tickedOn: Day(day))
        dismiss()
    }
}
