import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import LifeEngine

final class WorldLayoutTests: XCTestCase {
    func testNearbyWorkDoesNotUseAGlobalOuterRing() {
        let ids = (0..<4).map { _ in UUID() }
        let first = (0..<4).map { _ in UUID() }
        let inputs = ids.enumerated().map { index, id in
            WorldLayout.Input(id: id, work: [first[index]] + (0..<(index == 0 ? 49 : 2)).map { _ in UUID() })
        }
        let layout = WorldLayout(paths: inputs)
        for index in ids.indices {
            let path = layout.rooms.first { $0.pathID == ids[index] && $0.workID == nil }!
            let work = layout.rooms.first { $0.workID == first[index] }!
            XCTAssertLessThan(hypot(work.center.x-path.center.x, work.center.y-path.center.y), 300)
        }
        let children = layout.rooms.filter { $0.pathID == ids[0] && $0.workID != nil }
        XCTAssertGreaterThan(Set(children.map { Int($0.center.x) }).count, 3)
        XCTAssertGreaterThan(Set(children.map { Int($0.center.y) }).count, 3)
    }

    func testAddingQuestsDoesNotMovePathsAwayFromYou() {
        for count in [1, 4, 5, 8, 12] {
            let ids = (0..<count).map { _ in UUID() }
            let sparse = WorldLayout(paths: ids.map { .init(id: $0, work: [UUID()]) })
            let crowded = WorldLayout(paths: ids.enumerated().map { i, id in
                .init(id: id, work: (0..<(i == 0 ? 50 : 3)).map { _ in UUID() })
            })
            for room in sparse.rooms where room.workID == nil {
                let other = crowded.rooms.first { $0.id == room.id }!
                XCTAssertEqual(room.center.x - sparse.center.x, other.center.x - crowded.center.x)
                XCTAssertEqual(room.center.y - sparse.center.y, other.center.y - crowded.center.y)
            }
        }
    }

    func testOutwardRoutingAndNonoverlappingRooms() {
        var cases = [[], [0], [1], [20, 1, 0, 3, 8, 2], Array(repeating: 12, count: 12)]
        cases += (0..<12).map { seed in (0..<(seed + 1)).map { ($0 * 7 + seed * 3) % 15 } }
        for counts in cases {
            let inputs = counts.map { count in WorldLayout.Input(id: UUID(), work: (0..<count).map { _ in UUID() }) }
            let layout = WorldLayout(paths: inputs)
            XCTAssertEqual(layout.rooms.count, 1 + counts.count + counts.reduce(0, +))
            for (i, room) in layout.rooms.enumerated() {
                for other in layout.rooms.dropFirst(i + 1) {
                    XCTAssertFalse(room.frame.insetBy(dx: -8, dy: -8).intersects(other.frame), "Overlap: \(room.center) and \(other.center)")
                }
            }
            for edge in layout.corridors {
                for (a, b) in zip(edge.points, edge.points.dropFirst()) {
                    XCTAssertTrue(a.x == b.x || a.y == b.y)
                    let ax = a.x-layout.center.x, ay = a.y-layout.center.y
                    let bx = b.x-layout.center.x, by = b.y-layout.center.y
                    XCTAssertGreaterThanOrEqual(abs(bx), abs(ax))
                    XCTAssertGreaterThanOrEqual(abs(by), abs(ay))
                    XCTAssertGreaterThanOrEqual(ax * bx, 0)
                    XCTAssertGreaterThanOrEqual(ay * by, 0)
                    for room in layout.rooms {
                        let isEndpoint = edge.workID == nil
                            ? room.id == "you" || (room.pathID == edge.pathID && room.workID == nil)
                            : room.pathID == edge.pathID && (room.workID == nil || room.workID == edge.workID)
                        if !isEndpoint {
                            let r = room.frame
                            let overlapsX = max(a.x, b.x) > r.minX && min(a.x, b.x) < r.maxX
                            let overlapsY = max(a.y, b.y) > r.minY && min(a.y, b.y) < r.maxY
                            XCTAssertFalse(overlapsX && overlapsY)
                        }
                    }
                }
            }
            XCTAssertEqual(layout.rooms.map(\.center), WorldLayout(paths: inputs).rooms.map(\.center))
            // All geometry is on a four-point grid. Index occupied grid points
            // instead of comparing every staircase segment with every other one.
            struct Cell: Hashable { var x: Int; var y: Int }
            var occupied: [Cell: [UUID: Bool]] = [:]
            for edge in layout.corridors {
                for (a, b) in zip(edge.points, edge.points.dropFirst()) {
                    let steps = Int(max(abs(a.x-b.x), abs(a.y-b.y)) / 4)
                    for i in 0...steps {
                        let t = steps == 0 ? 0 : CGFloat(i) / CGFloat(steps)
                        let cell = Cell(x: Int((a.x + (b.x-a.x)*t) / 4), y: Int((a.y + (b.y-a.y)*t) / 4))
                        for (owner, isWork) in occupied[cell] ?? [:] where owner != edge.pathID {
                            XCTAssertFalse(isWork || edge.workID != nil, "Different path branches must not intersect")
                        }
                        occupied[cell, default: [:]][edge.pathID] = (occupied[cell]?[edge.pathID] ?? false) || edge.workID != nil
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
