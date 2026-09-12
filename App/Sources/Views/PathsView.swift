import SwiftUI
import LifeEngine

struct PathsView: View {
    @Environment(Store.self) private var store
    @Binding var capture: CaptureRequest?
    @AppStorage(Prefs.pathsStyleKey) private var style: PathsStyle = .atlas
    @State private var newPath = false
    @State private var settings = false

    var body: some View {
        NavigationStack {
            Group {
                if style == .list {
                    list
                } else {
                    AtlasView()
                }
            }
            .navigationTitle("Paths")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                PathDetailView(pathID: id, capture: $capture)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $style) {
                        ForEach(PathsStyle.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { newPath = true } label: { Label("New path", systemImage: "plus") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { settings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $newPath) { NewPathSheet() }
            .sheet(isPresented: $settings) { SettingsView() }
        }
    }

    private var list: some View {
        List {
            if store.activePaths.isEmpty {
                ContentUnavailableView {
                    Label("Name one thing you want to evolve.", systemImage: "leaf")
                } description: {
                    Text("Or restore a copy from Files.")
                } actions: {
                    RestoreFileButton()
                }
            }
            ForEach(store.activePaths) { p in
                NavigationLink(value: p.id) { PathRow(path: p) }
            }
            let archived = store.paths.filter { $0.status == .archived }
            if !archived.isEmpty {
                Section("Put away") {
                    ForEach(archived) { p in
                        NavigationLink(value: p.id) { PathRow(path: p) }
                    }
                }
            }
        }
    }
}
