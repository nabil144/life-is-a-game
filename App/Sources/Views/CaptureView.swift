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
    @State private var cue = Cue.anytime
    @State private var after: UUID?
    @State private var outsideHome = false
    @State private var appLaunch: AppLaunch?

    var body: some View {
        NavigationStack {
            PixelList {
                Section {
                    TextField("What is it?", text: $title, axis: .vertical)
                        .font(.title3)
                }
                Section("On which path") {
                    PixelMenuPicker("Path", selection: $pathID, options: store.activePaths.map { .init(title: $0.name, value: Optional($0.id), glyph: $0.glyph) })
                }
                Section {
                    PixelChoices(title: "Kind", selection: $kind, options: [
                ("Quest", NodeKind.quest),
                ("Routine", NodeKind.practice)
            ])
                    Text(kind == .quest ? "Something you do once." : "Something you return to.")
                        .pixelHelper()
                }
                AppLaunchEditor(launch: $appLaunch)
                if kind == .quest {
                    Section {
                        Toggle("Outside home", isOn: $outsideHome)
                    }
                    Text("Highlight this quest when you turn on Going out today.").pixelHelper()
                }
                Section(kind == .practice ? "How often?" : "When could you do this?") {
                    CueEditor(cue: $cue, forPractice: kind == .practice)
                }
                if let pid = pathID, let path = store.path(pid) {
                    let open = path.nodes.filter { $0.isOpen && $0.kind == .quest }
                    if !open.isEmpty {
                        Section("Only after (optional)") {
                            PixelMenuPicker("Blocker", selection: $after, options: [.init(title: "Nothing", value: UUID?.none)] + open.map { .init(title: $0.title, value: Optional($0.id)) })
                        }
                    }
                }
            }
            .navigationTitle("Capture")
            .onChange(of: kind) { _, kind in
                if kind == .quest { cue.monthDay = nil }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                PixelToolbarItem(placement: .confirmationAction) {
                    Button("Add to path") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || pathID == nil || (appLaunch != nil && appLaunch?.url == nil))
                }
                PixelToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                title = request.prefill
                pathID = request.pathID ?? store.activePaths.first?.id
                kind = request.kind ?? .quest
            }
        }
    }

    func save() {
        guard let pid = pathID else { return }
        var node = Node(kind: kind, title: title.trimmingCharacters(in: .whitespacesAndNewlines), cue: cue, after: after, createdOn: store.today)
        node.appLaunch = appLaunch
        node.outsideHome = kind == .quest && outsideHome
        store.addNode(node, to: pid)
        dismiss()
    }
}
