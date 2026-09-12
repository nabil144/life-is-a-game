import SwiftUI
import LifeEngine

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Notifier.self) private var notifier
    @State private var captureFor: CaptureRequest?
    @AppStorage(Prefs.keyPromptSeenKey) private var keyPromptSeen = false
    @State private var keyPrompt = false

    var body: some View {
        Group {
            if store.world.onboarded {
                TabView {
                    TodayView(capture: $captureFor)
                        .tabItem { Label("Today", systemImage: "sun.max") }
                    PathsView(capture: $captureFor)
                        .tabItem { Label("Paths", systemImage: "point.3.connected.trianglepath.dotted") }
                }
            } else {
                OnboardingView()
            }
        }
        .sheet(item: $captureFor) { req in
            CaptureView(request: req)
        }
        .sheet(isPresented: $keyPrompt, onDismiss: { keyPromptSeen = true }) {
            NavigationStack { KeySetupView(prompt: true) }
        }
        .onChange(of: store.world.onboarded, initial: true) { _, onboarded in
            guard onboarded, !keyPromptSeen, Talk.state.reason != nil else { return }
            Task {
                try? await Task.sleep(for: .seconds(0.8))
                keyPrompt = true
            }
        }
        .onAppear {
            notifier.openCapture = { (nodeID: UUID) in
                if let (path, node) = store.node(nodeID) {
                    captureFor = CaptureRequest(pathID: path.id, prefill: "Part of: \(node.title)")
                }
            }
        }
    }
}

struct CaptureRequest: Identifiable, Hashable {
    var id = UUID()
    var pathID: UUID?
    var prefill: String = ""
}
