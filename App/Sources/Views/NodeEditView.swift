import SwiftUI
import LifeEngine

/// Days, time of day, or one exact date. Shared by Capture and the node editor.
/// Monthly routines store a calendar day rather than an elapsed-day interval.
struct CueEditor: View {
    @Binding var cue: Cue
    var forPractice: Bool
    @State private var pickDate: Bool
    @State private var date: Date

    init(cue: Binding<Cue>, forPractice: Bool = false) {
        _cue = cue
        self.forPractice = forPractice
        _pickDate = State(initialValue: cue.wrappedValue.on != nil)
        let pinned = cue.wrappedValue.on.flatMap { Calendar.current.date(from: DateComponents(year: $0.year, month: $0.month, day: $0.day)) }
        _date = State(initialValue: pinned ?? Date())
    }

    var body: some View {
        if forPractice {
            PixelChoices(title: "How often", selection: rhythm, options: [
                ("Everyday", PracticeRhythm.everyday),
                ("Weekdays", PracticeRhythm.weekdays),
                ("Weekends", PracticeRhythm.weekends)
            ])
            PixelChoices(title: "How often", selection: rhythm, options: [
                ("Every 3 days", PracticeRhythm.few),
                ("Weekly", PracticeRhythm.weekly),
                ("Monthly", PracticeRhythm.monthly)
            ])
            if cue.practiceRhythm == .monthly {
                PixelMenuPicker("Day of month", selection: Binding(
                    get: { cue.monthDay ?? 1 },
                    set: { cue.monthDay = $0 }
                ), options: (1...31).map { .init(title: "Day \($0)", value: $0) })
                Text("Repeats on this day each month. Shorter months use their last day.")
                    .pixelHelper()
            }
        } else {
            Toggle("Pick a date instead", isOn: $pickDate)
                .onChange(of: pickDate) { _, on in cue.on = on ? Day(date) : nil }
            if pickDate {
                PixelDatePicker("On", selection: $date, in: Date()..., displayedComponents: .date)
                    .onChange(of: date) { _, d in cue.on = Day(d) }
            } else {
                PixelChoices(title: "Days", selection: $cue.days, options: [
                    ("Anytime", DaysCue.any),
                    ("Weekend", DaysCue.weekend),
                    ("Weekday", DaysCue.weekday)
                ])
            }
        }
        if forPractice || !pickDate {
            PixelChoices(title: "Time", selection: $cue.window, options: [
                ("Any", Window.any),
                ("Morning", Window.morning),
                ("Evening", Window.evening)
            ])
        }
    }

    private var rhythm: Binding<PracticeRhythm> {
        Binding(
            get: { cue.practiceRhythm },
            set: { cue.practiceRhythm = $0 }
        )
    }
}

/// Tap a quest or practice on its path to change its words, its cue, or its blocker.
struct NodeEditView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let pathID: UUID
    @State var node: Node
    @State private var confirmLetGo = false

    var body: some View {
        NavigationStack {
            PixelList {
                Section {
                    TextField("What is it?", text: $node.title, axis: .vertical).font(.title3)
                }
                Section {
                    PixelChoices(title: "Kind", selection: $node.kind, options: [
                ("Quest", NodeKind.quest),
                ("Routine", NodeKind.practice)
            ])
                    Text(node.kind == .quest ? "Something you do once." : "Something you return to.")
                        .pixelHelper()
                }
                AppLaunchEditor(launch: $node.appLaunch)
                if node.kind == .quest {
                    Section {
                        Toggle("Outside home", isOn: Binding(
                            get: { node.outsideHome == true },
                            set: { node.outsideHome = $0 }
                        ))
                    }
                    Text("Highlight this quest when you turn on Going out today.").pixelHelper()
                }
                Section(node.kind == .practice ? "How often?" : "When could you do this?") {
                    CueEditor(cue: $node.cue, forPractice: node.kind == .practice)
                }
                if let path = store.path(pathID) {
                    let others = path.nodes.filter { $0.isOpen && $0.kind == .quest && $0.id != node.id }
                    if !others.isEmpty {
                        Section("Only after (optional)") {
                            PixelMenuPicker("Blocker", selection: $node.after, options: [.init(title: "Nothing", value: UUID?.none)] + others.map { .init(title: $0.title, value: Optional($0.id)) })
                        }
                    }
                }
                Section {
                    if node.kind == .quest && node.isDone {
                        Button("Mark as not done") {
                            store.respond(.reopen, nodeID: node.id)
                            dismiss()
                        }
                    }
                    Button("Let it go", role: .destructive) { confirmLetGo = true }
                }
            }
            .navigationTitle(node.kind == .quest ? "Quest" : "Routine")
            .onChange(of: node.kind) { _, kind in
                if kind == .quest { node.cue.monthDay = nil }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                PixelToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(node.title.trimmingCharacters(in: .whitespaces).isEmpty || (node.appLaunch != nil && node.appLaunch?.url == nil))
                }
                PixelToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .confirmationDialog("Remove \(node.title)?", isPresented: $confirmLetGo, titleVisibility: .visible) {
                Button("Let it go", role: .destructive) {
                    store.respond(.letGo, nodeID: node.id)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        var n = node
        n.title = n.title.trimmingCharacters(in: .whitespacesAndNewlines)
        store.updateNode(n, in: pathID)
        dismiss()
    }
}
