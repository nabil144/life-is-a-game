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

struct TodayView: View {
    @Environment(Store.self) private var store
    @Environment(Notifier.self) private var notifier
    @Binding var capture: CaptureRequest?
    @State private var authorized = true
    @State private var pendingID: UUID?
    @State private var openPath: OpenPath?

    var body: some View {
        NavigationStack {
            Group {
                if store.dueToday().isEmpty {
                    quiet
                } else {
                    List {
                        Section {
                            ForEach(store.dueToday(), id: \.nodeID) { o in
                                TodayRow(
                                    objective: o,
                                    confirming: pendingID == o.nodeID,
                                    onAsk: { pendingID = o.nodeID },
                                    onCancel: { pendingID = nil },
                                    onDone: { markDone(o.nodeID) },
                                    onOpenPath: { openPath = OpenPath(id: $0) }
                                )
                            }
                        } header: {
                            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        } footer: {
                            Text("Swipe right when it is done, or tap to confirm. A practice will come back the next day its cue allows.")
                        }
                        let entries = store.recentLog()
                        if !entries.isEmpty {
                            Section("Recently") {
                                ForEach(entries) { LogRow(entry: $0) }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Ink.ground)
            .navigationTitle("Today")
            .navigationDestination(item: $openPath) { dest in
                PathDetailView(pathID: dest.id, capture: $capture)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { capture = CaptureRequest() } label: { Image(systemName: "plus") }
                }
            }
            .task { authorized = await notifier.authorized() }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    var quietLine: String {
        if !authorized { return "Objectives cannot find you yet. Allow notifications in Settings." }
        if store.activePaths.allSatisfy(\.isEvolved) { return "Every path has evolved. Add a milestone or start a new path." }
        return "Nothing is due today. Your paths are resting."
    }
}

private struct OpenPath: Identifiable, Hashable {
    let id: UUID
}

private struct TodayRow: View {
    @Environment(Store.self) private var store
    let objective: Objective
    let confirming: Bool
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
                            Text(node.kind == .practice ? "Practice" : "Quest")
                                .font(.caption.weight(.bold))
                                .textCase(.uppercase)
                                .tracking(1)
                                .foregroundStyle(Ink.brass)
                            Text(node.title).font(.body.weight(.semibold)).foregroundStyle(Ink.words)
                            Text("\(path.name) · \(cueText(node.cue))")
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
            .contentShape(Rectangle())
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button(action: onDone) {
                    Label("Done", systemImage: "checkmark")
                }
                .tint(Ink.brass)
            }
            .listRowBackground(Ink.card)
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
