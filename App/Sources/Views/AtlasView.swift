import SwiftUI
import LifeEngine

enum PathsStyle: String, CaseIterable, Identifiable {
    case atlas, list
    var id: String { rawValue }
    var label: String { self == .atlas ? "World" : "List" }
}

/// Layout is cached when data changes. Native UIScrollView owns camera gestures.
struct AtlasView: View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var openPath: UUID?
    @State private var map = WorldMapSnapshot(paths: [])
    @State private var selected: String?
    @State private var camera = WorldCamera()
    @State private var editor: WorldEditor?
    @State private var generating = false

    var body: some View {
        WorldScrollView(content: WorldMapContent(map: map, selected: selected, select: { select($0) }),
                        size: map.layout.size, camera: camera, animated: !reduceMotion)
            .background(Ink.ground)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 8) {
                    Button("Overview") { selected = nil; camera = WorldCamera() }
                    Button("You") { selected = nil; focus(map.layout.center) }
                    Spacer()
                    Menu {
                        ForEach(store.activePaths) { path in
                            Button(path.name) { select("path-\(path.id)", focusDestination: true) }
                        }
                    } label: { Label("Paths", systemImage: "point.3.connected.trianglepath.dotted") }
                    .disabled(store.activePaths.isEmpty)
                }
                .buttonStyle(PixelButtonStyle(compact: true))
                .padding(.horizontal, 12)
                .background(Ink.ground)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                selectionPanel
            }
            .task(id: store.activePaths) {
                let paths = store.activePaths
                let inputs = paths.map { WorldLayout.Input(id: $0.id, work: $0.nodes.filter(\.isOpen).map(\.id)) }
                if inputs == map.inputs {
                    map = WorldMapSnapshot(paths: paths, previous: map)
                    generating = false
                    return
                }
                generating = true
                let build = Task.detached(priority: .userInitiated) {
                    let layout = WorldLayout(paths: inputs)
                    return (layout, WorldMaze(layout: layout))
                }
                let geometry = await withTaskCancellationHandler {
                    await build.value
                } onCancel: { build.cancel() }
                guard !Task.isCancelled else { return }
                let previousCenter = map.layout.center
                map = WorldMapSnapshot(paths: paths, geometry: geometry)
                generating = false
                if let selected, let room = map.rooms.first(where: { $0.id == selected }) {
                    if previousCenter != map.layout.center { focus(room.center) }
                } else if selected != nil {
                    self.selected = nil
                    camera = WorldCamera()
                }
            }
            .sheet(item: $editor) { item in
                NodeEditView(pathID: item.pathID, node: item.node)
            }
    }

    private func focus(_ point: CGPoint) {
        camera = WorldCamera(center: point)
    }

    private func select(_ id: String, focusDestination: Bool = false) {
        if id.isEmpty { selected = nil; return }
        if id == "you" { selected = nil; focus(map.layout.center); return }
        if selected == id { selected = nil; return }
        selected = id
        if focusDestination, let room = map.rooms.first(where: { $0.id == id }) { focus(room.center) }
    }

    @ViewBuilder private var selectionPanel: some View {
        if let selected, let room = map.rooms.first(where: { $0.id == selected }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(room.title).font(.headline)
                    Text(room.subtitle).font(.caption).foregroundStyle(Ink.muted)
                }
                Spacer()
                if room.workID == nil, let pathID = room.pathID,
                   let path = store.activePaths.first(where: { $0.id == pathID }) {
                    Menu("Quests") {
                        ForEach(path.nodes.filter(\.isOpen)) { node in
                            Button(node.title) { select("work-\(node.id)", focusDestination: true) }
                        }
                    }
                    .disabled(!path.nodes.contains(where: \.isOpen))
                }
                Button("Open") {
                    guard let pathID = room.pathID else { return }
                    if let workID = room.workID, let (_, node) = store.node(workID) {
                        editor = WorldEditor(pathID: pathID, node: node)
                    } else { openPath = pathID }
                }
                .buttonStyle(PixelButtonStyle(selected: true, compact: true))
                Button { self.selected = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel("Deselect")
            }
            .padding(12)
            .background(Ink.card, in: PixelPanel())
            .padding(8)
        } else {
            VStack(spacing: 4) {
                Text(generating ? "Growing your maze…" : (store.activePaths.isEmpty ? "Add a path to grow your world." : "Tap a destination to reveal its route · tap the maze to clear"))
                if store.activePaths.isEmpty { RestoreFileButton() }
            }
            .font(.caption).foregroundStyle(Ink.muted)
            .padding(8).frame(maxWidth: .infinity).background(Ink.ground)
        }
    }
}

private struct WorldEditor: Identifiable {
    var pathID: UUID
    var node: LifeEngine.Node
    var id: UUID { node.id }
}

struct WorldCamera {
    var id = UUID()
    var center: CGPoint? = nil
}

struct WorldRoom: Identifiable {
    var id: String
    var pathID: UUID?
    var workID: UUID?
    var center: CGPoint
    var title: String
    var subtitle: String
    var glyph: String
    var routine: Bool
    var work: Bool
}

struct WorldMapSnapshot {
    var inputs: [WorldLayout.Input]
    var layout: WorldLayout
    var rooms: [WorldRoom]
    var corridors: SwiftUI.Path
    var routes: [String: SwiftUI.Path]

    init(paths: [LifeEngine.Path], previous: WorldMapSnapshot? = nil, geometry: (WorldLayout, WorldMaze)? = nil) {
        inputs = paths.map { .init(id: $0.id, work: $0.nodes.filter(\.isOpen).map(\.id)) }
        layout = geometry?.0 ?? (previous?.inputs == inputs ? previous!.layout : WorldLayout(paths: inputs))
        let pathIndex = Dictionary(uniqueKeysWithValues: paths.map { ($0.id, $0) })
        let nodeIndex = Dictionary(uniqueKeysWithValues: paths.flatMap(\.nodes).map { ($0.id, $0) })
        rooms = layout.rooms.map { room in
            let path = room.pathID.flatMap { pathIndex[$0] }
            let node = room.workID.flatMap { nodeIndex[$0] }
            return WorldRoom(id: room.id, pathID: room.pathID, workID: room.workID, center: room.center,
                             title: node?.title ?? path?.name ?? "You",
                             subtitle: node.map { $0.kind == .practice ? "Routine" : "Quest" }
                                ?? path.map { "\($0.nodes.filter(\.isOpen).count) quests & routines" } ?? "Your world",
                             glyph: path?.glyph ?? "brain", routine: node?.kind == .practice, work: path?.role == .work)
        }
        if let previous, previous.inputs == inputs {
            corridors = previous.corridors; routes = previous.routes
        } else {
            corridors = SwiftUI.Path(); routes = [:]
            let maze = geometry?.1 ?? WorldMaze(layout: layout)
            for segment in maze.segments {
                corridors.move(to: segment.from)
                corridors.addLine(to: segment.to)
            }
            for (id, points) in maze.routes {
                var route = SwiftUI.Path(); route.addLines(points)
                routes[id] = route
            }
            // Selecting a path reveals its whole family. A child reveals only its journey.
            for input in inputs {
                var family = routes["path-\(input.id)"] ?? SwiftUI.Path()
                for id in input.work {
                    if let route = routes["work-\(id)"] { family.addPath(route) }
                }
                routes["path-\(input.id)"] = family
            }
        }
    }
}

struct WorldMapContent: View {
    let map: WorldMapSnapshot
    let selected: String?
    let select: (String) -> Void

    private func revealed(_ room: WorldRoom, chosen: WorldRoom?) -> Bool {
        if room.id == "you" || room.id == selected { return true }
        guard let chosen,
              let pathID = chosen.pathID, room.pathID == pathID else { return false }
        return chosen.workID == nil || room.workID == nil
    }

    var body: some View {
        let chosen = map.rooms.first(where: { $0.id == selected })
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Ink.ground)
                .contentShape(Rectangle())
                .onTapGesture { select("") }
                .accessibilityHidden(true)
            WorldCorridors(base: map.corridors.cgPath, selected: selected.flatMap { map.routes[$0]?.cgPath })
                .frame(width: map.layout.size.width, height: map.layout.size.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            ForEach(map.rooms) { room in
                Button { select(room.id) } label: {
                    VStack(spacing: 4) {
                        if room.id == "you" {
                            Image("WorldBrain").resizable().interpolation(.none).scaledToFit().frame(width: 28, height: 28)
                        } else if room.workID != nil {
                            PixelQuestMark(routine: room.routine)
                        } else {
                            Image(systemName: room.glyph).font(.body.weight(.bold)).foregroundStyle(Ink.brass)
                        }
                        Text(room.title)
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .lineLimit(2).multilineTextAlignment(.center)
                    }
                    .padding(6)
                    .frame(width: 136, height: 72)
                    .foregroundStyle(Ink.words)
                    .background(room.work ? Ink.workCard : Ink.card, in: PixelPanel())
                    .overlay(PixelPanel().stroke(revealed(room, chosen: chosen) ? Ink.brass : Ink.line, lineWidth: 2))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(room.title)
                .accessibilityValue(room.subtitle)
                .accessibilityAddTraits(selected == room.id ? .isSelected : [])
                .accessibilityHint("Reveal the maze route. Tap again to deselect. Use Open for details.")
                .position(room.center)
            }
        }
        .frame(width: map.layout.size.width, height: map.layout.size.height)
        .background(Ink.ground)
    }
}
