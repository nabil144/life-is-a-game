import XCTest
@testable import LifeEngine

final class OutsideQuestTests: XCTestCase {
    let day = Day(2026, 9, 17)

    func testLegacyNodeDecodesAndFlagRoundTrips() throws {
        var node = Node(kind: .quest, title: "Collect parcel", createdOn: day)
        let legacy = try JSONEncoder().encode(node)
        XCTAssertFalse(String(decoding: legacy, as: UTF8.self).contains("outsideHome"))
        XCTAssertFalse(try JSONDecoder().decode(Node.self, from: legacy).isOutsideQuest)
        node.outsideHome = true
        let restored = try JSONDecoder().decode(Node.self, from: JSONEncoder().encode(node))
        XCTAssertTrue(restored.isOutsideQuest)
        XCTAssertEqual(restored.id, node.id)
    }

    func testOutsideListRespectsDatesBlockersAndCompletion() {
        let blocker = Node(kind: .quest, title: "Find receipt", createdOn: day)
        var blocked = Node(kind: .quest, title: "Return purchase", after: blocker.id, createdOn: day)
        blocked.outsideHome = true
        var future = Node(kind: .quest, title: "Appointment", cue: Cue(on: day.adding(days: 1)), createdOn: day)
        future.outsideHome = true
        var ready = Node(kind: .quest, title: "Collect parcel", createdOn: day)
        ready.outsideHome = true
        var routine = Node(kind: .practice, title: "Walk", createdOn: day)
        routine.outsideHome = true
        var path = Path(name: "Life", identity: "Life", glyph: "star", role: .hobby,
                        nodes: [blocker, blocked, future, ready, routine])
        let planner = Planner()
        XCTAssertEqual(planner.outsideQuests(on: day, paths: [path]).map(\.nodeID), [ready.id])
        planner.apply(.done, to: &path.nodes[0], on: day)
        planner.apply(.done, to: &path.nodes[3], on: day)
        XCTAssertEqual(planner.outsideQuests(on: day, paths: [path]).map(\.nodeID), [blocked.id])
        path.status = .resting
        XCTAssertTrue(planner.outsideQuests(on: day, paths: [path]).isEmpty)
    }

    func testWorkOutsideQuestKeepsWeekdayRule() {
        var node = Node(kind: .quest, title: "Deliver files", createdOn: day)
        node.outsideHome = true
        let path = Path(name: "Office", identity: "Office", glyph: "briefcase", role: .work, nodes: [node])
        XCTAssertEqual(Planner().outsideQuests(on: day, paths: [path]).count, 1)
        XCTAssertTrue(Planner().outsideQuests(on: Day(2026, 9, 19), paths: [path]).isEmpty)
    }
}
