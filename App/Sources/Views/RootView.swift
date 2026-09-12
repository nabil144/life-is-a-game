import SwiftUI
import LifeEngine

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Notifier.self) private var notifier
    @State private var captureFor: CaptureRequest?
    @AppStorage(Prefs.keyPromptSeenKey) private var keyPromptSeen = false
    @State private var keyPrompt = false
    @State private var mirrorPrompt = false

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
        .sheet(isPresented: $mirrorPrompt, onDismiss: offerKeyIfNeeded) { KeepCopySheet() }
        .onChange(of: store.world.onboarded, initial: true) { _, onboarded in
            guard onboarded else { return }
            offerMirrorIfNeeded()
            if !mirrorPrompt { offerKeyIfNeeded() }
        }
        .onAppear {
            notifier.openCapture = { (nodeID: UUID) in
                if let (path, node) = store.node(nodeID) {
                    captureFor = CaptureRequest(pathID: path.id, prefill: "Part of: \(node.title)")
                }
            }
        }
    }

    private func offerMirrorIfNeeded() {
        let seen = UserDefaults.standard.bool(forKey: Mirror.promptSeenKey)
        if !store.world.paths.isEmpty, !store.keepsACopy, !seen {
            mirrorPrompt = true
        }
    }

    private func offerKeyIfNeeded() {
        guard store.world.onboarded, !keyPromptSeen, Talk.state.reason != nil else { return }
        keyPrompt = true
    }
}

struct CaptureRequest: Identifiable, Hashable {
    var id = UUID()
    var pathID: UUID?
    var prefill: String = ""
}
