import SwiftUI
import UIKit
import LifeEngine

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
    private var constraining = false

    private var limits: WorldCameraLimits {
        WorldCameraLimits(world: worldSize, viewport: scroll.bounds.size)
    }

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
        scroll.bounces = false
        scroll.bouncesZoom = false
        scroll.minimumZoomScale = 0.9
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
        defer { updating = false; constrainOffset(); rememberViewport() }
        let resized = lastViewport != view.bounds.size
        let savedCenter = CGPoint(x: (scroll.contentOffset.x + scroll.bounds.width / 2) / scroll.zoomScale,
                                  y: (scroll.contentOffset.y + scroll.bounds.height / 2) / scroll.zoomScale)
        scroll.frame = view.bounds
        guard worldSize.width > 0, worldSize.height > 0, scroll.bounds.width > 0, scroll.bounds.height > 0 else { return }
        scroll.maximumZoomScale = max(2, limits.minimumZoom)
        scroll.minimumZoomScale = limits.minimumZoom
        if applied != request.id {
            let restore = applied == nil && viewport.generation == generation && viewport.cameraID == request.id
            applied = request.id
            if restore, let center = viewport.center {
                scroll.setZoomScale(min(scroll.maximumZoomScale, max(scroll.minimumZoomScale, viewport.zoom)), animated: false)
                updateMazeInsets()
                place(center)
            } else if let center = request.center {
                let zoom = max(1, scroll.minimumZoomScale)
                let rect = CGRect(x: center.x - scroll.bounds.width / (2 * zoom),
                                  y: center.y - scroll.bounds.height / (2 * zoom),
                                  width: scroll.bounds.width / zoom, height: scroll.bounds.height / zoom)
                scroll.zoom(to: rect, animated: animateCamera && !UIAccessibility.isReduceMotionEnabled)
            } else {
                // Even the widest view stays inside the maze, with readable room labels.
                let zoom = request.overview ? scroll.minimumZoomScale : max(1, scroll.minimumZoomScale)
                scroll.setZoomScale(zoom, animated: false)
                updateMazeInsets()
                place(CGPoint(x: worldSize.width / 2, y: worldSize.height / 2))
            }
        } else if resized {
            place(savedCenter)
        }
        lastViewport = view.bounds.size
        updateMazeInsets()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { host.view }
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateMazeInsets(); constrainOffset(); rememberViewport()
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { constrainOffset(); rememberViewport() }

    private func place(_ center: CGPoint) {
        updateMazeInsets()
        scroll.contentOffset = limits.offset(
            CGPoint(x: center.x * scroll.zoomScale - scroll.bounds.width / 2,
                    y: center.y * scroll.zoomScale - scroll.bounds.height / 2), zoom: scroll.zoomScale)
    }

    private func constrainOffset() {
        guard !updating, !constraining, worldSize.width > 0, scroll.bounds.width > 0 else { return }
        let offset = limits.offset(scroll.contentOffset, zoom: scroll.zoomScale)
        guard offset != scroll.contentOffset else { return }
        constraining = true
        scroll.contentOffset = offset
        constraining = false
    }

    private func rememberViewport() {
        guard !updating, applied == request.id, scroll.bounds.width > 0, scroll.bounds.height > 0 else { return }
        viewport.center = CGPoint(x: (scroll.contentOffset.x + scroll.bounds.width / 2) / scroll.zoomScale,
                                  y: (scroll.contentOffset.y + scroll.bounds.height / 2) / scroll.zoomScale)
        viewport.zoom = scroll.zoomScale
        viewport.generation = generation
        viewport.cameraID = request.id
    }

    private func updateMazeInsets() {
        guard worldSize.width > 0 else { return }
        let inset = -limits.margin * scroll.zoomScale
        let insets = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        if scroll.contentInset != insets { scroll.contentInset = insets }
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
    private var motionEnabled: Bool?

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
        let motion = animated && !UIAccessibility.isReduceMotionEnabled
        let changed = self.generation != generation || self.selection != selection || motionEnabled != motion
        if self.generation != generation {
            walls.path = path; floorMask.path = mask
        }
        guard changed else { return }
        self.generation = generation; self.selection = selection
        motionEnabled = motion
        light.sublayers?.forEach { $0.removeAllAnimations(); $0.removeFromSuperlayer() }
        guard let route, route.road.length > 0, route.road.points.count > 1 else { return }
        let road = route.road
        let duration = Double(road.length / 100)
        let start = light.convertTime(CACurrentMediaTime(), from: nil)

        func dots(opacity: CGFloat) -> CAShapeLayer {
            let shape = CAShapeLayer()
            shape.name = "road"
            shape.frame = bounds
            shape.path = route.path
            shape.fillColor = nil
            shape.strokeColor = UIColor(Ink.brass.opacity(Double(opacity))).cgColor
            shape.lineWidth = 2
            shape.lineCap = .round
            shape.lineDashPattern = [2, 14]
            light.addSublayer(shape)
            return shape
        }
        // The faint road remains legible after the brighter dots are eaten.
        _ = dots(opacity: motion ? 0.22 : 0.65)
        guard motion else { return }
        let food = dots(opacity: 0.9)
        food.strokeStart = 1
        let eat = CABasicAnimation(keyPath: "strokeStart")
        eat.fromValue = 0; eat.toValue = 1; eat.duration = duration
        eat.beginTime = start
        eat.timingFunction = CAMediaTimingFunction(name: .linear)
        food.add(eat, forKey: "eat")

        let traveller = CAShapeLayer()
        traveller.bounds = CGRect(x: -5,y: -5,width: 10,height: 10)
        traveller.fillColor = UIColor(Ink.brass).cgColor
        traveller.path = mouth(open: 0.12)
        traveller.position = road.points.last!
        let angles = zip(road.points,road.points.dropFirst()).map { a,b in atan2(b.y-a.y,b.x-a.x) }
        traveller.setAffineTransform(CGAffineTransform(rotationAngle: angles.last!))
        light.addSublayer(traveller)

        let times = road.distances.map { NSNumber(value: Double($0 / road.length)) }
        let walk = CAKeyframeAnimation(keyPath: "position")
        walk.values = road.points.map { NSValue(cgPoint: $0) }
        walk.keyTimes = times
        walk.calculationMode = .linear
        walk.duration = duration
        walk.beginTime = start
        let turn = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        turn.values = (angles + [angles.last!]).map { NSNumber(value: Double($0)) }
        turn.keyTimes = times
        turn.calculationMode = .discrete
        turn.duration = duration
        turn.beginTime = start
        let chomp = CABasicAnimation(keyPath: "path")
        chomp.fromValue = mouth(open: 0.08)
        chomp.toValue = mouth(open: .pi / 3)
        chomp.duration = 0.14
        chomp.beginTime = start
        chomp.autoreverses = true
        chomp.repeatDuration = duration
        traveller.add(walk, forKey: "walk")
        traveller.add(turn, forKey: "turn")
        traveller.add(chomp, forKey: "chomp")
    }

    private func mouth(open: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addArc(center: .zero, radius: 5, startAngle: open, endAngle: 2 * .pi - open, clockwise: false)
        path.closeSubpath()
        return path
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { light.sublayers?.forEach { $0.removeAllAnimations() } }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        walls.frame = bounds; light.frame = bounds; floorMask.frame = bounds
        // The traveller owns its small bounds; only road layers fill the canvas.
        light.sublayers?.filter { $0.name == "road" }.forEach { $0.frame = bounds }
        CATransaction.commit()
    }
}
