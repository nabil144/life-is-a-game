import SwiftUI
import LifeEngine

enum PathsStyle: String, CaseIterable, Identifiable {
    case atlas, list
    var id: String { rawValue }
    var label: String { self == .atlas ? "Maze" : "List" }
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
    @Binding var editor: MilestoneEditorRequest?
    @State private var savedWorld: WorldLevelState?
    @State private var details: UUID?
    @State private var generating = false
    @State private var builtMaze = false
    @State private var playing = false
    @State private var gameScore = 0
    @State private var mazeSeed = UInt64.random(in: .min ... .max)

    private var mapReady: Bool { builtMaze && map.scene == scene }

    private var parent: LifeEngine.Path? { scene.pathID.flatMap { store.path($0) } }

    var body: some View {
        Group {
            if mapReady {
                WorldScrollView(content: WorldMapContent(map: map, selected: playing ? nil : selected, select: { select($0) }, playing: playing, startGame: {
                    guard scene == .world, map.gameBoard != nil else { return }
                    gameScore = 0; playing = true
                }),
                                size: map.layout.size, camera: camera, animated: !reduceMotion, viewport: viewport,
                                playing: playing, onScore: { gameScore = $0 })
                    .id(scene)
            } else {
                ProgressView("Preparing your maze…")
                    .tint(Ink.brass)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
            .background(Ink.ground)
            .safeAreaInset(edge: .top, spacing: 0) {
                if !playing {
                HStack(spacing: 8) {
                    if scene != .world {
                        Button { returnToWorld() } label: {
                            Label("You", systemImage: "arrow.left")
                        }
                        .accessibilityLabel("Return to your maze")
                    }
                    Group {
                    Button("Overview") { selected = nil; camera = WorldCamera(overview: true) }
                    if scene == .world {
                        Button("You") { selected = nil; focus(map.layout.center) }
                    }
                    Spacer()
                    if let pathID = scene.pathID {
                        Button { editor = MilestoneEditorRequest(pathID: pathID, milestone: nil) } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add milestone")
                    }
                    PixelActionMenu {
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
                    .disabled(map.rooms.count <= 1 || !mapReady)
                    }
                    .disabled(generating || !mapReady)
                }
                .buttonStyle(PixelButtonStyle(compact: true))
                .padding(.horizontal, 12)
                .background(Ink.ground)
                }
            }
            .overlay(alignment: .bottom) {
                if mapReady && !playing { selectionPanel }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let parent {
                    Text(parent.name).font(.caption.monospaced().bold())
                        .frame(maxWidth: .infinity).padding(.vertical, 4).background(Ink.ground)
                }
            }
            .overlay(alignment: .topTrailing) {
                if playing {
                    HStack(spacing: 6) {
                        Text("· \(gameScore)").font(.caption.monospaced()).accessibilityLabel("\(gameScore) dots collected")
                        Button { playing = false } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                            .accessibilityLabel("Exit maze game")
                    }
                    .foregroundStyle(Ink.brass)
                    .padding(.horizontal, 8)
                    .background(Ink.ground.opacity(0.9), in: PixelPanel())
                    .padding(8)
                }
            }
            .navigationTitle("Paths")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $details) { id in
                PathDetailView(pathID: id, capture: $capture)
            }
            .task(id: WorldBuildKey(scene: scene, paths: store.activePaths, playing: playing)) {
                guard !playing else { return }
                let requestedScene = scene
                let seed = mazeSeed
                let paths = store.activePaths
                if let pathID = scene.pathID, !paths.contains(where: { $0.id == pathID }) {
                    returnToWorld(); return
                }
                let inputs = scene.inputs(paths: paths)
                if builtMaze && map.scene == scene && inputs == map.inputs {
                    map = WorldMapSnapshot(paths: paths, scene: scene, previous: map)
                    generating = false
                    return
                }
                generating = true
                let build = Task.detached(priority: .userInitiated) {
                    let layout = WorldLayout(paths: inputs, portrait: true, compactCenter: requestedScene == .world)
                    let maze = WorldMaze(layout: layout, seed: seed, alternatives: true)
                    return (layout, maze, MazeGameBoard(maze: maze))
                }
                let geometry = await withTaskCancellationHandler {
                    await build.value
                } onCancel: { build.cancel() }
                guard !Task.isCancelled, scene == requestedScene else { return }
                let previousCenter = map.layout.center
                map = WorldMapSnapshot(paths: paths, scene: scene, geometry: (geometry.0, geometry.1), gameBoard: geometry.2)
                builtMaze = true
                generating = false
                if let selected, let room = map.rooms.first(where: { $0.id == selected }) {
                    if previousCenter != map.layout.center { focus(room.center) }
                } else if selected != nil {
                    self.selected = nil; camera = WorldCamera()
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
        guard mapReady else { return }
        if id.isEmpty { selected = nil; return }
        if id == "you" && scene == .world { selected = nil; focus(map.layout.center); return }
        guard let room = map.rooms.first(where: { $0.id == id }) else { return }
        if selected == id && !focusDestination { activate(room); return }
        selected = id
        if focusDestination { focus(room.center) }
    }

    private func activate(_ room: WorldRoom) {
        guard editor == nil else { return }
        guard let pathID = room.pathID else { return }
        if let milestoneID = room.milestoneID,
           let milestone = store.path(pathID)?.milestones.first(where: { $0.id == milestoneID }) {
            editor = MilestoneEditorRequest(pathID: pathID, milestone: milestone)
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
                    Text(scene == .world ? "Add a path to grow your maze." : "No milestones on this path yet.")
                    if let pathID = scene.pathID {
                        Button("Add milestone") { editor = MilestoneEditorRequest(pathID: pathID, milestone: nil) }
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
    var playing: Bool
}

private struct WorldLevelState {
    var map: WorldMapSnapshot
    var selected: String?
    var camera: WorldCamera
    var viewport: WorldViewport
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

/// Reference storage survives native renderer recreation within one maze visit.
final class WorldRouteHistory {
    var last: [String: Int] = [:]
}

struct WorldMapSnapshot {
    var history = WorldRouteHistory()
    var scene: WorldScene
    var inputs: [WorldLayout.Input]
    var layout: WorldLayout
    var rooms: [WorldRoom]
    var walls: SwiftUI.Path
    var floorWidth: CGFloat
    var gameBoard: MazeGameBoard?
    var routes: [String: [WorldLightRoute]]
    var floorMask: SwiftUI.Path
    var generation: UUID

    init(paths: [LifeEngine.Path], scene: WorldScene = .world, previous: WorldMapSnapshot? = nil, geometry: (WorldLayout, WorldMaze)? = nil, gameBoard: MazeGameBoard? = nil) {
        self.scene = scene
        inputs = scene.inputs(paths: paths)
        let reusable = previous?.scene == scene && previous?.inputs == inputs
        layout = geometry?.0 ?? (reusable ? previous!.layout : WorldLayout(paths: inputs, portrait: true, compactCenter: scene == .world))
        let maze = reusable ? nil : (geometry?.1 ?? WorldMaze(layout: layout))
        self.gameBoard = reusable ? previous?.gameBoard : gameBoard
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
                                ?? path.map { "\($0.milestones.filter { $0.tickedOn != nil }.count)/\($0.milestones.count) milestones reached" } ?? "Your maze",
                             glyph: path?.glyph ?? "brain", reached: milestone?.tickedOn != nil, work: path?.role == .work)
        }
        if let previous, reusable {
            history = previous.history
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
                    routes[id] = (maze.alternateRoutes[id] ?? [points]).map {
                        WorldLightRoute(WorldRoad(points: $0, source: source, destination: destination))
                    }
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
    var playing = false
    var startGame: () -> Void = {}

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Ink.ground)
                .contentShape(Rectangle())
                .onTapGesture { if !playing { select("") } }
                .accessibilityHidden(true)
            WorldCorridors(walls: map.walls.cgPath, floorMask: map.floorMask.cgPath,
                           floorWidth: map.floorWidth, routes: selected.flatMap { map.routes[$0] } ?? [],
                           generation: map.generation, selection: selected, animated: !reduceMotion && !playing, history: map.history)
                .frame(width: map.layout.size.width, height: map.layout.size.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            ForEach(map.rooms) { room in
                Button { if !playing { select(room.id) } } label: {
                    Group {
                        if room.id == "you" && room.pathID == nil {
                            WorldBrainPulse()
                                .frame(width: room.frame.width, height: room.frame.height)
                        } else {
                            VStack(spacing: 2) {
                                if room.milestoneID != nil {
                                    Image(systemName: room.reached ? "trophy.fill" : "flag.fill")
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
                .opacity(playing ? 0.4 : 1)
                .accessibilityActions {
                    if room.id == "you" && room.pathID == nil {
                        Button("Play maze game") { startGame() }
                    }
                }
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
