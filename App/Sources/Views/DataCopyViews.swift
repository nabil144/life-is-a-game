import SwiftUI
import UniformTypeIdentifiers

/// Pick a Files folder. After that, every save writes world.json there.
struct KeepCopyButton: View {
    @Environment(Store.self) private var store
    var title: String = "Keep a copy in Files"
    var onPicked: () -> Void = {}
    @State private var pick = false
    @State private var failed = false

    var body: some View {
        Button(title) { pick = true }
            .fileImporter(isPresented: $pick, allowedContentTypes: [.folder]) { result in
                do {
                    let url = try result.get()
                    try store.keepACopy(in: url)
                    UserDefaults.standard.set(true, forKey: Mirror.promptSeenKey)
                    onPicked()
                } catch {
                    failed = true
                }
            }
            .alert("Could not keep a copy there", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            }
    }
}

/// Read a world.json or a paths bundle the owner exported.
struct RestoreFileButton: View {
    @Environment(Store.self) private var store
    var title: String = "Restore from a file"
    var onRestored: () -> Void = {}
    @State private var pick = false
    @State private var failed = false

    var body: some View {
        Button(title) { pick = true }
            .fileImporter(isPresented: $pick, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let ok = url.startAccessingSecurityScopedResource()
                    defer { if ok { url.stopAccessingSecurityScopedResource() } }
                    try store.importData(Data(contentsOf: url))
                    onRestored()
                } catch {
                    failed = true
                }
            }
            .alert("Could not read that file", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            }
    }
}

/// Once, after the owner has paths and has not picked a folder.
struct KeepCopySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("The phone forgets this app when it is deleted or installed under a new name. A folder in Files does not.")
                    .foregroundStyle(.secondary)
                Text("Pick one. iCloud Drive is safest. Every change writes there. After a new install, pick the same folder and the paths come back.")
                    .foregroundStyle(.secondary)
                KeepCopyButton(title: "Pick a folder") { dismiss() }
                    .buttonStyle(PixelButtonStyle(selected: true))
                    .controlSize(.large)
                Spacer()
            }
            .padding()
            .navigationTitle("Keep a copy")
            .toolbar {
                PixelToolbarItem(placement: .cancellationAction) {
                    Button("Later") {
                        UserDefaults.standard.set(true, forKey: Mirror.promptSeenKey)
                        dismiss()
                    }
                }
            }
        }
    }
}
