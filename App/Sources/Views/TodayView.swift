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
    @State private var filteredPathID: UUID?
    @State private var showPathFilter = false
    @State private var morePathsBelow = false
    @ScaledMetric(relativeTo: .caption) private var sortLabelWidth: CGFloat = 56
    @State private var authorized = true
    @State private var pendingID: UUID?
    @State private var openPath: OpenPath?
    @State private var showOuting = false
    @State private var reminderTime = Date().addingTimeInterval(15 * 60)
    @State private var reminderDenied = false

    private var filteredPath: LifeEngine.Path? { store.activePaths.first { $0.id == filteredPathID } }
    private var due: [Objective] {
        store.dueToday().filter { filteredPathID == nil || $0.pathID == filteredPathID }
    }
    private var showKind: Bool { sort == .when }
    private var dateSlot: CGFloat { 68 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pin
                dueList
            }
            .background(Ink.ground)
            .toolbar(openPath == nil ? .hidden : .automatic, for: .navigationBar)
            .navigationDestination(item: $openPath) { dest in
                PathDetailView(pathID: dest.id, capture: $capture)
            }
            .onChange(of: filteredPathID) { _, _ in pendingID = nil }
            .onChange(of: store.activePaths.map(\.id)) { _, ids in
                if let filteredPathID, !ids.contains(filteredPathID) { self.filteredPathID = nil }
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
        VStack(spacing: 4) {
            ZStack {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 2) {
                        Text(context.date, format: Self.dateStamp)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                        Text(context.date, format: Self.timeStamp)
                    }
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(Ink.words)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .padding(.horizontal, 36)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityAddTraits(.isHeader)
                }
                HStack {
                    reminderControl
                    Spacer()
                    Button { capture = CaptureRequest() } label: {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Ink.brass)
                            .frame(width: 30, height: 30)
                            .background(Ink.card, in: PixelPanel())
                            .overlay(PixelPanel().stroke(Ink.brass, lineWidth: 1))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Capture")
                }
            }
            .frame(height: dateSlot)
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    outingControls
                        .fixedSize(horizontal: true, vertical: false)
                    pathFilter
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                sortControls
            }
            if let error = notifier.outsideReminderError {
                Text(error).font(.caption).foregroundStyle(Ink.muted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(Ink.ground)
    }

    private var pathFilter: some View {
        HStack(spacing: 0) {
            Button { showPathFilter = true } label: {
                HStack(spacing: 4) {
                    Text(filteredPath?.name ?? "All paths")
                        .lineLimit(nil)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Image(systemName: "chevron.down")
                        .font(.caption2.bold())
                        .fixedSize()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(filteredPathID == nil ? Ink.muted : Ink.brass)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filter by path")
            .accessibilityValue(filteredPath?.name ?? "All paths")
            .popover(isPresented: $showPathFilter, arrowEdge: .top) {
                ScrollView {
                    VStack(spacing: 4) {
                        filterOption("All paths", glyph: "square.grid.2x2", id: nil)
                        ForEach(store.activePaths) { path in
                            filterOption(path.name, glyph: path.glyph, id: path.id)
                        }
                    }.padding(8)
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height > geometry.visibleRect.maxY + 2
                } action: { _, hasMore in
                    morePathsBelow = hasMore
                }
                .overlay(alignment: .bottom) {
                    if morePathsBelow {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Ink.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 20)
                            .background {
                                LinearGradient(colors: [Ink.ground.opacity(0), Ink.ground],
                                               startPoint: .top, endPoint: .center)
                            }
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .onDisappear { morePathsBelow = false }
                .frame(width: 280, height: min(CGFloat(store.activePaths.count + 1) * 48 + 16, 336))
                .presentationCompactAdaptation(.popover)
                .presentationBackground(Ink.ground)
            }
        }
    }

    private func filterOption(_ name: String, glyph: String, id: UUID?) -> some View {
        Button {
            filteredPathID = id
            showPathFilter = false
        } label: {
            Label(name, systemImage: glyph)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PixelButtonStyle(selected: filteredPathID == id, compact: true, fillsWidth: true))
        .accessibilityAddTraits(filteredPathID == id ? .isSelected : [])
    }

    private var outingControls: some View {
        HStack(spacing: 4) {
            Button {
                store.setGoingOut(!store.goingOutToday)
                if store.goingOutToday && !store.outsideQuestsToday().isEmpty {
                    reminderTime = Date().addingTimeInterval(900)
                    reminderDenied = false
                    showOuting = true
                }
            } label: {
                Label("Out", systemImage: "figure.walk")
            }
            .buttonStyle(PixelButtonStyle(selected: store.goingOutToday, compact: true))
            .accessibilityLabel("Going out today")
            .accessibilityValue(store.goingOutToday ? "On" : "Off")
        }
    }

    private var reminderControl: some View {
        HStack(spacing: 0) {
            if store.goingOutToday {
                Button {
                    reminderTime = max(store.world.outsideReminderAt ?? Date().addingTimeInterval(900), Date().addingTimeInterval(60))
                    reminderDenied = false
                    showOuting = true
                } label: {
                    Image(systemName: "bell")
                }
                .buttonStyle(PixelButtonStyle(compact: true))
                .accessibilityLabel("Outside quest reminder")
            }
        }
    }

    @ViewBuilder
    private var sortControls: some View {
        if !due.isEmpty {
            HStack(spacing: 3) {
                ForEach(TodaySort.allCases) { s in
                    Button { sort = s } label: {
                        Text(s.label)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(width: sortLabelWidth)
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(PixelButtonStyle(selected: sort == s, compact: true))
                    .accessibilityAddTraits(sort == s ? .isSelected : [])
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Sort")
        }
    }

    private var outingSettings: some View {
        NavigationStack {
            PixelList {
                Section {
                    Text("\(store.outsideQuestsToday().count) outside quests ready today")
                    PixelDatePicker("Remind me", selection: $reminderTime, displayedComponents: [.date, .hourAndMinute])
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
                }
                Text("Choose a future time today. One notification lists your remaining outside quests. Tapping it opens Today. Going out resets tomorrow.").pixelHelper()
                if reminderDenied {
                    Text("Notifications are off. Enable them in iPhone Settings, then set the reminder again.")
                }
            }
            .navigationTitle("While you’re out")
            .toolbar { PixelToolbarItem(placement: .cancellationAction) { Button("Close") { showOuting = false } } }
        }
    }

    private static let dateStamp = Date.FormatStyle()
        .weekday(.wide)
        .month(.wide)
        .day()
        .year()

    private static let timeStamp = Date.FormatStyle()
        .hour()
        .minute()
        .second()

    private var dueList: some View {
        List {
            if due.isEmpty {
                quiet
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            if !due.isEmpty {
                ForEach(buckets) { bucket in
                    bucketSection(bucket)
                }
            }
            if !due.isEmpty {
                Text("Swipe right when it is done, or tap to confirm. A routine will come back the next day its cue allows.")
                    .pixelHelper()
            }
            let entries = filteredPathID.map { Array(store.log(for: $0).prefix(5)) } ?? store.recentLog()
            if !entries.isEmpty {
                Section {
                    ForEach(entries) { entry in
                        LogRow(entry: entry, pixelStyle: true, subdued: true)
                            .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Recently")
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .textCase(nil)
                        .foregroundStyle(Ink.muted)
                        .padding(.top, 12)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .listStyle(.plain)
        // Each card reserves its own gap, including across bucket boundaries.
        .listRowSpacing(0)
        .padding(.horizontal, 12)
        .contentMargins(.top, 0, for: .scrollContent)
        .environment(\.defaultMinListHeaderHeight, 0)
    }

    @ViewBuilder
    private func bucketSection(_ bucket: DueBucket) -> some View {
        Section {
            if bucket.items.isEmpty {
                Text(bucket.empty)
                    .foregroundStyle(Color.gray.opacity(0.85))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(bucket.items, id: \.nodeID) { o in
                    dueRow(o)
                }
            }
        } header: {
            if let title = bucket.title {
                Text(title)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(Ink.brass)
            }
        }
    }

    @ViewBuilder
    private func dueRow(_ o: Objective) -> some View {
        TodayRow(
            objective: o,
            confirming: pendingID == o.nodeID,
            showKind: showKind,
            onAsk: { pendingID = pendingID == o.nodeID ? nil : o.nodeID },
            onCancel: { pendingID = nil },
            onDone: { markDone(o.nodeID) },
            onOpenPath: { openPath = OpenPath(id: $0) }
        )
    }

    private var buckets: [DueBucket] {
        let outside = store.goingOutToday ? store.outsideQuestsToday().filter { filteredPathID == nil || $0.pathID == filteredPathID } : []
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
            Image(systemName: "moon.stars").font(.largeTitle)
            Text(quietLine).multilineTextAlignment(.center)
        }
        .foregroundStyle(Color.gray.opacity(0.85))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    var quietLine: String {
        if let path = filteredPath { return "Nothing is due today for \(path.name). Choose All paths to see the rest." }
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
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    PixelQuestMark(routine: node.kind == .practice)
                    Button(action: onAsk) {
                        VStack(alignment: .leading, spacing: 2) {
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
                            Text(node.title).font(.title3.weight(.semibold)).foregroundStyle(Ink.words)
                            Text("\(path.name) · \(cueText(node.cue, kind: node.kind))")
                                .font(.caption)
                                .foregroundStyle(Ink.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(confirming ? "Selected" : "Not selected")
                    .accessibilityHint(confirming ? "Hide quest actions" : "Show quest actions")

                    Button { onOpenPath(path.id) } label: {
                        Image(systemName: path.glyph).foregroundStyle(Ink.brass)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(path.name)
                }

                if confirming {
                    if let launch = node.appLaunch { AppLaunchButton(launch: launch) }
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
                            .background(Ink.brass, in: PixelPanel())
                    }
                    .accessibilityElement(children: .contain)
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 6))
            .contentShape(Rectangle())
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button(action: onDone) {
                    Image(uiImage: PixelSwipeArtwork.done)
                        .renderingMode(.original)
                }
                .accessibilityLabel("Mark as done")
                .tint(Ink.ground)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    store.respond(.letGo, nodeID: node.id)
                    onCancel()
                } label: {
                    Image(uiImage: PixelSwipeArtwork.cancel)
                        .renderingMode(.original)
                }
                .accessibilityLabel("Cancel item")
                .tint(Ink.ground)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(
                PixelPanel()
                    .fill(path.role == .work ? Ink.workCard : Ink.card)
                    .overlay {
                        PixelPanel()
                            .stroke(store.goingOutToday && node.isOutsideQuest ? Ink.brass : Ink.line,
                                    lineWidth: 2)
                            .shadow(color: store.goingOutToday && node.isOutsideQuest ? Ink.brass.opacity(0.4) : .clear,
                                    radius: 5)
                    }
                    // Keep the highlight inside the card so it cannot fill the gap.
                    .clipShape(PixelPanel())
                    .padding(.horizontal, 1)
                    .padding(.vertical, 3)
                    .allowsHitTesting(false)
            )
            .animation(.easeInOut(duration: 0.2), value: confirming)
        }
    }
}

struct PathRow: View {
    let path: Path
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: path.glyph).font(.title3).frame(width: 36, height: 36).pixelCard()
            VStack(alignment: .leading, spacing: 2) {
                Text(path.name).font(.title3.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 5) {
                ForEach(path.milestones) { m in
                    Rectangle().fill(m.tickedOn == nil ? Color.clear : Ink.brass)
                        .overlay(Rectangle().stroke(m.tickedOn == nil ? Ink.muted : Ink.brass, lineWidth: 1.5))
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(.vertical, 2)
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
    @State private var confirmUndo = false
    let entry: LogEntry
    var pixelStyle = false
    var subdued = false
    var body: some View {
        Group {
            if store.canUndoRoutineCompletion(entry) {
                Button { confirmUndo = true } label: { content }
                    .buttonStyle(.plain)
                    .accessibilityHint("Undo this routine completion")
            } else {
                content
            }
        }
        .confirmationDialog("Undo this routine completion?", isPresented: $confirmUndo, titleVisibility: .visible) {
            Button("Undo completion", role: .destructive) { store.undoRoutineCompletion(entry.id) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove the check for \(entry.text) on \(entry.day.description). Earlier completions stay in your log.")
        }
    }

    private var content: some View {
        HStack(spacing: pixelStyle ? 8 : 14) {
            if let f = entry.photoFile, let img = UIImage(contentsOfFile: store.photoURL(f).path) {
                if pixelStyle {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 32, height: 32).clipShape(PixelPanel())
                } else {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                if subdued {
                    Image(systemName: entry.milestoneID == nil ? "checkmark" : "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(Ink.muted)
                        .frame(width: 28, height: 28)
                } else if pixelStyle {
                    Image(systemName: entry.milestoneID == nil ? "checkmark" : "trophy.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(Ink.brass)
                        .frame(width: 28, height: 28)
                        .overlay(PixelPanel().stroke(Ink.brass, lineWidth: 1))
                } else {
                Image(systemName: entry.milestoneID == nil ? "checkmark.circle" : "trophy.fill").font(.title2).frame(width: 36)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.text)
                    .font(subdued ? .subheadline : .body)
                    .foregroundStyle(subdued ? Ink.muted : Ink.words)
                Text(entry.day.description)
                    .font(pixelStyle ? .system(.caption, design: .monospaced) : .caption)
                    .foregroundStyle(pixelStyle ? Ink.muted : .secondary)
            }
            Spacer()
            if subdued && store.canUndoRoutineCompletion(entry) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.caption)
                    .foregroundStyle(Ink.muted)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: subdued ? 44 : nil)
        .contentShape(Rectangle())
        .padding(.vertical, pixelStyle ? 0 : 6)
    }
}
