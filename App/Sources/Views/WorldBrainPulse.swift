import SwiftUI
import UIKit

/// Animate only the small brain overlay; never redraw or relayout the maze per beat.
struct WorldBrainPulse: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var brain: some View {
        Image("WorldBrain")
            .resizable()
            .interpolation(.none)
            .scaledToFit()
    }

    var body: some View {
        brain
            .overlay {
                BrainPulseSurface(animated: !reduceMotion && scenePhase == .active)
                    // Luminance confines the highlight to the bright maze pattern,
                    // instead of illuminating the image's dark square background.
                    .mask { brain.luminanceToAlpha() }
                    .blendMode(.screen)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}

private struct BrainPulseSurface: UIViewRepresentable {
    let animated: Bool

    func makeUIView(context: Context) -> BrainPulseLayerView {
        BrainPulseLayerView()
    }

    func updateUIView(_ view: BrainPulseLayerView, context: Context) {
        view.setAnimated(animated)
    }

    static func dismantleUIView(_ view: BrainPulseLayerView, coordinator: ()) {
        view.setAnimated(false)
    }
}

private final class BrainPulseLayerView: UIView {
    private let waves = [CAGradientLayer(), CAGradientLayer()]
    private var enabled = false
    private let duration = 2.6

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        for wave in waves {
            wave.type = .radial
            wave.startPoint = CGPoint(x: 0.5, y: 0.5)
            wave.endPoint = CGPoint(x: 1, y: 1)
            wave.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor,
                           UIColor(red: 1, green: 0.91, blue: 0.66, alpha: 1).cgColor,
                           UIColor.clear.cgColor, UIColor.clear.cgColor]
            wave.locations = [0, 0, 0, 0.12, 1]
            wave.opacity = 0
            layer.addSublayer(wave)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Match the square asset's aspect-fit bounds, leaving the room unchanged.
        let side = min(bounds.width, bounds.height)
        let imageFrame = CGRect(x: (bounds.width-side)/2, y: (bounds.height-side)/2, width: side, height: side)
        for wave in waves { wave.frame = imageFrame }
        CATransaction.commit()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateAnimation()
    }

    func setAnimated(_ value: Bool) {
        enabled = value
        updateAnimation()
    }

    private func updateAnimation() {
        guard enabled, window != nil else {
            for wave in waves { wave.removeAllAnimations() }
            return
        }
        guard waves[0].animation(forKey: "heartbeat") == nil else { return }
        let start = CACurrentMediaTime()
        for (index, wave) in waves.enumerated() {
            let travel = CAKeyframeAnimation(keyPath: "locations")
            travel.values = [[0, 0, 0, 0.12, 1], [0, 0.78, 0.90, 1, 1], [0, 0.78, 0.90, 1, 1]]
            travel.keyTimes = [0, 0.62, 1]
            travel.duration = duration
            let glow = CAKeyframeAnimation(keyPath: "opacity")
            glow.values = [0, index == 0 ? 0.85 : 0.4, 0.5, 0, 0]
            glow.keyTimes = [0, 0.08, 0.36, 0.62, 1]
            glow.duration = duration
            let beat = CAAnimationGroup()
            beat.animations = [travel, glow]
            beat.duration = duration
            beat.beginTime = start + Double(index) * 0.28
            beat.repeatCount = .infinity
            beat.fillMode = .backwards
            wave.add(beat, forKey: "heartbeat")
        }
    }
}
