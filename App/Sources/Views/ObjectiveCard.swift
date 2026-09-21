import SwiftUI
import PhotosUI
import LifeEngine

/// The one card that matters. Shared by every Today style.
struct ObjectiveCard: View {
    @Environment(Store.self) private var store
    let objective: Objective
    var compact = false
    @State private var showDone = false

    var body: some View {
        if let (path, node) = store.node(objective.nodeID) {
            VStack(alignment: .leading, spacing: 8) {
                Text(objective.kind == .staleCheck ? "Still want this?" : "New objective")
                    .font(.caption.weight(.bold)).textCase(.uppercase).tracking(1).foregroundStyle(.tint)
                if !compact {
                    Image(systemName: path.glyph).font(.system(size: 40)).padding(.top, 4)
                }
                Text(node.title).font(compact ? .title3.bold() : .title.bold())
                Text(meta(path: path, node: node)).font(.subheadline).foregroundStyle(.secondary)
                actions(node: node)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelCard()
            .sheet(isPresented: $showDone) { DoneSheet(node: node) }
        }
    }

    func meta(path: Path, node: Node) -> String {
        var parts = [path.identity, cueText(node.cue, kind: node.kind)]
        if let after = node.after, let b = path.node(after) { parts.append("after \"\(b.title)\"") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    func actions(node: Node) -> some View {
        HStack(spacing: 10) {
            if objective.kind == .staleCheck {
                Button("Keep it") { store.respond(.keep, nodeID: node.id) }.buttonStyle(PixelButtonStyle(selected: true))
                Button("Let it go", role: .destructive) { store.respond(.letGo, nodeID: node.id) }.buttonStyle(PixelButtonStyle())
            } else {
                Button("Done") { showDone = true }.buttonStyle(PixelButtonStyle(selected: true))
                Button("Not now") { store.respond(.notNow, nodeID: node.id) }.buttonStyle(PixelButtonStyle())
                Button("Too big") { store.respond(.tooBig, nodeID: node.id) }.buttonStyle(PixelButtonStyle())
            }
        }
        .controlSize(.large)
        .padding(.top, 8)
    }
}

func cueText(_ cue: Cue, kind: NodeKind = .quest) -> String {
    if let on = cue.on { return on.description }
    var s: String
    if kind == .practice {
        switch cue.practiceRhythm {
        case .everyday: s = "everyday"
        case .weekdays: s = "weekdays"
        case .weekends: s = "weekends"
        case .few: s = "every \(cue.every) days"
        case .weekly: s = "weekly"
        case .monthly: s = "monthly on day \(cue.monthDay ?? 1)"
        }
    } else {
        s = cue.days == .any ? "anytime" : cue.days.rawValue
    }
    if cue.window != .any { s += " " + cue.window.rawValue + "s" }
    return s
}

/// Done with an optional line and photo. The proof.
struct DoneSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let node: Node
    @State private var note = ""
    @State private var pick: PhotosPickerItem?
    @State private var photo: Data?

    var body: some View {
        NavigationStack {
            PixelList {
                Section {
                    Text(node.title).font(.headline)
                    TextField("One line about what happened (optional)", text: $note, axis: .vertical)
                }
                Section {
                    PhotosPicker(selection: $pick, matching: .images) {
                        Label(photo == nil ? "Add a photo" : "Photo attached", systemImage: "camera")
                    }
                }
            }
            .navigationTitle("Done")
            .toolbar {
                PixelToolbarItem(placement: .confirmationAction) {
                    Button("Log it") {
                        store.respond(.done, nodeID: node.id, note: note.isEmpty ? nil : note, photo: photo)
                        dismiss()
                    }
                }
                PixelToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onChange(of: pick) { _, item in
                Task { photo = try? await item?.loadTransferable(type: Data.self) }
            }
        }
        .presentationDetents([.medium])
    }
}
