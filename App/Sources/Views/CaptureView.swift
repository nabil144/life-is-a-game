import SwiftUI
import LifeEngine

/// One text field, three taps. The only authoring surface for nodes.
struct CaptureView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let request: CaptureRequest

    @State private var title = ""
    @State private var pathID: UUID?
    @State private var kind: NodeKind = .quest
    @State private var days: DaysCue = .any
    @State private var window: Window = .any
    @State private var pickDate = false
    @State private var date = Date()
    @State private var after: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What is it?", text: $title, axis: .vertical)
                        .font(.title3)
                }
                Section("On which path") {
                    Picker("Path", selection: $pathID) {
                        ForEach(store.activePaths) { p in
                            Label(p.name, systemImage: p.glyph).tag(Optional(p.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section {
                    Picker("Kind", selection: $kind) {
                        Text("Quest").tag(NodeKind.quest)
                        Text("Practice").tag(NodeKind.practice)
                    }
                    .pickerStyle(.segmented)
                    Text(kind == .quest ? "Something you do once." : "Something you return to.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("When could you do this?") {
                    Picker("Days", selection: $days) {
                        Text("Anytime").tag(DaysCue.any)
                        Text("Weekend").tag(DaysCue.weekend)
                        Text("Weekday").tag(DaysCue.weekday)
                    }
                    .pickerStyle(.segmented)
                    Picker("Time", selection: $window) {
                        Text("Any").tag(Window.any)
                        Text("Morning").tag(Window.morning)
                        Text("Evening").tag(Window.evening)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Pick a date instead", isOn: $pickDate)
                    if pickDate {
                        DatePicker("On", selection: $date, in: Date()..., displayedComponents: .date)
                    }
                }
                if let pid = pathID, let path = store.path(pid) {
                    let open = path.nodes.filter { $0.isOpen && $0.kind == .quest }
                    if !open.isEmpty {
                        Section("Only after (optional)") {
                            Picker("Blocker", selection: $after) {
                                Text("Nothing").tag(UUID?.none)
                                ForEach(open) { n in Text(n.title).tag(Optional(n.id)) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to path") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || pathID == nil)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                title = request.prefill
                pathID = request.pathID ?? store.activePaths.first?.id
            }
        }
    }

    func save() {
        guard let pid = pathID else { return }
        let cue = Cue(days: days, window: window, on: pickDate ? Day(date) : nil)
        let node = Node(kind: kind, title: title.trimmingCharacters(in: .whitespacesAndNewlines), cue: cue, after: after, createdOn: store.today)
        store.addNode(node, to: pid)
        dismiss()
    }
}
