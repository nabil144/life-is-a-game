import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Keep a strip of generated maze beyond every viewport edge, including when
/// pinching or panning to an extreme. Independent of the number of destinations.
public struct WorldCameraLimits: Sendable {
    public let world: CGSize
    public let viewport: CGSize
    public let margin: CGFloat = 32

    public init(world: CGSize, viewport: CGSize) {
        self.world = world
        self.viewport = viewport
    }

    public var minimumZoom: CGFloat {
        max(0.9, viewport.width / max(1, world.width - 2 * margin),
            viewport.height / max(1, world.height - 2 * margin))
    }

    public func offset(_ proposed: CGPoint, zoom: CGFloat) -> CGPoint {
        let low = margin * zoom
        return CGPoint(
            x: min(max(low, world.width * zoom - viewport.width - low), max(low, proposed.x)),
            y: min(max(low, world.height * zoom - viewport.height - low), max(low, proposed.y)))
    }
}
