import XCTest
@testable import LifeEngine

final class PlannerTests: XCTestCase {
    let planner = Planner()
    let fri = Day(2026, 9, 11)
    let sat = Day(2026, 9, 12)
    let sun = Day(2026, 9, 13)
    let mon = Day(2026, 9, 14)

    func path(_ name: String, role: Role = .hobby, deadline: Day? = nil, nodes: [Node], milestones: [Milestone] = [Milestone(text: "it moved")]) -> Path {
        Path(name: name, identity: name, glyph: "star", role: role, deadline: deadline, milestones: milestones, nodes: nodes)
    }

    func quest(_ title: String, cue: Cue = .anytime, after: UUID? = nil) -> Node {
        Node(kind: .quest, title: title, cue: cue, after: after, createdOn: fri)
    }

    func testDayArithmeticAndWeekend() {
        XCTAssertEqual(fri.weekday, 6)
        XCTAssertTrue(planner.isWeekend(sat))
        XCTAssertTrue(planner.isWeekend(sun))
        XCTAssertFalse(planner.isWeekend(mon))
        XCTAssertEqual(fri.adding(days: 3), mon)
        XCTAssertEqual(mon.days(since: fri), 3)
        XCTAssertEqual(Day(2026, 12, 31).adding(days: 1), Day(2027, 1, 1))
    }

    func testAtMostOneObjectivePerDay() {
        let p = path("A", nodes: [quest("one"), quest("two"), quest("three")])
        let plan = planner.plan(days: [sat, sun, mon], paths: [p], history: [])
        XCTAssertEqual(plan.count, 3)
        XCTAssertEqual(Set(plan.map(\.day)).count, 3)
    }

    func testWeekendCueIsSilentOnWeekday() {
        let p = path("A", nodes: [quest("strings", cue: Cue(days: .weekend))])
        XCTAssertNil(planner.objective(for: mon, paths: [p], history: []))
        XCTAssertEqual(planner.objective(for: sat, paths: [p], history: [])?.nodeID, p.nodes[0].id)
    }

    func testBlockerGatesUntilDone() {
        let first = quest("clean")
        let second = quest("strings", after: first.id)
        var p = path("A", nodes: [first, second])
        XCTAssertEqual(planner.candidates(for: sat, paths: [p], history: []).map(\.nodeID), [first.id])

        planner.apply(.done, to: &p.nodes[0], on: fri)
        XCTAssertEqual(planner.candidates(for: sat, paths: [p], history: []).map(\.nodeID), [second.id])
    }

    func testNoRepeatWithinSevenDays() {
        let p = path("A", nodes: [quest("only")])
        let plan = planner.plan(days: (0..<10).map { sat.adding(days: $0) }, paths: [p], history: [])
        XCTAssertEqual(plan.map(\.day), [sat, sat.adding(days: 7)])
    }

    func testRoleWindows() {
        XCTAssertEqual(planner.roleWindow(.hobby, on: mon), .evening)
        XCTAssertEqual(planner.roleWindow(.hobby, on: sat), .morning)
        XCTAssertNil(planner.roleWindow(.lab, on: mon))
        XCTAssertNil(planner.roleWindow(.work, on: sat))
        XCTAssertEqual(planner.roleWindow(.work, on: mon), .morning)
    }

    func testWorkPathIsSilentOnWeekend() {
        let p = path("Job", role: .work, nodes: [quest("write the doc")])
        XCTAssertNil(planner.objective(for: sat, paths: [p], history: []))
        XCTAssertEqual(planner.objective(for: mon, paths: [p], history: [])?.window, .morning)
    }

    func testCueWindowOverridesRoleWindow() {
        let p = path("A", nodes: [quest("practice", cue: Cue(window: .evening))])
        XCTAssertEqual(planner.objective(for: sat, paths: [p], history: [])?.window, .evening)
    }

    func testRotationPrefersADifferentPathThanYesterday() {
        let a = path("A", nodes: [quest("a1"), quest("a2")])
        let b = path("B", nodes: [quest("b1")])
        let plan = planner.plan(days: [sat, sun], paths: [a, b], history: [])
        XCTAssertEqual(plan.map(\.pathID), [a.id, b.id])
    }

    func testTwoSkipsPauseTheNode() {
        var n = quest("x")
        planner.apply(.notNow, to: &n, on: sat)
        XCTAssertEqual(n.state, .todo)
        planner.apply(.notNow, to: &n, on: sun)
        XCTAssertEqual(n.state, .paused)
        planner.apply(.reopen, to: &n, on: mon)
        XCTAssertEqual(n.state, .todo)
        XCTAssertEqual(n.consecutiveSkips, 0)
    }

    func testDoneOnPracticeKeepsItOpen() {
        var n = Node(kind: .practice, title: "chords", createdOn: fri)
        planner.apply(.done, to: &n, on: sat)
        XCTAssertTrue(n.isOpen)
        XCTAssertEqual(n.lastDone, sat)
    }

    func testStaleCheckThenNotTaken() {
        let n = quest("forgotten")
        var paths = [path("A", nodes: [n])]
        let surfaced = fri.adding(days: 10)
        let history = [Surfacing(day: surfaced, pathID: paths[0].id, nodeID: n.id, kind: .objective)]

        let tooEarly = fri.adding(days: 29)
        XCTAssertEqual(planner.objective(for: tooEarly, paths: paths, history: history)?.kind, .objective)

        let stale = fri.adding(days: 30)
        let check = planner.objective(for: stale, paths: paths, history: history)
        XCTAssertEqual(check?.kind, .staleCheck)
        planner.record(check!, in: &paths)
        XCTAssertEqual(paths[0].nodes[0].staleCheckOn, stale)

        let stillWaiting = planner.reconcile(paths, on: stale.adding(days: 6))
        XCTAssertTrue(stillWaiting[0].nodes[0].isOpen)
        let gone = planner.reconcile(paths, on: stale.adding(days: 7))
        XCTAssertEqual(gone[0].nodes[0].state, .notTaken)
    }

    func testKeepClearsStaleCheck() {
        var n = quest("kept")
        n.staleCheckOn = sat
        planner.apply(.keep, to: &n, on: sun)
        XCTAssertNil(n.staleCheckOn)
        XCTAssertEqual(n.touchedOn, sun)
        XCTAssertTrue(planner.reconcile([path("A", nodes: [n])], on: sun.adding(days: 30))[0].nodes[0].isOpen)
    }

    func testEvolvedPathGoesQuiet() {
        let p = path("A", nodes: [quest("x")], milestones: [Milestone(text: "done", tickedOn: fri)])
        XCTAssertTrue(p.isEvolved)
        XCTAssertNil(planner.objective(for: sat, paths: [p], history: []))
    }

    func testDecisionSurfacesWeeklyThenDailyNearDeadline() {
        let deadline = sat.adding(days: 20)
        let p = path("Car", role: .decision, deadline: deadline, nodes: [quest("cost"), quest("want"), quest("talk"), quest("decide")])
        let days = (0..<21).map { sat.adding(days: $0) }
        let plan = planner.plan(days: days, paths: [p], history: [])
        let picked = plan.map { $0.day.days(since: sat) }
        XCTAssertEqual(picked, [0, 7, 14, 17, 18, 19], "weekly until the last three days, then daily while the cooldown allows")
    }

    func testPlanNeverPicksFromRestingOrArchivedPaths() {
        var p = path("A", nodes: [quest("x")])
        p.status = .resting
        XCTAssertNil(planner.objective(for: sat, paths: [p], history: []))
        p.status = .archived
        XCTAssertNil(planner.objective(for: sat, paths: [p], history: []))
    }
}
