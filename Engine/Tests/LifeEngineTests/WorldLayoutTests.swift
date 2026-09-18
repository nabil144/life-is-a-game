import XCTest
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
        }
    }
}
