import SwiftUI
import LifeEngine

struct PathDetailView: View {
    @Environment(Store.self) private var store
    let pathID: UUID
    @Binding var capture: CaptureRequest?
    @State private var celebrate: Milestone?
    @State private var newMilestone = ""
    @State private var editing: Node?

    var body: some View {
        if let path = store.path(pathID) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: path.glyph).font(.system(size: 40))
                        Text(path.name).font(.largeTitle.bold())
                        Text("\(path.identity) · \(path.role.rawValue) · surfaces \(roleWindowText(path.role))")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if path.isEvolved {
                            Text("This path has evolved. It will stay here, quiet.").font(.footnote).foregroundStyle(.green).padding(.top, 4)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Milestones") {
                    MilestoneList(pathID: pathID, onTick: { celebrate = $0 })
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
                nodeSection("Practices", path: path, kind: .practice)

                let entries = store.log(for: pathID)
                if !entries.isEmpty {
                    Section("Log") { ForEach(entries) { LogRow(entry: $0) } }
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { capture = CaptureRequest(pathID: pathID) } label: { Image(systemName: "plus") }
                }
            }
            .fullScreenCover(item: $celebrate) { m in
                CelebrationView(path: path, milestone: m)
            }
            .sheet(item: $editing) { n in
                NodeEditView(pathID: pathID, node: n)
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
                            Image(systemName: kind == .quest ? "diamond" : "arrow.trianglehead.2.clockwise")
                                .foregroundStyle(n.isDone ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(n.title).strikethrough(n.isDone).foregroundStyle(.primary)
                                Text(nodeMeta(n, in: path)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.todaysObjective()?.nodeID == n.id { Text("today").font(.caption.bold()).foregroundStyle(.tint) }
                            if n.state == .paused {
                                Button("Reopen") { store.respond(.reopen, nodeID: n.id) }.font(.caption).buttonStyle(.borderless)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Let it go", role: .destructive) { store.respond(.letGo, nodeID: n.id) }
                    }
                }
            } header: {
                Text(title)
            } footer: {
                if kind == .quest { Text("Tap one to change it. Swipe to let it go. Plus adds another.") }
            }
        }
    }

    func nodeMeta(_ n: Node, in path: Path) -> String {
        var parts = [cueText(n.cue)]
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

    var body: some View {
        if let path = store.path(pathID) {
            ForEach(path.milestones) { m in
                Button {
                    let wasTicked = m.tickedOn != nil
                    store.tickMilestone(m.id, in: pathID)
                    if !wasTicked { onTick?(m) }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: m.tickedOn == nil ? "circle" : "circle.fill")
                            .foregroundStyle(m.tickedOn == nil ? Color.secondary : Color.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.text).foregroundStyle(.primary)
                            Text(m.tickedOn.map { "ticked \($0.description)" } ?? "tap when true")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .sensoryFeedback(.success, trigger: m.tickedOn)
            }
        }
    }
}
