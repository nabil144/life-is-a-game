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
    @AppStorage(Prefs.todayStyleKey) private var style: TodayStyle = .objectiveAndPaths
    @State private var authorized = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch style {
                    case .oneCard: oneCard
                    case .objectiveAndPaths: objectiveAndPaths
                    case .pathsFirst: pathsFirst
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(style == .pathsFirst ? "Evolving" : "Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { capture = CaptureRequest() } label: { Image(systemName: "plus") }
                }
            }
            .task { authorized = await notifier.authorized() }
        }
    }

    var dateLine: some View {
        Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .font(.subheadline).foregroundStyle(.secondary)
    }

    @ViewBuilder
    var objectiveOrQuiet: some View {
        if let o = store.todaysObjective() {
            ObjectiveCard(objective: o, compact: style != .oneCard)
        } else {
            quiet
        }
    }

    var quiet: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.stars").font(.largeTitle).foregroundStyle(.secondary)
            Text(quietLine).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30)
    }

    var quietLine: String {
        if !authorized { return "Objectives cannot find you yet. Allow notifications in Settings." }
        if store.activePaths.allSatisfy(\.isEvolved) { return "Every path has evolved. Add a milestone or start a new path." }
        return "Nothing is due today. Your paths are resting."
    }

    // MARK: Style A

    var oneCard: some View {
        Group {
            dateLine
            objectiveOrQuiet
            if store.todaysObjective() != nil {
                Text("That is all for today. One thing, done well.")
                    .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
            recently
        }
    }

    // MARK: Style B

    var objectiveAndPaths: some View {
        Group {
            dateLine
            objectiveOrQuiet
            Text("Your paths").font(.title3.bold())
            GroupBox {
                ForEach(store.activePaths) { p in
                    NavigationLink(value: p.id) { PathRow(path: p) }
                }
            }
            recently
        }
        .navigationDestination(for: UUID.self) { id in
            if let p = store.path(id) { PathDetailView(pathID: p.id, capture: $capture) }
        }
    }

    // MARK: Style C

    var pathsFirst: some View {
        Group {
            Text("\(store.activePaths.count) paths · \(store.todaysObjective() == nil ? "quiet today" : "1 objective today")")
                .font(.subheadline).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.activePaths) { p in
                        let hot = store.todaysObjective()?.pathID == p.id
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: p.glyph).font(.title2)
                            Text(p.name).font(.subheadline.bold())
                            Text(hot ? "objective ready" : (p.isEvolved ? "evolved" : "quiet today")).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(12).frame(minWidth: 120, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(hot ? Color.accentColor : .clear, lineWidth: 2))
                    }
                }
            }
            if let o = store.todaysObjective(), let p = store.path(o.pathID) {
                Text("\(p.name) · \(p.identity)").font(.title3.bold())
                ObjectiveCard(objective: o, compact: true)
                Text("Milestones").font(.headline)
                GroupBox { MilestoneList(pathID: p.id) }
            } else {
                quiet
            }
        }
    }

    // MARK: Shared

    @ViewBuilder
    var recently: some View {
        let entries = store.recentLog()
        if !entries.isEmpty {
            Text("Recently").font(.title3.bold())
            GroupBox {
                ForEach(entries) { e in LogRow(entry: e) }
            }
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
                    Circle().fill(m.tickedOn == nil ? Color.clear : Color.green)
                        .overlay(Circle().stroke(m.tickedOn == nil ? Color.secondary : .green, lineWidth: 1.5))
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
