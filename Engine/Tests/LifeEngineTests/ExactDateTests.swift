import XCTest
@testable import LifeEngine

final class ExactDateTests: XCTestCase {
    let monday = Day(2026, 9, 14)
    let saturday = Day(2026, 9, 19)
    private func path(_ node: Node, role: Role = .hobby) -> Path {
        Path(name: "Test", identity: "Test", glyph: "star", role: role,
             milestones: [Milestone(text: "Still ahead")], nodes: [node])
    }
    func testExactDateIgnoresHiddenDayAndWindowPreferences() {
        let planner = Planner()
        let node = Node(kind: .quest, title: "Dated", cue: Cue(days: .weekend, window: .evening, on: monday), createdOn: monday)
        let p = path(node, role: .lab)
        XCTAssertEqual(planner.due(on: monday, paths: [p]).first?.window, .any)
        XCTAssertEqual(planner.objective(for: monday, paths: [p], history: [])?.window, .any)
        XCTAssertTrue(planner.due(on: saturday, paths: [p]).isEmpty)
    }
    func testTurningDateOffRestoresStoredChoices() {
        let planner = Planner()
        var node = Node(kind: .quest, title: "Dated", cue: Cue(days: .weekend, window: .evening, on: monday), createdOn: monday)
        node.cue.on = nil
        XCTAssertTrue(planner.due(on: monday, paths: [path(node)]).isEmpty)
        XCTAssertEqual(planner.due(on: saturday, paths: [path(node)]).first?.window, .evening)
    }
    func testExactDateStillRespectsBlockersAndCompletion() {
        let planner = Planner()
        var blocker = Node(kind: .quest, title: "First", createdOn: monday)
        var node = Node(kind: .quest, title: "Dated", cue: Cue(on: monday), after: blocker.id, createdOn: monday)
        var p = path(node); p.nodes.insert(blocker, at: 0)
        XCTAssertFalse(planner.due(on: monday, paths: [p]).contains { $0.nodeID == node.id })
        blocker.state = .done(monday); p.nodes[0] = blocker
        XCTAssertTrue(planner.due(on: monday, paths: [p]).contains { $0.nodeID == node.id })
        node.state = .done(monday); p.nodes[1] = node
        XCTAssertTrue(planner.due(on: monday, paths: [p]).isEmpty)
    }
}
