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
    static let outsideID = "outside-errands"
    var openTodayRequest = UUID()
    var outsideReminderError: String?
    private var outsideSyncVersion = 0

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

    /// One editable outing summary, separate from the usual daily objective.
    func syncOutsideReminder() async {
        outsideSyncVersion += 1
        let version = outsideSyncVersion
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.outsideID])
        center.removeDeliveredNotifications(withIdentifiers: [Self.outsideID])
        outsideReminderError = nil
        guard store.goingOutToday,
              let date = store.world.outsideReminderAt, date > Date(),
              Day(date) == store.today else { return }
        let items = store.outsideQuestsToday().compactMap { store.node($0.nodeID)?.1.title }
        guard !items.isEmpty else { return }
        let allowed = await authorized()
        guard version == outsideSyncVersion, !Task.isCancelled else { return }
        guard allowed else {
            outsideReminderError = "Notifications are off. Enable them in iPhone Settings to receive this reminder."
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "While you’re out · \(items.count) quest\(items.count == 1 ? "" : "s")"
        content.body = items.prefix(5).joined(separator: " • ")
            + (items.count > 5 ? " • Open Today for the full list." : "")
        content.sound = .default
        content.threadIdentifier = Self.outsideID
        content.userInfo = ["outside": true]
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let request = UNNotificationRequest(identifier: Self.outsideID, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        do { try await center.add(request) }
        catch { outsideReminderError = "Could not schedule the reminder. Please try again." }
    }

    // MARK: Delegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if response.notification.request.identifier == Self.outsideID {
            await MainActor.run { openTodayRequest = UUID() }
            return
        }
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
