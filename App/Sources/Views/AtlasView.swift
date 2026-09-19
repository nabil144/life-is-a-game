import SwiftUI
import LifeEngine

enum PathsStyle: String, CaseIterable, Identifiable {
    case atlas, list
    var id: String { rawValue }
    var label: String { self == .atlas ? "World" : "List" }
}

/// The World and its current path share one screen; returning restores the World viewport.
/// Opening a path never builds or displays another path's children.
struct AtlasView: View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var capture: CaptureRequest?
    @State private var scene: WorldScene = .world
    @State private var map = WorldMapSnapshot(paths: [])
    @State private var selected: String?
    @State private var camera = WorldCamera()
    @State private var viewport = WorldViewport()
    @State private var editor: WorldMilestoneEditor?
    @State private var savedWorld: WorldLevelState?
    @State private var details: UUID?
    @State private var generating = false

    private var parent: LifeEngine.Path? { scene.pathID.flatMap { store.path($0) } }

    var body: some View {
        Group {
            if map.scene == scene {
                WorldScrollView(content: WorldMapContent(map: map, selected: selected, select: { select($0) }),
                                size: map.layout.size, camera: camera, animated: !reduceMotion, viewport: viewport)
                    .id(scene)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
            .background(Ink.ground)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 8) {
                    if scene != .world {
                        Button { returnToWorld() } label: {
                            Label("You", systemImage: "arrow.left")
                        }
                        .accessibilityLabel("Return to your world")
                    }
                    Group {
                    Button("Overview") { selected = nil; camera = WorldCamera(overview: true) }
                    if scene == .world {
                        Button("You") { selected = nil; focus(map.layout.center) }
                    }
                    Spacer()
                    if let pathID = scene.pathID {
                        Button { editor = WorldMilestoneEditor(pathID: pathID, milestone: nil) } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add milestone")
                    }
                    Menu {
                        ForEach(map.rooms.filter { $0.id != "you" }) { room in
                            Button(room.title) { select(room.id, focusDestination: true) }
                        }
                    } label: {
                        if scene == .world {
                            Label("Paths", systemImage: "point.3.connected.trianglepath.dotted")
                        } else {
                            Image(systemName: "flag.fill").accessibilityLabel("Milestones")
                        }
                    }
                    .disabled(map.rooms.count <= 1 || map.scene != scene)
                    }
                    .disabled(generating || map.scene != scene)
                }
                .buttonStyle(PixelButtonStyle(compact: true))
                .padding(.horizontal, 12)
                .background(Ink.ground)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { selectionPanel }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let parent {
                    Text(parent.name).font(.caption.monospaced().bold())
                        .frame(maxWidth: .infinity).padding(.vertical, 4).background(Ink.ground)
                }
            }
            .navigationTitle("Paths")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $details) { id in
                PathDetailView(pathID: id, capture: $capture)
            }
            .task(id: WorldBuildKey(scene: scene, paths: store.activePaths)) {
                let requestedScene = scene
                let paths = store.activePaths
                if let pathID = scene.pathID, !paths.contains(where: { $0.id == pathID }) {
                    returnToWorld(); return
                }
                let inputs = scene.inputs(paths: paths)
                if map.scene == scene && inputs == map.inputs {
                    map = WorldMapSnapshot(paths: paths, scene: scene, previous: map)
                    generating = false
                    return
                }
                generating = true
                let build = Task.detached(priority: .userInitiated) {
                    let layout = WorldLayout(paths: inputs, portrait: true, compactCenter: requestedScene == .world)
                    return (layout, WorldMaze(layout: layout))
                }
                let geometry = await withTaskCancellationHandler {
                    await build.value
                } onCancel: { build.cancel() }
                guard !Task.isCancelled, scene == requestedScene else { return }
                let previousCenter = map.layout.center
                map = WorldMapSnapshot(paths: paths, scene: scene, geometry: geometry)
                generating = false
                if let selected, let room = map.rooms.first(where: { $0.id == selected }) {
                    if previousCenter != map.layout.center { focus(room.center) }
                } else if selected != nil {
                    self.selected = nil; camera = WorldCamera()
                }
            }
            .sheet(item: $editor) { item in
                if let milestone = item.milestone, milestone.tickedOn != nil {
                    MilestoneFactView(pathID: item.pathID, milestone: milestone)
                } else {
                    WorldMilestoneForm(pathID: item.pathID, milestone: item.milestone)
                }
            }
    }

    private func enter(_ pathID: UUID) {
        savedWorld = WorldLevelState(map: map, selected: selected, camera: camera, viewport: viewport)
        selected = nil
        camera = WorldCamera()
        viewport = WorldViewport()
        scene = .path(pathID)
    }

    private func returnToWorld() {
        guard scene != .world else { return }
        if let savedWorld {
            map = savedWorld.map
            selected = savedWorld.selected
            camera = savedWorld.camera
            viewport = savedWorld.viewport
        } else {
            selected = nil
            camera = WorldCamera()
            viewport = WorldViewport()
        }
        savedWorld = nil
        scene = .world
    }

    private func focus(_ point: CGPoint) { camera = WorldCamera(center: point) }

    private func select(_ id: String, focusDestination: Bool = false) {
        guard map.scene == scene else { return }
        if id.isEmpty { selected = nil; return }
        if id == "you" && scene == .world { selected = nil; focus(map.layout.center); return }
        guard let room = map.rooms.first(where: { $0.id == id }) else { return }
        if selected == id && !focusDestination { activate(room); return }
        selected = id
        if focusDestination { focus(room.center) }
    }

    private func activate(_ room: WorldRoom) {
        guard let pathID = room.pathID else { return }
        if let milestoneID = room.milestoneID,
           let milestone = store.path(pathID)?.milestones.first(where: { $0.id == milestoneID }) {
            editor = WorldMilestoneEditor(pathID: pathID, milestone: milestone)
        } else if scene == .world { enter(pathID) }
        else { details = pathID }
    }

    @ViewBuilder private var selectionPanel: some View {
        if let selected, let room = map.rooms.first(where: { $0.id == selected }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(room.title).font(.headline)
                    Text(room.subtitle).font(.caption).foregroundStyle(Ink.muted)
                }
                Spacer()
                if scene == .world, let pathID = room.pathID {
                    Button("Details") { details = pathID }
                        .buttonStyle(PixelButtonStyle(compact: true))
                }
                Button(scene == .world ? "Enter" : "Open") { activate(room) }
                    .buttonStyle(PixelButtonStyle(selected: true, compact: true))
                Button { self.selected = nil } label: { Image(systemName: "xmark").frame(width: 44,height: 44) }
                    .accessibilityLabel("Deselect")
            }
            .padding(12).background(Ink.card, in: PixelPanel()).padding(8)
        } else {
            VStack(spacing: 4) {
                if generating || map.scene != scene { Text("Growing your maze…") }
                else if map.rooms.count <= 1 {
                    Text(scene == .world ? "Add a path to grow your world." : "No milestones on this path yet.")
                    if let pathID = scene.pathID {
                        Button("Add milestone") { editor = WorldMilestoneEditor(pathID: pathID, milestone: nil) }
                            .buttonStyle(PixelButtonStyle(compact: true))
                    } else { RestoreFileButton() }
                } else {
                    Text(scene == .world ? "Tap to select · tap again to enter" : "Tap to select · tap again to edit")
                }
            }
            .font(.caption).foregroundStyle(Ink.muted)
            .padding(8).frame(maxWidth: .infinity).background(Ink.ground)
        }
    }
}

private struct WorldBuildKey: Hashable {
    var scene: WorldScene
    var paths: [LifeEngine.Path]
}

private struct WorldLevelState {
    var map: WorldMapSnapshot
    var selected: String?
    var camera: WorldCamera
    var viewport: WorldViewport
}

private struct WorldMilestoneEditor: Identifiable {
    var pathID: UUID
    var milestone: Milestone?
    let id = UUID()
}

struct WorldCamera {
    var id = UUID()
    var center: CGPoint? = nil
    var overview = false
}

struct WorldRoom: Identifiable {
    var id: String
    var pathID: UUID?
    var milestoneID: UUID?
    var center: CGPoint
    var frame: CGRect
    var title: String
    var subtitle: String
    var glyph: String
    var reached: Bool
    var work: Bool
}

struct WorldLightRoute {
    var road: WorldRoad
    var path: CGPath

    init(_ road: WorldRoad) {
        self.road = road
        var path = SwiftUI.Path()
        path.addLines(road.points)
        self.path = path.cgPath
    }
}

struct WorldMapSnapshot {
    var scene: WorldScene
    var inputs: [WorldLayout.Input]
    var layout: WorldLayout
    var rooms: [WorldRoom]
    var walls: SwiftUI.Path
    var floorWidth: CGFloat
    var routes: [String: WorldLightRoute]
    var floorMask: SwiftUI.Path
    var generation: UUID

    init(paths: [LifeEngine.Path], scene: WorldScene = .world, previous: WorldMapSnapshot? = nil, geometry: (WorldLayout, WorldMaze)? = nil) {
        self.scene = scene
        inputs = scene.inputs(paths: paths)
        let reusable = previous?.scene == scene && previous?.inputs == inputs
        layout = geometry?.0 ?? (reusable ? previous!.layout : WorldLayout(paths: inputs, portrait: true, compactCenter: scene == .world))
        let maze = reusable ? nil : (geometry?.1 ?? WorldMaze(layout: layout))
        if let maze {
            layout.size = maze.size
            for index in layout.rooms.indices {
                if let frame = maze.roomFrames[layout.rooms[index].id] {
                    layout.rooms[index].center = CGPoint(x: frame.midX,y: frame.midY)
                }
            }
            layout.center = layout.rooms.first(where: { $0.id == "you" })?.center ?? layout.center
        }
        let previousFrames = Dictionary(uniqueKeysWithValues: (previous?.rooms ?? []).map { ($0.id,$0.frame) })
        let pathIndex = Dictionary(uniqueKeysWithValues: paths.map { ($0.id, $0) })
        let milestones = scene.pathID.flatMap { pathIndex[$0]?.milestones } ?? []
        let milestoneIndex = Dictionary(uniqueKeysWithValues: milestones.map { ($0.id, $0) })
        rooms = layout.rooms.map { room in
            let path = (scene.pathID ?? room.pathID).flatMap { pathIndex[$0] }
            let milestone = scene.pathID == nil ? nil : room.pathID.flatMap { milestoneIndex[$0] }
            return WorldRoom(id: room.id, pathID: path?.id, milestoneID: milestone?.id, center: room.center,
                             frame: maze?.roomFrames[room.id] ?? previousFrames[room.id] ?? room.frame,
                             title: milestone?.text ?? path?.name ?? "You",
                             subtitle: milestone.map { $0.tickedOn.map { "Reached on \($0.description)" } ?? "Milestone · not reached yet" }
                                ?? path.map { "\($0.milestones.filter { $0.tickedOn != nil }.count)/\($0.milestones.count) milestones reached" } ?? "Your world",
                             glyph: path?.glyph ?? "brain", reached: milestone?.tickedOn != nil, work: path?.role == .work)
        }
        if let previous, reusable {
            walls = previous.walls; floorWidth = previous.floorWidth; routes = previous.routes
            floorMask = previous.floorMask; generation = previous.generation
        } else {
            walls = SwiftUI.Path(); routes = [:]
            let maze = maze!
            floorWidth = maze.cellSize - 4
            generation = UUID()
            floorMask = SwiftUI.Path(CGRect(origin: .zero, size: layout.size))
            for room in rooms { floorMask.addRect(room.frame) }
            for segment in maze.walls {
                walls.move(to: segment.from)
                walls.addLine(to: segment.to)
            }
            if let source = maze.roomFrames["you"] {
                for (id, points) in maze.routes where id != "you" {
                    guard let destination = maze.roomFrames[id] else { continue }
                    routes[id] = WorldLightRoute(WorldRoad(points: points, source: source, destination: destination))
                }
            }
        }
    }
}

struct WorldMapContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let map: WorldMapSnapshot
    let selected: String?
    let select: (String) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Ink.ground)
                .contentShape(Rectangle())
                .onTapGesture { select("") }
                .accessibilityHidden(true)
            WorldCorridors(walls: map.walls.cgPath, floorMask: map.floorMask.cgPath,
                           floorWidth: map.floorWidth, route: selected.flatMap { map.routes[$0] },
                           generation: map.generation, selection: selected, animated: !reduceMotion)
                .frame(width: map.layout.size.width, height: map.layout.size.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            ForEach(map.rooms) { room in
                Button { select(room.id) } label: {
                    Group {
                        if room.id == "you" && room.pathID == nil {
                            Image("WorldBrain")
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: room.frame.width - 16, height: room.frame.height - 12)
                        } else {
                            VStack(spacing: 2) {
                                if room.milestoneID != nil {
                                    Image(systemName: room.reached ? "checkmark.square.fill" : "flag.fill")
                                        .font(.body.weight(.bold)).foregroundStyle(Ink.brass)
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: room.glyph).font(.body.weight(.bold)).foregroundStyle(Ink.brass)
                                        .frame(width: 20, height: 20)
                                }
                                Text(room.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2).multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                    .frame(width: room.frame.width - 16, height: room.frame.height - 12)
                    .scaleEffect(selected == room.id ? 1.06 : 1)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: selected == room.id)
                    .frame(width: room.frame.width - 8, height: room.frame.height - 8)
                    .foregroundStyle(Ink.words)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(room.title)
                .accessibilityValue(room.subtitle)
                .accessibilityAddTraits(selected == room.id ? .isSelected : [])
                .accessibilityHint(room.id == "you" && room.pathID == nil ? "Center on You." : (map.scene == .world ? "Select and enlarge. Tap again to enter this path's maze." : "Select and enlarge. Tap again to open details."))
                .position(room.center)
            }
        }
        .frame(width: map.layout.size.width, height: map.layout.size.height)
        .background(Ink.ground)
    }
}
