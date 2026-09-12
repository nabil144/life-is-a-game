import SwiftUI
import LifeEngine

struct PathsView: View {
    @Environment(Store.self) private var store
    @Binding var capture: CaptureRequest?
    @State private var newPath = false
    @State private var settings = false

    var body: some View {
        NavigationStack {
            List {
                if store.activePaths.isEmpty {
                    ContentUnavailableView("Name one thing you want to evolve.", systemImage: "leaf")
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
            .navigationTitle("Paths")
            .navigationDestination(for: UUID.self) { id in
                PathDetailView(pathID: id, capture: $capture)
            }
            .toolbar {
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
}
