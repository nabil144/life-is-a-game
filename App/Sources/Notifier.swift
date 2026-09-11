import Foundation
import Observation
import UserNotifications
import LifeEngine

/// Owns the UNUserNotificationCenter side. Schedules one notification per planned day and turns action taps into store responses.
@Observable
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let category = "objective"
    static let staleCategory = "staleCheck"
    static let prefix = "objective-"

    enum ActionID: String {
        case done, later, tooBig, keep, letGo
    }

    @ObservationIgnored let store: Store
    /// Set by the root view so a "Too big" tap can open Capture prefilled.
    @ObservationIgnored var openCapture: ((UUID) -> Void)?

    init(store: Store) {
        self.store = store
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
    }

    private func registerCategories() {
        let done = UNNotificationAction(identifier: ActionID.done.rawValue, title: "Done", options: [])
        let later = UNNotificationAction(identifier: ActionID.later.rawValue, title: "Not now", options: [])
        let tooBig = UNNotificationAction(identifier: ActionID.tooBig.rawValue, title: "Too big", options: [.foreground])
        let keep = UNNotificationAction(identifier: ActionID.keep.rawValue, title: "Keep it", options: [])
        let letGo = UNNotificationAction(identifier: ActionID.letGo.rawValue, title: "Let it go", options: [.destructive])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: [done, later, tooBig], intentIdentifiers: []),
            UNNotificationCategory(identifier: Self.staleCategory, actions: [keep, letGo], intentIdentifiers: []),
        ])
    }

    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorized() async -> Bool {
        let s = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return s == .authorized || s == .provisional
    }

    /// Replace every pending objective with the given plan. Safe to call as often as you like.
    func schedule(_ objectives: [Objective], morningHour: Int, eveningHour: Int) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        for o in objectives {
            guard let (path, node) = store.node(o.nodeID) else { continue }
            let content = UNMutableNotificationContent()
            content.title = path.identity
            content.body = o.kind == .staleCheck ? "Still want this? \(node.title)" : "New objective: \(node.title)"
            content.sound = .default
            content.categoryIdentifier = o.kind == .staleCheck ? Self.staleCategory : Self.category
            content.threadIdentifier = path.id.uuidString
            content.userInfo = ["nodeID": o.nodeID.uuidString, "pathID": o.pathID.uuidString]

            var comps = DateComponents()
            comps.year = o.day.year
            comps.month = o.day.month
            comps.day = o.day.day
            comps.hour = o.window == .evening ? eveningHour : morningHour
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: Self.prefix + o.day.description, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    // MARK: Delegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let raw = response.notification.request.content.userInfo["nodeID"] as? String,
              let nodeID = UUID(uuidString: raw) else { return }
        let actionID = response.actionIdentifier
        await MainActor.run {
            switch ActionID(rawValue: actionID) {
            case .done: store.respond(.done, nodeID: nodeID)
            case .later: store.respond(.notNow, nodeID: nodeID)
            case .keep: store.respond(.keep, nodeID: nodeID)
            case .letGo: store.respond(.letGo, nodeID: nodeID)
            case .tooBig: openCapture?(nodeID)
            case .none: break
            }
        }
    }
}
