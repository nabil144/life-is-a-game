import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import LifeEngine

final class WorldDecorationTests: XCTestCase {
    func testDecorationIsStableBoundedAndClearOfRealRoutes() {
        let inputs = [2, 5, 0, 3, 1].map { n in
            WorldLayout.Input(id: UUID(), work: (0..<n).map { _ in UUID() })
        }
        let layout = WorldLayout(paths: inputs)
        let decoration = WorldDecoration(layout: layout)
        XCTAssertFalse(decoration.segments.isEmpty)
        XCTAssertLessThan(decoration.segments.count, 8000)
        XCTAssertEqual(decoration.segments, WorldDecoration(layout: layout).segments)
        for segment in decoration.segments {
            XCTAssertTrue(segment.from.x == segment.to.x || segment.from.y == segment.to.y)
            for step in 0...8 {
                let t = CGFloat(step) / 8
                let point = CGPoint(x: segment.from.x + (segment.to.x-segment.from.x)*t,
                                    y: segment.from.y + (segment.to.y-segment.from.y)*t)
                for room in layout.rooms {
                    XCTAssertFalse(room.frame.insetBy(dx: -12, dy: -12).contains(point))
                }
                for edge in layout.corridors {
                    for (a, b) in zip(edge.points, edge.points.dropFirst()) {
                        let bounds = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x-b.x), height: abs(a.y-b.y))
                        XCTAssertFalse(bounds.insetBy(dx: -10, dy: -10).contains(point))
                    }
                }
            }
        }
    }

    func testLargeWorldDecorationBudget() {
        let layout = WorldLayout(paths: (0..<20).map { _ in
            .init(id: UUID(), work: (0..<50).map { _ in UUID() })
        })
        measure {
            XCTAssertLessThan(WorldDecoration(layout: layout).segments.count, 8000)
        }
    }

    func testSmallWorldKeepsPathsCloseToYou() {
        let layout = WorldLayout(paths: (0..<4).map { _ in .init(id: UUID(), work: [UUID()]) })
        for room in layout.rooms where room.pathID != nil && room.workID == nil {
            XCTAssertEqual(hypot(room.center.x-layout.center.x, room.center.y-layout.center.y), 160, accuracy: 0.001)
        }
    }
}
