import SwiftUI

enum Neuron {
    static func bend(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let mx = (a.x + b.x) / 2
        let my = (a.y + b.y) / 2
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = max(hypot(dx, dy), 1)
        return CGPoint(x: mx - dy / len * 36, y: my + dx / len * 36)
    }
}

struct NeuronSky: View {
    var body: some View {
        RadialGradient(
            colors: [
                Ink.wine.opacity(0.35),
                Ink.ground,
                Ink.ground,
            ],
            center: .center,
            startRadius: 20,
            endRadius: 420
        )
    }
}
