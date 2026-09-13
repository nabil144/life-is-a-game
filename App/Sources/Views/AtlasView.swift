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

/// You in the middle. Paths as orbs on branches. Pinch closer and milestones appear around each path.
struct AtlasView: View {
    @Environment(Store.self) private var store
    @Binding var openPath: UUID?
    @State private var pick: AtlasPick?
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
                        let pathOn = pathLit(node.path.id)
                        strokeBranch(
                            &ctx,
                            from: layout.center,
                            to: node.at,
                            lit: pathOn
                        )
                        for sat in node.neurons {
                            strokeBranch(
                                &ctx,
                                from: node.at,
                                to: sat.at,
                                lit: workLit(sat.work.id),
                                twig: true
                            )
                        }
                        if scale > 1.25 {
                            for sat in node.milestones {
                                strokeBranch(
                                    &ctx,
                                    from: node.at,
                                    to: sat.at,
                                    lit: false,
                                    twig: true
                                )
                            }
                        }
                    }
                }
                .allowsHitTesting(false)

                ForEach(layout.nodes, id: \.path.id) { node in
                    ForEach(node.neurons) { sat in
                        neuronPip(sat.work, at: sat.at, pathID: node.path.id)
                    }
                    pathOrb(node.path, at: node.at)
                    if scale > 1.25 {
                        ForEach(node.milestones) { sat in
                            milestonePip(sat.milestone, at: sat.at, pathID: node.path.id)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
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

    private func strokeBranch(_ ctx: inout GraphicsContext, from: CGPoint, to: CGPoint, lit: Bool, twig: Bool = false) {
        var line = SwiftUI.Path()
        line.move(to: from)
        line.addQuadCurve(to: to, control: Neuron.bend(from: from, to: to))
        if lit {
            ctx.stroke(line, with: .color(Ink.brass.opacity(0.28)), style: StrokeStyle(lineWidth: twig ? 10 : 14, lineCap: .round))
            ctx.stroke(line, with: .color(Ink.brass.opacity(0.9)), style: StrokeStyle(lineWidth: twig ? 2.4 : 3.2, lineCap: .round))
        } else {
            ctx.stroke(
                line,
                with: .color(Ink.wine.opacity(twig ? 0.45 : 0.55)),
                style: StrokeStyle(lineWidth: twig ? 1.3 : 1.6, lineCap: .round)
            )
        }
    }

    private func pathLit(_ id: UUID) -> Bool {
        switch pick {
        case .path(let p): p == id
        case .work(let p, _): p == id
        case nil: false
        }
    }

    private func workLit(_ id: UUID) -> Bool {
        if case .work(_, let n) = pick { return n == id }
        return false
    }

    private func tapPath(_ id: UUID) {
        if pick == .path(id) {
            openPath = id
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { pick = .path(id) }
        }
    }

    private func tapWork(pathID: UUID, nodeID: UUID) {
        if pick == .work(pathID: pathID, nodeID: nodeID) {
            openPath = pathID
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { pick = .work(pathID: pathID, nodeID: nodeID) }
        }
    }

    private var selfOrb: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { pick = nil }
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
                Text(work.title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(on ? Ink.brass : Ink.words)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 72)
            }
        }
        .buttonStyle(.plain)
        .position(point)
        .accessibilityLabel(work.title)
    }

    private func milestonePip(_ milestone: Milestone, at point: CGPoint, pathID: UUID) -> some View {
        NavigationLink(value: pathID) {
            Circle()
                .fill(milestone.tickedOn == nil ? Color.clear : Ink.brass)
                .stroke(milestone.tickedOn == nil ? Ink.muted : Ink.brass, lineWidth: 1.5)
                .frame(width: 13, height: 13)
                .shadow(color: milestone.tickedOn == nil ? .clear : Ink.brass.opacity(0.5), radius: 4)
        }
        .buttonStyle(.plain)
        .position(point)
        .accessibilityLabel(milestone.text)
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
    struct Sat: Identifiable {
        var milestone: Milestone
        var at: CGPoint
        var id: UUID { milestone.id }
    }

    struct NeuronSat: Identifiable {
        var work: LifeEngine.Node
        var at: CGPoint
        var id: UUID { work.id }
    }

    struct Node {
        var path: Path
        var at: CGPoint
        var milestones: [Sat]
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
            let orbit: CGFloat = 46
            let sats = item.milestones.enumerated().map { j, m in
                let a = (Double(j) / Double(max(item.milestones.count, 1))) * .pi * 2 - .pi / 2
                return Sat(
                    milestone: m,
                    at: CGPoint(x: at.x + CGFloat(cos(a)) * orbit, y: at.y + CGFloat(sin(a)) * orbit)
                )
            }
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
            return Node(path: item, at: at, milestones: sats, neurons: neurons)
        }
        center = origin
        nodes = laid
    }
}
