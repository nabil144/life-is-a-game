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
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let layout = AtlasLayout(paths: store.activePaths, in: geo.size)
            let today = store.todaysObjective()?.pathID
            ZStack {
                AtlasSky()
                Canvas { ctx, _ in
                    for node in layout.nodes {
                        var branch = SwiftUI.Path()
                        branch.move(to: layout.center)
                        branch.addQuadCurve(to: node.at, control: AtlasLayout.bend(from: layout.center, to: node.at))
                        let todayBranch = node.path.id == today
                        ctx.stroke(
                            branch,
                            with: .color(Color.accentColor.opacity(todayBranch ? 0.7 : 0.28)),
                            style: StrokeStyle(lineWidth: todayBranch ? 3 : 1.6, lineCap: .round)
                        )
                    }
                }
                .allowsHitTesting(false)

                selfOrb
                    .position(layout.center)

                ForEach(layout.nodes, id: \.path.id) { node in
                    pathOrb(node.path, at: node.at, today: node.path.id == today)
                    if scale > 1.25 {
                        ForEach(node.milestones) { sat in
                            milestonePip(sat.milestone, at: sat.at, pathID: node.path.id)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(pan.simultaneously(with: pinch))
            .onTapGesture(count: 2, perform: toggleZoom)
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if store.activePaths.isEmpty {
                    Text("Name one thing you want to evolve.")
                        .font(.subheadline)
                    RestoreFileButton()
                } else {
                    Text(scale > 1.25
                         ? "The smaller rings are milestones. Tap a path to open it."
                         : "Pinch closer. Drag to wander.")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private var selfOrb: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: 92, height: 92)
                Circle()
                    .stroke(Color.accentColor.opacity(0.85), lineWidth: 2)
                    .frame(width: 78, height: 78)
                Image(systemName: "leaf")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.pulse, options: .repeating, isActive: true)
            }
            .shadow(color: Color.accentColor.opacity(0.35), radius: 16)
            Text("You")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func pathOrb(_ path: Path, at point: CGPoint, today: Bool) -> some View {
        NavigationLink(value: path.id) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(path.isEvolved ? Color.green.opacity(0.16) : Color(.secondarySystemGroupedBackground))
                        .frame(width: today ? 68 : 58, height: today ? 68 : 58)
                    Circle()
                        .stroke(today ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: today ? 2.5 : 1)
                        .frame(width: today ? 68 : 58, height: today ? 68 : 58)
                    Image(systemName: path.glyph)
                        .font(.system(size: today ? 24 : 20))
                        .foregroundStyle(path.isEvolved ? Color.green : Color.primary)
                }
                .shadow(color: today ? Color.accentColor.opacity(0.45) : .clear, radius: 12)
                Text(path.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 96)
            }
        }
        .buttonStyle(.plain)
        .position(point)
        .opacity(path.status == .resting ? 0.55 : 1)
    }

    private func milestonePip(_ milestone: Milestone, at point: CGPoint, pathID: UUID) -> some View {
        NavigationLink(value: pathID) {
            Circle()
                .fill(milestone.tickedOn == nil ? Color.clear : Color.green)
                .stroke(milestone.tickedOn == nil ? Color.secondary.opacity(0.7) : Color.green, lineWidth: 1.5)
                .frame(width: 13, height: 13)
                .shadow(color: milestone.tickedOn == nil ? .clear : Color.green.opacity(0.5), radius: 4)
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

private struct AtlasSky: View {
    var body: some View {
        RadialGradient(
            colors: [
                Color.accentColor.opacity(0.14),
                Color(.systemBackground),
                Color(.systemBackground),
            ],
            center: .center,
            startRadius: 20,
            endRadius: 420
        )
    }
}

private struct AtlasLayout {
    struct Sat: Identifiable {
        var milestone: Milestone
        var at: CGPoint
        var id: UUID { milestone.id }
    }

    struct Node {
        var path: Path
        var at: CGPoint
        var milestones: [Sat]
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
            return Node(path: item, at: at, milestones: sats)
        }
        center = origin
        nodes = laid
    }

    static func bend(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let mx = (a.x + b.x) / 2
        let my = (a.y + b.y) / 2
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = max(hypot(dx, dy), 1)
        return CGPoint(x: mx - dy / len * 36, y: my + dx / len * 36)
    }
}
