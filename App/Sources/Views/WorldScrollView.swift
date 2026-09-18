import SwiftUI
import UIKit

/// UIKit performs panning/zooming without publishing every gesture frame to SwiftUI.
struct WorldScrollView: UIViewControllerRepresentable {
    var content: WorldMapContent
    var size: CGSize
    var camera: WorldCamera
    var animated: Bool

    func makeUIViewController(context: Context) -> WorldScrollController {
        WorldScrollController(content: content)
    }

    func updateUIViewController(_ controller: WorldScrollController, context: Context) {
        controller.update(content: content, size: size, camera: camera, animated: animated)
    }
}

final class WorldScrollController: UIViewController, UIScrollViewDelegate {
    private let scroll = UIScrollView()
    private let host: UIHostingController<WorldMapContent>
    private var worldSize = CGSize.zero
    private var request = WorldCamera()
    private var applied: UUID?
    private var lastViewport = CGSize.zero
    private var animateCamera = false

    init(content: WorldMapContent) {
        host = UIHostingController(rootView: content)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Ink.ground)
        scroll.delegate = self
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.delaysContentTouches = false
        scroll.canCancelContentTouches = true
        scroll.minimumZoomScale = 0.01
        scroll.maximumZoomScale = 2
        view.addSubview(scroll)
        addChild(host)
        scroll.addSubview(host.view)
        host.view.backgroundColor = UIColor(Ink.ground)
        host.didMove(toParent: self)
    }

    func update(content: WorldMapContent, size: CGSize, camera: WorldCamera, animated: Bool) {
        loadViewIfNeeded()
        host.rootView = content
        if size != worldSize {
            // The initial empty snapshot is replaced after loading the stored paths.
            // Refit the overview when its world bounds change.
            if camera.center == nil { applied = nil }
            let oldZoom = scroll.zoomScale
            scroll.setZoomScale(1, animated: false)
            worldSize = size
            host.view.frame = CGRect(origin: .zero, size: size)
            scroll.contentSize = size
            scroll.setZoomScale(oldZoom, animated: false)
        }
        request = camera
        animateCamera = animated
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let resized = lastViewport != view.bounds.size
        let savedCenter = CGPoint(x: (scroll.contentOffset.x + scroll.bounds.width / 2) / scroll.zoomScale,
                                  y: (scroll.contentOffset.y + scroll.bounds.height / 2) / scroll.zoomScale)
        scroll.frame = view.bounds
        guard worldSize.width > 0, worldSize.height > 0, scroll.bounds.width > 0, scroll.bounds.height > 0 else { return }
        let fit = min(scroll.bounds.width / worldSize.width, scroll.bounds.height / worldSize.height)
        scroll.minimumZoomScale = min(1, fit)
        if applied != request.id || (resized && request.center == nil) {
            applied = request.id
            if let center = request.center {
                let zoom: CGFloat = 1
                let rect = CGRect(x: center.x - scroll.bounds.width / (2 * zoom),
                                  y: center.y - scroll.bounds.height / (2 * zoom),
                                  width: scroll.bounds.width / zoom, height: scroll.bounds.height / zoom)
                scroll.zoom(to: rect, animated: animateCamera && !UIAccessibility.isReduceMotionEnabled)
            } else {
                scroll.setZoomScale(min(1, fit), animated: false)
                centerContent()
                scroll.contentOffset = CGPoint(x: -scroll.contentInset.left, y: -scroll.contentInset.top)
            }
        } else if resized {
            scroll.contentOffset = CGPoint(x: savedCenter.x * scroll.zoomScale - scroll.bounds.width / 2,
                                           y: savedCenter.y * scroll.zoomScale - scroll.bounds.height / 2)
        }
        lastViewport = view.bounds.size
        centerContent()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { host.view }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerContent() }

    private func centerContent() {
        let horizontal = max(0, (scroll.bounds.width - worldSize.width * scroll.zoomScale) / 2)
        let vertical = max(0, (scroll.bounds.height - worldSize.height * scroll.zoomScale) / 2)
        scroll.contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
}

/// Vector layers avoid allocating a world-sized Canvas bitmap when the map grows.
struct WorldCorridors: UIViewRepresentable {
    var base: CGPath
    var selected: CGPath?

    func makeUIView(context: Context) -> WorldCorridorLayerView { WorldCorridorLayerView() }
    func updateUIView(_ view: WorldCorridorLayerView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.walls.path = base
        view.floor.path = base
        view.highlight.path = selected
        CATransaction.commit()
    }
}

final class WorldCorridorLayerView: UIView {
    let walls = CAShapeLayer()
    let floor = CAShapeLayer()
    let highlight = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        for (shape, color, width) in [(walls, Ink.line, CGFloat(10)), (floor, Ink.ground, CGFloat(4)), (highlight, Ink.brass, CGFloat(4))] {
            shape.fillColor = nil
            shape.strokeColor = UIColor(color).cgColor
            shape.lineWidth = width
            shape.lineCap = .square
            shape.lineJoin = .miter
            layer.addSublayer(shape)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
