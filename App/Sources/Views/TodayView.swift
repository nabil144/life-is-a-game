import SwiftUI
import LifeEngine

enum TodayStyle: String, CaseIterable, Identifiable {
    case oneCard, objectiveAndPaths, pathsFirst
    var id: String { rawValue }
    var label: String {
        switch self {
        case .oneCard: "A. One card"
        case .objectiveAndPaths: "B. Objective and paths"
        case .pathsFirst: "C. Paths first"
        }
    }
}

enum TodaySort: String, CaseIterable, Identifiable {
    case quests, practices, when
    var id: String { rawValue }
    var label: String {
        switch self {
        case .quests: "Quests"
        case .practices: "Routine"
        case .when: "When"
        }
    }
}

struct TodayView: View {
    @Environment(Store.self) private var store
    @Environment(Notifier.self) private var notifier
    @Binding var capture: CaptureRequest?
    @AppStorage(Prefs.todaySortKey) private var sort: TodaySort = .quests
    @State private var authorized = true
    @State private var pendingID: UUID?
    @State private var openPath: OpenPath?
    @State private var showOuting = false
    @State private var reminderTime = Date().addingTimeInterval(15 * 60)
    @State private var reminderDenied = false

    private var due: [Objective] { store.dueToday() }
    private var showKind: Bool { sort == .when }
    private var dateSlot: CGFloat { 68 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pin
                if due.isEmpty {
                    quiet
                    Spacer()
                } else {
                    dueList
                }
            }
            .background(Ink.ground)
            .toolbar(openPath == nil ? .hidden : .automatic, for: .navigationBar)
            .navigationDestination(item: $openPath) { dest in
                PathDetailView(pathID: dest.id, capture: $capture)
            }
            .sheet(isPresented: $showOuting) { outingSettings }
            .task {
                authorized = await notifier.authorized()
                while !Task.isCancelled {
                    if let day = store.world.goingOutOn, day != store.today { store.setGoingOut(false) }
                    do { try await Task.sleep(for: .seconds(30)) } catch { break }
                }
            }
        }
    }

    private var pin: some View {
        VStack(spacing: 12) {
            ZStack {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(context.date, format: Self.stamp)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Ink.words)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                        .padding(.horizontal, 36)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityAddTraits(.isHeader)
                }
                HStack {
                    Spacer()
                    Button { capture = CaptureRequest() } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Ink.brass)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Capture")
                }
            }
            .frame(height: dateSlot)
            HStack {
                Button {
                    store.setGoingOut(!store.goingOutToday)
                    if store.goingOutToday && !store.outsideQuestsToday().isEmpty {
                        reminderTime = Date().addingTimeInterval(900)
                        reminderDenied = false
                        showOuting = true
                    }
                } label: {
                    Label(store.goingOutToday ? "Going out today · On" : "Going out today",
                          systemImage: store.goingOutToday ? "checkmark.circle.fill" : "figure.walk")
                }
                .buttonStyle(.bordered)
                .accessibilityValue(store.goingOutToday ? "On" : "Off")
                Spacer()
                if store.goingOutToday {
                    Button("Reminder") {
                        reminderTime = max(store.world.outsideReminderAt ?? Date().addingTimeInterval(900), Date().addingTimeInterval(60))
                        reminderDenied = false
                        showOuting = true
                    }
                }
            }
            if let error = notifier.outsideReminderError {
                Text(error).font(.caption).foregroundStyle(Ink.muted)
            }
            if !due.isEmpty {
                Picker("Sort", selection: $sort) {
                    ForEach(TodaySort.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(Ink.ground)
    }

    private var outingSettings: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(store.outsideQuestsToday().count) outside quests ready today")
                    DatePicker("Remind me", selection: $reminderTime, displayedComponents: [.date, .hourAndMinute])
                    Button("Set reminder") {
                        Task {
                            let allowed = await notifier.requestPermission()
                            reminderDenied = !allowed
                            if allowed {
                                store.setOutsideReminder(reminderTime)
                                showOuting = false
                            }
                        }
                    }
                    .disabled(store.outsideQuestsToday().isEmpty || reminderTime <= Date() || Day(reminderTime) != store.today)
                    if store.world.outsideReminderAt != nil {
                        Button("Cancel reminder", role: .destructive) {
                            store.setOutsideReminder(nil)
                            showOuting = false
                        }
                    }
                } footer: {
                    Text("Choose a future time today. One notification lists your remaining outside quests. Tapping it opens Today. Going out resets tomorrow.")
                }
                if reminderDenied {
                    Text("Notifications are off. Enable them in iPhone Settings, then set the reminder again.")
                }
            }
            .navigationTitle("While you’re out")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showOuting = false } } }
        }
    }

    private static let stamp = Date.FormatStyle()
        .weekday(.wide)
        .month(.wide)
        .day()
        .year()
        .hour()
        .minute()
        .second()

    private var dueList: some View {
        List {
            ForEach(buckets) { bucket in
                bucketSection(bucket)
            }
            let entries = store.recentLog()
            if !entries.isEmpty {
                Section {
                    ForEach(entries) { LogRow(entry: $0) }
                } header: {
                    Text("Recently")
                        .foregroundStyle(Ink.muted)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .environment(\.defaultMinListHeaderHeight, 0)
    }

    @ViewBuilder
    private func bucketSection(_ bucket: DueBucket) -> some View {
        Section {
            if bucket.items.isEmpty {
                Text(bucket.empty)
                    .foregroundStyle(Ink.muted)
                    .listRowBackground(Ink.card)
            } else {
                ForEach(bucket.items, id: \.nodeID) { o in
                    dueRow(o)
                }
            }
        } header: {
            if let title = bucket.title {
                Text(title).foregroundStyle(Ink.muted)
            }
        } footer: {
                            if bucket.id == buckets.last?.id {
                Text("Swipe right when it is done, or tap to confirm. A routine will come back the next day its cue allows.")
            }
        }
    }

    @ViewBuilder
    private func dueRow(_ o: Objective) -> some View {
        TodayRow(
            objective: o,
            confirming: pendingID == o.nodeID,
            showKind: showKind || (store.goingOutToday && store.node(o.nodeID)?.1.isOutsideQuest == true),
            onAsk: { pendingID = o.nodeID },
            onCancel: { pendingID = nil },
            onDone: { markDone(o.nodeID) },
            onOpenPath: { openPath = OpenPath(id: $0) }
        )
    }

    private var buckets: [DueBucket] {
        let outside = store.goingOutToday ? store.outsideQuestsToday() : []
        let outsideIDs = Set(outside.map(\.nodeID))
        let rest = due.filter { !outsideIDs.contains($0.nodeID) }
        let featured = store.goingOutToday ? [DueBucket(id: "outside", title: "While you’re out", items: outside,
            empty: "No outside quests ready today. Flag a quest as Outside home in its editor.")] : []
        return featured + regularBuckets(rest)
    }

    private func regularBuckets(_ due: [Objective]) -> [DueBucket] {
        switch sort {
        case .quests:
            return [DueBucket(
                id: "quest",
                title: nil,
                items: due.filter { nodeKind($0) == .quest },
                empty: "No quests due today."
            )]
        case .practices:
            return [DueBucket(
                id: "practice",
                title: nil,
                items: due.filter { nodeKind($0) == .practice },
                empty: "No routines due today."
            )]
        case .when:
            return [Window.morning, .evening, .any].compactMap { window in
                let items = due.filter { $0.window == window }
                return items.isEmpty ? nil : DueBucket(id: window.rawValue, title: windowLabel(window), items: items)
            }
        }
    }

    private func nodeKind(_ o: Objective) -> NodeKind? {
        store.node(o.nodeID)?.1.kind
    }

    private func windowLabel(_ window: Window) -> String {
        switch window {
        case .morning: "Morning"
        case .evening: "Evening"
        case .any: "Anytime"
        }
    }

    private func markDone(_ nodeID: UUID) {
        store.respond(.done, nodeID: nodeID)
        if pendingID == nodeID { pendingID = nil }
    }

    var quiet: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.stars").font(.largeTitle).foregroundStyle(Ink.muted)
            Text(quietLine).multilineTextAlignment(.center).foregroundStyle(Ink.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    var quietLine: String {
        if !authorized { return "Objectives cannot find you yet. Allow notifications in Settings." }
        if store.activePaths.allSatisfy(\.isEvolved) { return "Every path has evolved. Add a milestone or start a new path." }
        return "Nothing is due today. Your paths are resting."
    }
}

private struct DueBucket: Identifiable {
    let id: String
    let title: String?
    let items: [Objective]
    var empty: String = ""

    init(id: String, title: String?, items: [Objective], empty: String = "") {
        self.id = id
        self.title = title
        self.items = items
        self.empty = empty
    }
}

private struct OpenPath: Identifiable, Hashable {
    let id: UUID
}

private struct TodayRow: View {
    @Environment(Store.self) private var store
    let objective: Objective
    let confirming: Bool
    var showKind: Bool
    var onAsk: () -> Void
    var onCancel: () -> Void
    var onDone: () -> Void
    var onOpenPath: (UUID) -> Void

    var body: some View {
        if let (path, node) = store.node(objective.nodeID) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Button(action: onAsk) {
                        VStack(alignment: .leading, spacing: 4) {
                            if showKind {
                                Text(node.kind == .practice ? "Routine" : "Quest")
                                    .font(.caption.weight(.bold))
                                    .textCase(.uppercase)
                                    .tracking(1)
                                    .foregroundStyle(Ink.brass)
                            }
                            if node.isOutsideQuest {
                                Label("Outside home", systemImage: "figure.walk")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Ink.brass)
                            }
                            if path.role == .work {
                                Label("Work", systemImage: "briefcase")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Ink.muted)
                            }
                            Text(node.title).font(.body.weight(.semibold)).foregroundStyle(Ink.words)
                            Text("\(path.name) · \(cueText(node.cue, kind: node.kind))")
                                .font(.caption)
                                .foregroundStyle(Ink.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    Button { onOpenPath(path.id) } label: {
                        Image(systemName: path.glyph).foregroundStyle(Ink.brass)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 28)
                    .accessibilityLabel(path.name)
                }

                if confirming {
                    Text(node.kind == .practice
                         ? "It leaves Today. It will come back when its cue allows."
                         : "It leaves Today. A quest does not come back.")
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                    HStack {
                        Button("Cancel", action: onCancel)
                            .foregroundStyle(Ink.muted)
                        Spacer()
                        Button("Done", action: onDone)
                            .fontWeight(.semibold)
                            .foregroundStyle(Ink.ground)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Ink.brass, in: Capsule())
                    }
                    .accessibilityElement(children: .contain)
                }
            }
            .padding(.vertical, store.goingOutToday && node.isOutsideQuest ? 6 : 0)
            .contentShape(Rectangle())
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button(action: onDone) {
                    Label("Done", systemImage: "checkmark")
                }
                .tint(Ink.brass)
            }
            .listRowBackground(
                (path.role == .work ? Ink.workCard : Ink.card)
                    .overlay {
                        if store.goingOutToday && node.isOutsideQuest {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Ink.brass.opacity(0.85), lineWidth: 1.5)
                                .shadow(color: Ink.brass.opacity(0.45), radius: 6)
                                .allowsHitTesting(false)
                        }
                    }
            )
            .animation(.easeInOut(duration: 0.2), value: confirming)
        }
    }
}

struct PathRow: View {
    let path: Path
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: path.glyph).font(.title2).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(path.name).font(.body.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 5) {
                ForEach(path.milestones) { m in
                    Circle().fill(m.tickedOn == nil ? Color.clear : Ink.brass)
                        .overlay(Circle().stroke(m.tickedOn == nil ? Ink.muted : Ink.brass, lineWidth: 1.5))
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    var subtitle: String {
        if path.status == .resting { return "Resting" }
        if path.isEvolved { return "Evolved" }
        if path.role == .decision, let d = path.deadline { return "Deciding · \(max(0, d.days(since: Day(Date())))) days left" }
        if let next = path.nextMilestone { return "\(path.identity) · next: \(next.text)" }
        return path.identity
    }
}

struct LogRow: View {
    @Environment(Store.self) private var store
    let entry: LogEntry
    var body: some View {
        HStack(spacing: 14) {
            if let f = entry.photoFile, let img = UIImage(contentsOfFile: store.photoURL(f).path) {
                Image(uiImage: img).resizable().scaledToFill().frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: entry.milestoneID == nil ? "checkmark.circle" : "flag.checkered").font(.title2).frame(width: 36)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.text).font(.body)
                Text(entry.day.description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
