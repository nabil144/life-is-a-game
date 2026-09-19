import SwiftUI
import UIKit

/// Plain reference storage: scroll gestures never publish SwiftUI updates.
@MainActor
final class WorldViewport {
    var center: CGPoint?
    var zoom: CGFloat = 1
    var generation: UUID?
    var cameraID: UUID?
}

/// UIKit performs panning/zooming without publishing every gesture frame to SwiftUI.
struct WorldScrollView: UIViewControllerRepresentable {
    var content: WorldMapContent
    var size: CGSize
    var camera: WorldCamera
    var animated: Bool
    var viewport: WorldViewport

    func makeUIViewController(context: Context) -> WorldScrollController {
        WorldScrollController(content: content, viewport: viewport)
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
    private let viewport: WorldViewport
    private var generation: UUID?
    private var updating = false

    init(content: WorldMapContent, viewport: WorldViewport) {
        self.viewport = viewport
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
        host.safeAreaRegions = []
        scroll.addSubview(host.view)
        host.view.backgroundColor = UIColor(Ink.ground)
        host.didMove(toParent: self)
    }

    func update(content: WorldMapContent, size: CGSize, camera: WorldCamera, animated: Bool) {
        loadViewIfNeeded()
        updating = true
        defer { updating = false }
        generation = content.map.generation
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
        updating = true
        defer { updating = false; rememberViewport() }
        let resized = lastViewport != view.bounds.size
        let savedCenter = CGPoint(x: (scroll.contentOffset.x + scroll.bounds.width / 2) / scroll.zoomScale,
                                  y: (scroll.contentOffset.y + scroll.bounds.height / 2) / scroll.zoomScale)
        scroll.frame = view.bounds
        guard worldSize.width > 0, worldSize.height > 0, scroll.bounds.width > 0, scroll.bounds.height > 0 else { return }
        let fit = min(scroll.bounds.width / worldSize.width, scroll.bounds.height / worldSize.height)
        scroll.minimumZoomScale = min(1, fit)
        if applied != request.id {
            let restore = applied == nil && viewport.generation == generation && viewport.cameraID == request.id
            applied = request.id
            if restore, let center = viewport.center {
                scroll.setZoomScale(min(2, max(scroll.minimumZoomScale, viewport.zoom)), animated: false)
                centerContent()
                place(center)
            } else if let center = request.center {
                let zoom: CGFloat = 1
                let rect = CGRect(x: center.x - scroll.bounds.width / (2 * zoom),
                                  y: center.y - scroll.bounds.height / (2 * zoom),
                                  width: scroll.bounds.width / zoom, height: scroll.bounds.height / zoom)
                scroll.zoom(to: rect, animated: animateCamera && !UIAccessibility.isReduceMotionEnabled)
            } else {
                // Open at a readable scale; Overview remains available for the whole maze.
                let zoom = request.overview ? min(1, fit) : min(1, max(0.85, fit))
                scroll.setZoomScale(zoom, animated: false)
                centerContent()
                place(CGPoint(x: worldSize.width / 2, y: worldSize.height / 2))
            }
        } else if resized {
            place(savedCenter)
        }
        lastViewport = view.bounds.size
        centerContent()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { host.view }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerContent(); rememberViewport() }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { rememberViewport() }

    private func place(_ center: CGPoint) {
        centerContent()
        let minX = -scroll.contentInset.left, minY = -scroll.contentInset.top
        let maxX = max(minX, scroll.contentSize.width - scroll.bounds.width + scroll.contentInset.right)
        let maxY = max(minY, scroll.contentSize.height - scroll.bounds.height + scroll.contentInset.bottom)
        scroll.contentOffset = CGPoint(
            x: min(maxX, max(minX, center.x * scroll.zoomScale - scroll.bounds.width / 2)),
            y: min(maxY, max(minY, center.y * scroll.zoomScale - scroll.bounds.height / 2)))
    }

    private func rememberViewport() {
        guard !updating, applied == request.id, scroll.bounds.width > 0, scroll.bounds.height > 0 else { return }
        viewport.center = CGPoint(x: (scroll.contentOffset.x + scroll.bounds.width / 2) / scroll.zoomScale,
                                  y: (scroll.contentOffset.y + scroll.bounds.height / 2) / scroll.zoomScale)
        viewport.zoom = scroll.zoomScale
        viewport.generation = generation
        viewport.cameraID = request.id
    }

    private func centerContent() {
        let horizontal = max(0, (scroll.bounds.width - worldSize.width * scroll.zoomScale) / 2)
        let vertical = max(0, (scroll.bounds.height - worldSize.height * scroll.zoomScale) / 2)
        scroll.contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
}

/// Cached walls and masked floor layers. Core Animation reveals branches without
/// rebuilding maze geometry or publishing frame-by-frame SwiftUI state.
struct WorldCorridors: UIViewRepresentable {
    var walls: CGPath
    var floorMask: CGPath
    var floorWidth: CGFloat
    var route: WorldLightRoute?
    var generation: UUID
    var selection: String?
    var animated: Bool

    func makeUIView(context: Context) -> WorldCorridorLayerView { WorldCorridorLayerView() }
    func updateUIView(_ view: WorldCorridorLayerView, context: Context) {
        view.update(walls: walls, mask: floorMask, width: floorWidth, route: route,
                    generation: generation, selection: selection, animated: animated)
    }
}

final class WorldCorridorLayerView: UIView {
    private let walls = CAShapeLayer()
    private let light = CALayer()
    private let floorMask = CAShapeLayer()
    private var generation: UUID?
    private var selection: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        floorMask.fillRule = .evenOdd
        floorMask.fillColor = UIColor.black.cgColor
        light.mask = floorMask
        layer.addSublayer(light)
        walls.fillColor = nil
        walls.strokeColor = UIColor(Ink.brass.opacity(0.45)).cgColor
        walls.lineWidth = 2
        walls.lineCap = .square
        walls.lineJoin = .miter
        layer.addSublayer(walls)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(walls path: CGPath, mask: CGPath, width: CGFloat, route: WorldLightRoute?,
                generation: UUID, selection: String?, animated: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let changed = self.generation != generation || self.selection != selection
        if self.generation != generation {
            walls.path = path; floorMask.path = mask
        }
        guard changed else {
            if !animated { light.sublayers?.forEach { $0.removeAllAnimations() } }
            return
        }
        self.generation = generation; self.selection = selection
        light.sublayers?.forEach { $0.removeAllAnimations(); $0.removeFromSuperlayer() }
        guard let route, route.distance > 0 else { return }
        let duration = min(6, max(2.5, Double(route.distance / 160)))
        let start = CACurrentMediaTime()
        for stroke in route.strokes {
            let shape = CAShapeLayer()
            shape.frame = bounds
            shape.path = stroke.path
            shape.fillColor = nil
            shape.strokeColor = UIColor(Ink.brass.opacity(0.55)).cgColor
            shape.lineWidth = width
            shape.lineCap = .butt
            shape.lineJoin = .miter
            shape.strokeEnd = 1
            light.addSublayer(shape)
            if animated && !UIAccessibility.isReduceMotionEnabled {
                let reveal = CABasicAnimation(keyPath: "strokeEnd")
                reveal.fromValue = 0; reveal.toValue = 1
                reveal.beginTime = start + duration * Double(stroke.start / route.distance)
                reveal.duration = max(0.01, duration * Double(stroke.length / route.distance))
                reveal.timingFunction = CAMediaTimingFunction(name: .linear)
                reveal.fillMode = .backwards
                shape.add(reveal, forKey: "reveal")
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        walls.frame = bounds; light.frame = bounds; floorMask.frame = bounds
        light.sublayers?.forEach { $0.frame = bounds }
        CATransaction.commit()
    }
}
