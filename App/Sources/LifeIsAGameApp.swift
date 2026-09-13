import SwiftUI
import BackgroundTasks
import LifeEngine

enum Prefs {
    static let morningKey = "morningHour"
    static let eveningKey = "eveningHour"
    static let todayStyleKey = "todayStyle"
    static let todaySortKey = "todaySort"
    static let pathsStyleKey = "pathsStyle"
    static let talkKey = "talkPaths"
    static let providerKey = "talkProvider"
    static let modelKey = "talkModel"
    static let keyPromptSeenKey = "keyPromptSeen"

    static var morningHour: Int { UserDefaults.standard.object(forKey: morningKey) as? Int ?? 10 }
    static var eveningHour: Int { UserDefaults.standard.object(forKey: eveningKey) as? Int ?? 19 }
    static var provider: Provider { UserDefaults.standard.string(forKey: providerKey).flatMap(Provider.init(rawValue:)) ?? .openAI }
    static var model: String {
        let m = UserDefaults.standard.string(forKey: modelKey) ?? ""
        return m.isEmpty ? provider.defaultModel : m
    }
}

@main
struct LifeIsAGameApp: App {
    static let refreshTaskID = "com.nabil.LifeIsAGame.refresh"

    @State private var store: Store
    @State private var notifier: Notifier
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = Store()
        let notifier = Notifier(store: store)
        _store = State(initialValue: store)
        _notifier = State(initialValue: notifier)
        Ink.install()
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskID, using: nil) { task in
            Task { @MainActor in
                await Self.replan(store: store, notifier: notifier)
                task.setTaskCompleted(success: true)
                Self.scheduleRefresh()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(notifier)
                .task { await Self.replan(store: store, notifier: notifier) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await Self.replan(store: store, notifier: notifier) } }
                    if phase == .background { Self.scheduleRefresh() }
                }
        }
    }

    @MainActor
    static func replan(store: Store, notifier: Notifier) async {
        let objectives = store.refreshPlan()
        await notifier.schedule(objectives, morningHour: Prefs.morningHour, eveningHour: Prefs.eveningHour)
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 6, to: Date())
        try? BGTaskScheduler.shared.submit(request)
    }
}
