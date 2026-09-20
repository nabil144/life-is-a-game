import SwiftUI
import LifeEngine

struct PathDetailView: View {
    @Environment(Store.self) private var store
    let pathID: UUID
    @Binding var capture: CaptureRequest?
    @State private var celebrate: Milestone?
    @State private var newMilestone = ""
    @State private var editing: Node?
    @State private var editingPath = false
    @State private var milestoneEditor: MilestoneEditorRequest?

    var body: some View {
        ZStack { detail }
            .sheet(item: $milestoneEditor) { MilestoneEditorSheet(request: $0) }
    }

    @ViewBuilder
    private var detail: some View {
        if let path = store.path(pathID) {
            PixelList {
                Section {
                    Button { editingPath = true } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: path.glyph).font(.title2).frame(width: 44, height: 44).pixelCard()
                            Text(path.name).font(.title2.bold()).foregroundStyle(.primary)
                            Text("\(path.identity) · \(path.role.rawValue) · surfaces \(roleWindowText(path.role))")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("Tap to change this path.")
                                .font(.caption).foregroundStyle(.tint)
                            if path.isEvolved {
                                Text("This path has evolved. It will stay here, quiet.").font(.footnote).foregroundStyle(Ink.brass).padding(.top, 4)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Milestones") {
                    MilestoneList(pathID: pathID, onTick: { celebrate = $0 }, onOpenFact: {
                        milestoneEditor = MilestoneEditorRequest(pathID: pathID, milestone: $0)
                    })
                    HStack {
                        TextField("Add a milestone as a sentence", text: $newMilestone)
                        Button("Add") {
                            var p = path
                            p.milestones.append(Milestone(text: newMilestone))
                            store.update(p)
                            newMilestone = ""
                        }.disabled(newMilestone.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                nodeSection("Quests", path: path, kind: .quest)
                nodeSection("Routines", path: path, kind: .practice)

                let entries = store.log(for: pathID)
                if !entries.isEmpty {
                    Section("Log") { ForEach(entries) { LogRow(entry: $0, pixelStyle: true) } }
                }

                Section {
                    if path.status == .active {
                        Button("Let it rest") { var p = path; p.status = .resting; store.update(p) }
                    } else {
                        Button("Continue") { var p = path; p.status = .active; store.update(p) }
                    }
                    if path.status != .archived {
                        Button("Put it away", role: .destructive) { var p = path; p.status = .archived; store.update(p) }
                    }
                }
            }
            .navigationTitle(path.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                PixelToolbarItem(placement: .primaryAction) {
                    Button { capture = CaptureRequest(pathID: pathID) } label: { Image(systemName: "plus") }
                }
                PixelToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { editingPath = true }
                }
            }
            .fullScreenCover(item: $celebrate) { m in
                CelebrationView(path: path, milestone: m)
            }
            .sheet(item: $editing) { n in
                NodeEditView(pathID: pathID, node: n)
            }
            .sheet(isPresented: $editingPath) {
                PathEditView(path: path)
            }
        }
    }

    @ViewBuilder
    func nodeSection(_ title: String, path: Path, kind: NodeKind) -> some View {
        let nodes = path.nodes.filter { $0.kind == kind && $0.state != .notTaken }
        if !nodes.isEmpty {
            Section {
                ForEach(nodes) { n in
                    Button { editing = n } label: {
                        HStack {
                            PixelQuestMark(routine: kind == .practice)
                                .foregroundStyle(n.isDone ? Ink.brass : Ink.muted)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(n.title).strikethrough(n.isDone).foregroundStyle(.primary)
                                Text(nodeMeta(n, in: path)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.isDueToday(n.id) { Text("today").font(.caption.bold()).foregroundStyle(.tint) }
                            if n.state == .paused {
                                Button("Reopen") { store.respond(.reopen, nodeID: n.id) }.font(.caption).buttonStyle(.borderless)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Let it go", role: .destructive) { store.respond(.letGo, nodeID: n.id) }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if kind == .quest && n.isDone {
                            Button {
                                store.respond(.reopen, nodeID: n.id)
                            } label: {
                                Label("Mark as not done", systemImage: "arrow.uturn.backward")
                            }
                            .tint(Ink.brass)
                        }
                    }
                }
            } header: {
                Text(title).font(.system(.caption, design: .monospaced).bold()).foregroundStyle(Ink.brass)
            }
            if kind == .quest {
                Text("Tap one to change it or mark a completed quest as not done. Swipe left to let it go. Plus adds another.")
                    .font(.caption)
                    .foregroundStyle(Color.gray.opacity(0.85))
                    .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
    }

    func nodeMeta(_ n: Node, in path: Path) -> String {
        var parts = [cueText(n.cue, kind: n.kind)]
        if let a = n.after, let b = path.node(a) { parts.append("after \(b.title)") }
        if n.kind == .practice, let last = n.lastDone { parts.append("last \(last.description)") }
        if n.state == .paused { parts.append("paused") }
        return parts.joined(separator: " · ")
    }
}

func roleWindowText(_ role: Role) -> String {
    switch role {
    case .hobby, .craft: "evenings and weekends"
    case .lab: "weekends"
    case .decision: "once a week until the deadline"
    case .work: "weekday mornings"
    }
}

struct MilestoneList: View {
    @Environment(Store.self) private var store
    let pathID: UUID
    var onTick: ((Milestone) -> Void)? = nil
    var onOpenFact: (Milestone) -> Void

    var body: some View {
        if let path = store.path(pathID) {
            ForEach(path.milestones) { m in
                Button {
                    if m.tickedOn == nil {
                        store.tickMilestone(m.id, in: pathID)
                        onTick?(m)
                    } else {
                        onOpenFact(m)
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: m.tickedOn == nil ? "flag" : "trophy.fill")
                            .foregroundStyle(m.tickedOn == nil ? Ink.muted : Ink.brass)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.text).foregroundStyle(.primary)
                            Text(m.tickedOn.map { "true on \($0.description) · tap to change" } ?? "tap when true")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .sensoryFeedback(.success, trigger: m.tickedOn)
            }
        }
    }
}
