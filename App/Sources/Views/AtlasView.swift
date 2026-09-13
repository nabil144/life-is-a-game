import SwiftUI
import LifeEngine

enum PathsStyle: String, CaseIterable, Identifiable {
    case atlas, list
    var id: String { rawValue }
    var label: String {
        switch self {
        case .atlas: "World"
        case .list: "List"
        }
    }
}

/// You in the middle. Paths as orbs on branches. Quests and practices as twigs.
struct AtlasView: View {
    @Environment(Store.self) private var store
    @Binding var openPath: UUID?
    @State private var pick: AtlasPick?
    @State private var glow: AtlasPick?
    @State private var travel: CGFloat = 0
    @State private var hop = 0
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let layout = AtlasLayout(paths: store.activePaths, in: geo.size)
            ZStack {
                NeuronSky()
                Canvas { ctx, _ in
                    for node in layout.nodes {
                        strokeBranch(
                            &ctx,
                            from: layout.center,
                            to: node.at,
                            fill: pathFill(node.path.id)
                        )
                        for sat in node.neurons {
                            strokeBranch(
                                &ctx,
                                from: node.at,
                                to: sat.at,
                                fill: workFill(sat.work.id),
                                twig: true
                            )
                        }
                    }
                }
                .allowsHitTesting(false)

                ForEach(layout.nodes, id: \.path.id) { node in
                    ForEach(node.neurons) { sat in
                        neuronPip(sat.work, at: sat.at, pathID: node.path.id)
                    }
                    pathOrb(node.path, at: node.at)
                }

                selfOrb
                    .position(layout.center)
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(pan.simultaneously(with: pinch))
            .onTapGesture(count: 2, perform: toggleZoom)
        }
        .background(Ink.ground)
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if store.activePaths.isEmpty {
                    Text("Name one thing you want to evolve.")
                        .font(.subheadline)
                    RestoreFileButton()
                } else {
                    Text(pick == nil
                         ? "Tap a path or a quest. Tap You to clear."
                         : "Tap again to open. Tap You to let go.")
                }
            }
            .font(.footnote)
            .foregroundStyle(Ink.muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private func strokeBranch(_ ctx: inout GraphicsContext, from: CGPoint, to: CGPoint, fill: CGFloat, twig: Bool = false) {
        var line = SwiftUI.Path()
        line.move(to: from)
        line.addQuadCurve(to: to, control: Neuron.bend(from: from, to: to))
        ctx.stroke(
            line,
            with: .color(Ink.wine.opacity(twig ? 0.45 : 0.55)),
            style: StrokeStyle(lineWidth: twig ? 1.3 : 1.6, lineCap: .round)
        )
        let t = min(1, max(0, fill))
        guard t > 0.01 else { return }
        let beam = line.trimmedPath(from: 0, to: t)
        ctx.stroke(beam, with: .color(Ink.brass.opacity(0.28)), style: StrokeStyle(lineWidth: twig ? 10 : 14, lineCap: .round))
        ctx.stroke(beam, with: .color(Ink.brass.opacity(0.9)), style: StrokeStyle(lineWidth: twig ? 2.4 : 3.2, lineCap: .round))
    }

    private func pathFill(_ id: UUID) -> CGFloat {
        switch glow {
        case .path(let p) where p == id: min(1, travel)
        case .work(let p, _) where p == id: min(1, travel)
        default: 0
        }
    }

    private func workFill(_ id: UUID) -> CGFloat {
        if case .work(_, let n) = glow, n == id { return min(1, max(0, travel - 1)) }
        return 0
    }

    private func pathLit(_ id: UUID) -> Bool { pathFill(id) > 0.35 }

    private func workLit(_ id: UUID) -> Bool { workFill(id) > 0.35 }

    private func namesOn(_ pathID: UUID) -> Bool {
        switch pick {
        case .path(let p): p == pathID
        case .work(let p, _): p == pathID
        case nil: false
        }
    }

    private func target(_ pick: AtlasPick?) -> CGFloat {
        switch pick {
        case .path: 1
        case .work: 2
        case nil: 0
        }
    }

    private func select(_ new: AtlasPick?) {
        if pick == new, let new {
            switch new {
            case .path(let id), .work(let id, _): openPath = id
            }
            return
        }
        hop += 1
        let token = hop
        if glow != nil, travel > 0.02 {
            withAnimation(.easeInOut(duration: 0.22)) { travel = 0 }
            pick = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(230))
                guard token == hop else { return }
                glow = new
                pick = new
                if new != nil {
                    withAnimation(.easeInOut(duration: 0.28)) { travel = target(new) }
                }
            }
        } else {
            glow = new
            pick = new
            withAnimation(.easeInOut(duration: 0.28)) { travel = target(new) }
        }
    }

    private func tapPath(_ id: UUID) { select(.path(id)) }

    private func tapWork(pathID: UUID, nodeID: UUID) { select(.work(pathID: pathID, nodeID: nodeID)) }

    private var selfOrb: some View {
        Button {
            select(nil)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Ink.brass.opacity(0.18))
                        .frame(width: 92, height: 92)
                    Circle()
                        .stroke(Ink.brass.opacity(pick == nil ? 0.55 : 0.85), lineWidth: 2)
                        .frame(width: 78, height: 78)
                    Image(systemName: "leaf")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Ink.brass)
                }
                .shadow(color: Ink.brass.opacity(pick == nil ? 0.15 : 0.4), radius: 16)
                Text("You")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Ink.muted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("You, clear the glow")
    }

    private func pathOrb(_ path: Path, at point: CGPoint) -> some View {
        let on = pathLit(path.id)
        return Button { tapPath(path.id) } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(path.isEvolved ? Ink.brass.opacity(0.16) : Ink.card)
                        .frame(width: on ? 68 : 58, height: on ? 68 : 58)
                    Circle()
                        .stroke(on ? Ink.brass : Ink.line, lineWidth: on ? 2.5 : 1)
                        .frame(width: on ? 68 : 58, height: on ? 68 : 58)
                    Image(systemName: path.glyph)
                        .font(.system(size: on ? 24 : 20))
                        .foregroundStyle(path.isEvolved || on ? Ink.brass : Ink.words)
                }
                .shadow(color: on ? Ink.brass.opacity(0.5) : .clear, radius: 14)
                Text(path.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Ink.words)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 96)
            }
        }
        .buttonStyle(.plain)
        .position(point)
        .opacity(path.status == .resting ? 0.55 : 1)
    }

    private func neuronPip(_ work: LifeEngine.Node, at point: CGPoint, pathID: UUID) -> some View {
        let on = workLit(work.id)
        return Button { tapWork(pathID: pathID, nodeID: work.id) } label: {
            VStack(spacing: 3) {
                Circle()
                    .fill(on ? Ink.brass.opacity(0.35) : (work.kind == .practice ? Ink.brass.opacity(0.22) : Ink.card))
                    .overlay(Circle().stroke(on || work.kind == .practice ? Ink.brass : Ink.line, lineWidth: on ? 2 : 1.4))
                    .frame(width: on ? 20 : 16, height: on ? 20 : 16)
                    .shadow(color: on ? Ink.brass.opacity(0.55) : .clear, radius: 8)
                if namesOn(pathID) {
                    Text(work.title)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(on ? Ink.brass : Ink.words)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 72)
                        .transition(.opacity)
                }
            }
        }
        .buttonStyle(.plain)
        .position(point)
        .animation(.easeInOut(duration: 0.18), value: pick)
        .accessibilityLabel(work.title)
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(2.8, max(0.55, lastScale * value.magnification))
            }
            .onEnded { _ in lastScale = scale }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func toggleZoom() {
        withAnimation(.easeInOut(duration: 0.28)) {
            if scale > 1.15 {
                scale = 1
                lastScale = 1
                offset = .zero
                lastOffset = .zero
            } else {
                scale = 1.7
                lastScale = 1.7
            }
        }
    }
}

private enum AtlasPick: Equatable {
    case path(UUID)
    case work(pathID: UUID, nodeID: UUID)
}

private struct AtlasLayout {
    struct NeuronSat: Identifiable {
        var work: LifeEngine.Node
        var at: CGPoint
        var id: UUID { work.id }
    }

    struct Node {
        var path: Path
        var at: CGPoint
        var neurons: [NeuronSat]
    }

    var center: CGPoint
    var nodes: [Node]

    init(paths: [Path], in size: CGSize) {
        let origin = CGPoint(x: size.width / 2, y: size.height / 2 - 12)
        let radius = min(size.width, size.height) * 0.34
        let count = max(paths.count, 1)
        let laid = paths.enumerated().map { i, item in
            let angle = (Double(i) / Double(count)) * .pi * 2 - .pi / 2
            let at = CGPoint(
                x: origin.x + CGFloat(cos(angle)) * radius,
                y: origin.y + CGFloat(sin(angle)) * radius
            )
            let open = item.nodes.filter(\.isOpen)
            let outward = atan2(at.y - origin.y, at.x - origin.x)
            let fan = Double.pi * 1.15
            let twigOrbit: CGFloat = 62
            let neurons = open.enumerated().map { j, n -> NeuronSat in
                let t = open.count == 1 ? 0 : (Double(j) / Double(open.count - 1)) - 0.5
                let a = outward + t * fan
                return NeuronSat(
                    work: n,
                    at: CGPoint(
                        x: at.x + CGFloat(cos(a)) * twigOrbit,
                        y: at.y + CGFloat(sin(a)) * twigOrbit
                    )
                )
            }
            return Node(path: item, at: at, neurons: neurons)
        }
        center = origin
        nodes = laid
    }
}
