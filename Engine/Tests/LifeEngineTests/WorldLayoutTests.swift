import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import LifeEngine

final class WorldLayoutTests: XCTestCase {
    func testOutwardRoutingAndNonoverlappingRooms() {
        for counts in [[], [0], [1], [20, 1, 0, 3, 8, 2], Array(repeating: 12, count: 12)] {
            let inputs = counts.map { count in WorldLayout.Input(id: UUID(), work: (0..<count).map { _ in UUID() }) }
            let layout = WorldLayout(paths: inputs)
            XCTAssertEqual(layout.rooms.count, 1 + counts.count + counts.reduce(0, +))
            for (i, room) in layout.rooms.enumerated() {
                for other in layout.rooms.dropFirst(i + 1) {
                    XCTAssertFalse(room.frame.insetBy(dx: -8, dy: -8).intersects(other.frame))
                }
            }
            for edge in layout.corridors {
                for (a, b) in zip(edge.points, edge.points.dropFirst()) {
                    XCTAssertTrue(a.x == b.x || a.y == b.y)
                    var last: CGFloat = -1
                    for step in 0...20 {
                        let t = CGFloat(step) / 20
                        let p = CGPoint(x: a.x + (b.x-a.x)*t, y: a.y + (b.y-a.y)*t)
                        let d = hypot(p.x-layout.center.x, p.y-layout.center.y)
                        XCTAssertGreaterThanOrEqual(d + 0.001, last)
                        last = d
                        for room in layout.rooms {
                            let isEndpoint = edge.workID == nil
                                ? room.id == "you" || (room.pathID == edge.pathID && room.workID == nil)
                                : room.pathID == edge.pathID && (room.workID == nil || room.workID == edge.workID)
                            if !isEndpoint { XCTAssertFalse(room.frame.contains(p)) }
                        }
                    }
                }
            }
            XCTAssertEqual(layout.rooms.map(\.center), WorldLayout(paths: inputs).rooms.map(\.center))
            for (i, edge) in layout.corridors.enumerated() {
                for other in layout.corridors.dropFirst(i + 1)
                    where edge.pathID != other.pathID && (edge.workID != nil || other.workID != nil) {
                    for (a, b) in zip(edge.points, edge.points.dropFirst()) where a != b {
                        for (c, d) in zip(other.points, other.points.dropFirst()) where c != d {
                            let overlapX = max(min(a.x, b.x), min(c.x, d.x)) <= min(max(a.x, b.x), max(c.x, d.x))
                            let overlapY = max(min(a.y, b.y), min(c.y, d.y)) <= min(max(a.y, b.y), max(c.y, d.y))
                            XCTAssertFalse(overlapX && overlapY, "Different path branches must not intersect")
                        }
                    }
                }
            }
        }
    }

    func testThousandQuestLayoutPerformance() {
        let inputs = (0..<20).map { _ in
            WorldLayout.Input(id: UUID(), work: (0..<50).map { _ in UUID() })
        }
        measure {
            let layout = WorldLayout(paths: inputs)
            XCTAssertEqual(layout.rooms.count, 1021)
        }
    }
}
