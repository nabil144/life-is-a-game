import SwiftUI
import LifeEngine

/// One path in the middle. Due quests or practices on bent branches, same language as World.
struct DueNeuronView: View {
    @Environment(Store.self) private var store
    let path: Path
    let items: [Objective]
    let confirming: UUID?
    var onAsk: (UUID) -> Void
    var onCancel: () -> Void
    var onDone: (UUID) -> Void
    var onOpenPath: (UUID) -> Void

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let layout = DueNeuronLayout(items: items, in: geo.size)
                ZStack {
                    Canvas { ctx, _ in
                        for sat in layout.sats {
                            var branch = SwiftUI.Path()
                            branch.move(to: layout.center)
                            branch.addQuadCurve(to: sat.at, control: Neuron.bend(from: layout.center, to: sat.at))
                            let on = sat.id == confirming
                            ctx.stroke(
                                branch,
                                with: .color((on ? Ink.brass : Ink.wine).opacity(on ? 0.85 : 0.55)),
                                style: StrokeStyle(lineWidth: on ? 3 : 1.6, lineCap: .round)
                            )
                        }
                    }
                    .allowsHitTesting(false)

                    pathOrb(at: layout.center)
                    ForEach(layout.sats) { sat in
                        pip(sat)
                    }
                }
            }
            .frame(height: fieldHeight)

            if let id = confirming, items.contains(where: { $0.nodeID == id }) {
                confirm(id)
                    .padding(.horizontal, 16)
            }
        }
    }

    private var fieldHeight: CGFloat {
        switch items.count {
        case 0: 0
        case 1...3: 236
        case 4...6: 276
        default: 316
        }
    }

    private func pathOrb(at point: CGPoint) -> some View {
        Button { onOpenPath(path.id) } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Ink.card)
                        .frame(width: 58, height: 58)
                    Circle()
                        .stroke(Ink.brass, lineWidth: 2)
                        .frame(width: 58, height: 58)
                    Image(systemName: path.glyph)
                        .font(.system(size: 20))
                        .foregroundStyle(Ink.words)
                }
                .shadow(color: Ink.brass.opacity(0.35), radius: 10)
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
        .accessibilityLabel(path.name)
    }

    private func pip(_ sat: DueNeuronLayout.Sat) -> some View {
        let node = store.node(sat.objective.nodeID)?.1
        let on = sat.id == confirming
        return Button { onAsk(sat.id) } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Ink.card)
                        .frame(width: on ? 44 : 38, height: on ? 44 : 38)
                    Circle()
                        .stroke(on ? Ink.brass : Ink.line, lineWidth: on ? 2.2 : 1)
                        .frame(width: on ? 44 : 38, height: on ? 44 : 38)
                    Circle()
                        .fill(on ? Ink.brass.opacity(0.35) : Color.clear)
                        .frame(width: 10, height: 10)
                }
                .shadow(color: on ? Ink.brass.opacity(0.4) : .clear, radius: 8)
                Text(node?.title ?? "")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Ink.words)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 86)
            }
        }
        .buttonStyle(.plain)
        .position(sat.at)
        .accessibilityLabel(node?.title ?? "Due")
    }

    private func confirm(_ nodeID: UUID) -> some View {
        let practice = store.node(nodeID)?.1.kind == .practice
        return VStack(alignment: .leading, spacing: 8) {
            Text(practice
                 ? "It leaves Today. It will come back when its cue allows."
                 : "It leaves Today. A quest does not come back.")
                .font(.caption)
                .foregroundStyle(Ink.muted)
            HStack {
                Button("Cancel", action: onCancel)
                    .foregroundStyle(Ink.muted)
                Spacer()
                Button("Done") { onDone(nodeID) }
                    .fontWeight(.semibold)
                    .foregroundStyle(Ink.ground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Ink.brass, in: Capsule())
            }
        }
        .padding(12)
        .background(Ink.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct DueNeuronLayout {
    struct Sat: Identifiable {
        var objective: Objective
        var at: CGPoint
        var id: UUID { objective.nodeID }
    }

    var center: CGPoint
    var sats: [Sat]

    init(items: [Objective], in size: CGSize) {
        let origin = CGPoint(x: size.width / 2, y: size.height / 2 - 6)
        let radius = min(size.width, size.height) * 0.34
        let count = max(items.count, 1)
        sats = items.enumerated().map { i, item in
            let angle = (Double(i) / Double(count)) * .pi * 2 - .pi / 2
            Sat(
                objective: item,
                at: CGPoint(
                    x: origin.x + CGFloat(cos(angle)) * radius,
                    y: origin.y + CGFloat(sin(angle)) * radius
                )
            )
        }
        center = origin
    }
}
