import SwiftUI
import UIKit
import LifeEngine

/// A small native game layer over the existing maze, with no persisted game state.
final class MazeGameLayerView: UIView {
    private var game: MazeGame
    private let pac = CAShapeLayer()
    private var chunks: [Int: [Int]] = [:]
    private var dotLayers: [Int: CAShapeLayer] = [:]
    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval?
    var onPosition: ((CGPoint) -> Void)?
    var onScore: ((Int) -> Void)?
    var paused = false { didSet { updatePause() } }

    init(board: MazeGameBoard) {
        game = MazeGame(board: board)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        for cell in board.neighbors.keys { chunks[chunk(for: cell), default: []].append(cell) }
        for key in chunks.keys {
            let dots = CAShapeLayer()
            dots.fillColor = UIColor(Ink.brass).withAlphaComponent(0.65).cgColor
            layer.addSublayer(dots); dotLayers[key] = dots
            redraw(key)
        }
        pac.fillColor = UIColor(Ink.brass).cgColor
        layer.addSublayer(pac)
        pac.position = board.doorway
        NotificationCenter.default.addObserver(self, selector: #selector(updatePause), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updatePause), name: UIApplication.willResignActiveNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { link?.invalidate(); link = nil; lastTime = nil }
        else if link == nil {
            let proxy = MazeGameClock(); proxy.view = self
            let display = CADisplayLink(target: proxy, selector: #selector(MazeGameClock.tick(_:)))
            display.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            display.add(to: .main, forMode: .common)
            link = display
            updatePause()
        }
    }

    @objc private func updatePause() {
        link?.isPaused = paused || UIApplication.shared.applicationState != .active
        lastTime = nil
    }
    func steer(_ direction: MazeGameBoard.Direction) { game.steer(direction) }

    fileprivate func tick(_ display: CADisplayLink) {
        guard !paused, UIApplication.shared.applicationState == .active else { lastTime = nil; return }
        let dt = lastTime.map { display.timestamp - $0 } ?? 0
        lastTime = display.timestamp
        let eaten = game.advance(seconds: dt)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for key in Set(eaten.map { chunk(for: $0) }) { redraw(key) }
        pac.position = game.position
        pac.setAffineTransform(CGAffineTransform(rotationAngle: game.direction.angle))
        let opening: CGFloat = UIAccessibility.isReduceMotionEnabled ? 0.2 : 0.1 + 0.65 * CGFloat((sin(display.timestamp * 18)+1)/2)
        let mouth = CGMutablePath()
        mouth.move(to: .zero)
        mouth.addArc(center: .zero, radius: 5, startAngle: opening, endAngle: 2 * .pi-opening, clockwise: false)
        mouth.closeSubpath(); pac.path = mouth
        CATransaction.commit()
        onPosition?(game.position)
        if !eaten.isEmpty { onScore?(game.score) }
    }
    private func chunk(for cell: Int) -> Int {
        (cell / game.board.columns / 16) * ((game.board.columns+15)/16) + cell % game.board.columns / 16
    }
    private func redraw(_ key: Int) {
        let path = CGMutablePath()
        for cell in chunks[key] ?? [] where game.remaining.contains(cell) {
            let point = game.board.center(cell)
            let radius: CGFloat = cell.isMultiple(of: 5) ? 2 : 1.3
            path.addEllipse(in: CGRect(x: point.x-radius, y: point.y-radius, width: radius*2, height: radius*2))
        }
        dotLayers[key]?.path = path
    }
}

@MainActor private final class MazeGameClock: NSObject {
    weak var view: MazeGameLayerView?
    @objc func tick(_ display: CADisplayLink) { view?.tick(display) }
}
