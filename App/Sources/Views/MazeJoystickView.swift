import SwiftUI
import UIKit
import LifeEngine

final class MazeJoystickView: UIView {
    var onInput: ((MazeJoystick) -> Void)?
    private let base = UIView()
    private let knob = UIView()
    private var activeTouch: UITouch?
    private var origin = CGPoint.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        base.bounds = CGRect(x: 0, y: 0, width: 112, height: 112)
        base.layer.cornerRadius = 56
        base.backgroundColor = UIColor(Ink.ground).withAlphaComponent(0.75)
        base.layer.borderColor = UIColor(Ink.brass).withAlphaComponent(0.55).cgColor
        base.layer.borderWidth = 1
        base.isUserInteractionEnabled = false
        knob.bounds = CGRect(x: 0, y: 0, width: 32, height: 32)
        knob.layer.cornerRadius = 16
        knob.backgroundColor = UIColor(Ink.brass).withAlphaComponent(0.8)
        knob.isUserInteractionEnabled = false
        addSubview(base)
        addSubview(knob)
        base.isHidden = true
        knob.isHidden = true
        NotificationCenter.default.addObserver(self, selector: #selector(reset),
            name: UIApplication.willResignActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch
        origin = touch.location(in: self)
        base.center = CGPoint(x: min(max(56, origin.x), max(56, bounds.width - 56)),
                              y: min(max(56, origin.y), max(56, bounds.height - 56)))
        knob.center = base.center
        base.isHidden = false
        knob.isHidden = false
        onInput?(MazeJoystick(displacement: .zero))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        let point = touch.location(in: self)
        let input = MazeJoystick(displacement: CGPoint(x: point.x - origin.x, y: point.y - origin.y))
        knob.center = CGPoint(x: base.center.x + input.offset.x, y: base.center.y + input.offset.y)
        onInput?(input)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let activeTouch, touches.contains(activeTouch) { reset() }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { reset() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { reset() }
    }

    @objc func reset() {
        activeTouch = nil
        base.isHidden = true
        knob.isHidden = true
        onInput?(MazeJoystick(displacement: .zero))
    }
}
