import SwiftUI
import LifeEngine

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Notifier.self) private var notifier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var captureFor: CaptureRequest?
    @AppStorage(Prefs.keyPromptSeenKey) private var keyPromptSeen = false
    @State private var keyPrompt = false
    @State private var mirrorPrompt = false
    @State private var selectedTab = 0
    @State private var worldVisit = UUID()

    var body: some View {
        Group {
            if store.world.onboarded {
                VStack(spacing: 0) {
                    TabView(selection: $selectedTab) {
                        TodayView(capture: $captureFor)
                            .toolbar(.hidden, for: .tabBar)
                            .tabItem { Label("Today", systemImage: "sun.max") }
                            .tag(0)
                        PathsView(capture: $captureFor, worldVisit: worldVisit)
                            .toolbar(.hidden, for: .tabBar)
                            .tabItem { Label("Paths", systemImage: "point.3.connected.trianglepath.dotted") }
                            .tag(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Reserve real layout space, including for pushed detail screens.
                    // A tab controller can otherwise lose an outer safe-area inset.
                    HStack(spacing: 6) {
                        tabButton("Today", glyph: "sun.max", tab: 0)
                        tabButton("Paths", glyph: "point.3.connected.trianglepath.dotted", tab: 1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background(Ink.ground)
                }
            } else {
                OnboardingView()
            }
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == 1 { worldVisit = UUID() }
        }
        .task(id: store.outsideReminderSignature) { await notifier.syncOutsideReminder() }
        .onChange(of: notifier.openTodayRequest) { _, _ in selectedTab = 0 }
        .tint(Ink.brass)
        .preferredColorScheme(.dark)
        .background(Ink.ground)
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

    private func tabButton(_ title: String, glyph: String, tab: Int) -> some View {
        Button { selectedTab = tab } label: {
            HStack(spacing: 8) {
                Image(systemName: glyph)
                    .font(.system(size: 23, weight: .semibold))
                    .scaleEffect(selectedTab == tab ? 1.15 : 1)
                    .rotationEffect(.degrees(reduceMotion ? 0 : (tab == 0
                        ? (selectedTab == tab ? 45 : 0)
                        : (selectedTab == tab ? 30 : -30))))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.38), value: selectedTab == tab)
                    .frame(width: 44, height: 36)
                    .accessibilityHidden(true)
                Text(title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PixelButtonStyle(selected: selectedTab == tab, compact: true, fillsWidth: true))
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
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
