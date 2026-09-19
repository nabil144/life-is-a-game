import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import LifeEngine

final class WorldCameraLimitsTests: XCTestCase {
    func testExtremePanAndZoomCannotRevealMazeBoundary() {
        for world in [CGSize(width: 1200,height: 1900), CGSize(width: 5000,height: 8000)] {
            for screen in [CGSize(width: 320,height: 600), CGSize(width: 430,height: 900),
                           CGSize(width: 900,height: 430), CGSize(width: 1366,height: 1024)] {
                let limits = WorldCameraLimits(world: world, viewport: screen)
                for zoom in [limits.minimumZoom, max(2, limits.minimumZoom)] {
                    for point in [CGPoint(x: -100000,y: -100000), CGPoint(x: 100000,y: 100000), .zero] {
                        let offset = limits.offset(point, zoom: zoom)
                        XCTAssertGreaterThanOrEqual(offset.x / zoom, limits.margin - 0.001)
                        XCTAssertGreaterThanOrEqual(offset.y / zoom, limits.margin - 0.001)
                        XCTAssertLessThanOrEqual((offset.x + screen.width) / zoom, world.width - limits.margin + 0.001)
                        XCTAssertLessThanOrEqual((offset.y + screen.height) / zoom, world.height - limits.margin + 0.001)
                    }
                }
            }
        }
    }

    func testCompactRoomsRemainReachableInsideGeneratedPadding() {
        let inputs = (0..<9).map { _ in WorldLayout.Input(id: UUID(),work: []) }
        let layout = WorldLayout(paths: inputs, portrait: true)
        let screen = CGSize(width: 430,height: 900)
        let limits = WorldCameraLimits(world: layout.size, viewport: screen)
        XCTAssertEqual(limits.minimumZoom, 0.9)
        for room in layout.rooms {
            let proposed = CGPoint(x: room.center.x-screen.width/2,y: room.center.y-screen.height/2)
            let offset = limits.offset(proposed, zoom: 1)
            let visible = CGRect(origin: offset,size: screen)
            XCTAssertTrue(visible.contains(room.frame))
        }
    }
}
