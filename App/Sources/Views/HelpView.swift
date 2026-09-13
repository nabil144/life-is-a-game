import SwiftUI

/// The cheat sheet. Opened from Settings and from New path, so the owner does not have to ask again.
struct HelpView: View {
    var body: some View {
        List {
            Section {
                Text("A milestone is something you achieve on the path. You tick it when you have reached it. A quest is a small step that might get you there, and may show up tonight.")
                    .font(.subheadline)
                    .foregroundStyle(Ink.muted)
            }
            row("Path", "The thing you are evolving. Guitar, a lab, a decision. You write it.")
            row("Milestone", "A fact you want to be able to say is true. “I can play solo X.” Tick it the day that is true. The app never throws this at you as tonight’s job.")
            row("Quest", "One sitting. A step toward a milestone. “Learn the first eight bars of solo X.” Today may put it in front of you.")
            row("Practice", "You return to it. It is never done. “20 minutes on solo X.”")
            row("Cue", "When a quest or practice may surface. Weekend, evening, a date. Not an alarm.")
            row("Today", "The quests and practices that fit this day. The date ticks with the phone’s clock. Quests and practices grow out of each path, like World. When groups by morning and evening. Tap one to mark it done. A quest leaves. A practice comes back when its cue allows. Paths live on the other tab.")
            row("Evolved", "Every milestone on the path is ticked. The path goes quiet and stays visible.")
            row("The fact", "A ticked milestone. Tap it to change the day, or to take the tick back. One tap will not undo it.")
            Section {
                Text("If it is the destination, it is a milestone. If it is tonight’s move, it is a quest. If you will do it again next week, it is a practice. If you cannot see a quest yet, skip it. Add one from the path later.")
                    .font(.subheadline)
                    .foregroundStyle(Ink.muted)
            }
        }
        .navigationTitle("The words")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(Ink.muted)
        }
        .padding(.vertical, 4)
    }
}
