import XCTest
@testable import LifeEngine

final class MonthlyRoutineTests: XCTestCase {
    private let planner = Planner()

    private func path(day: Int, role: Role = .hobby) -> Path {
        let node = Node(kind: .practice, title: "Monthly check", cue: Cue(monthDay: day), createdOn: Day(2026, 1, 1))
        return Path(name: "Test", identity: "Test", glyph: "star", role: role, nodes: [node])
    }

    func testMonthlyDateMatchesTodayAndNotificationPlanning() {
        let p = path(day: 15, role: .work)
        let sunday = Day(2026, 2, 15)
        XCTAssertTrue(planner.due(on: sunday.adding(days: -1), paths: [p]).isEmpty)
        XCTAssertEqual(planner.due(on: sunday, paths: [p]).count, 1)
        XCTAssertNotNil(planner.objective(for: sunday, paths: [p], history: []))
        XCTAssertTrue(planner.due(on: sunday.adding(days: 1), paths: [p]).isEmpty)
        XCTAssertNil(planner.objective(for: sunday.adding(days: 1), paths: [p], history: []))
    }

    func testMonthEndHandlesShortMonthsLeapYearsAndYearBoundary() {
        for date in [Day(2026, 2, 28), Day(2028, 2, 29), Day(2026, 4, 30), Day(2026, 12, 31), Day(2027, 1, 31)] {
            let p = path(day: 31)
            XCTAssertTrue(planner.due(on: date.adding(days: -1), paths: [p]).isEmpty, date.description)
            XCTAssertEqual(planner.due(on: date, paths: [p]).count, 1, date.description)
            XCTAssertNotNil(planner.objective(for: date, paths: [p], history: []), date.description)
            XCTAssertTrue(planner.due(on: date.adding(days: 1), paths: [p]).isEmpty, date.description)
        }
    }

    func testCompletionDoesNotShiftNextMonthAndBlockersStillApply() {
        var p = path(day: 31)
        let february = Day(2026, 2, 28)
        planner.apply(.done, to: &p.nodes[0], on: february)
        XCTAssertTrue(planner.due(on: february, paths: [p]).isEmpty)
        XCTAssertNil(planner.objective(for: february, paths: [p], history: []))
        XCTAssertTrue(planner.due(on: Day(2026, 3, 28), paths: [p]).isEmpty)
        XCTAssertEqual(planner.due(on: Day(2026, 3, 31), paths: [p]).count, 1)
        let blocker = Node(kind: .quest, title: "First", createdOn: february)
        p.nodes[0].after = blocker.id
        p.nodes.append(blocker)
        XCTAssertFalse(planner.due(on: Day(2026, 3, 31), paths: [p]).contains { $0.nodeID == p.nodes[0].id })
    }

    func testMonthlyCueRoundTripsAndOldCuesKeepTheirRhythm() throws {
        let cue = Cue(window: .evening, monthDay: 23)
        let data = try JSONEncoder().encode(cue)
        XCTAssertEqual(try JSONDecoder().decode(Cue.self, from: data), cue)
        let old = try JSONDecoder().decode(Cue.self, from: Data(#"{"days":"any","window":"any","every":7}"#.utf8))
        XCTAssertNil(old.monthDay)
        XCTAssertEqual(old.practiceRhythm, .weekly)
        let invalid = try JSONDecoder().decode(Cue.self, from: Data(#"{"monthDay":99}"#.utf8))
        XCTAssertEqual(invalid.monthDay, 31)
    }

    func testSwitchingRhythmClearsMonthlyRestrictionAndExactDate() {
        var cue = Cue(on: Day(2026, 4, 3), every: 7)
        cue.practiceRhythm = .monthly
        XCTAssertNil(cue.on)
        XCTAssertEqual(cue.monthDay, 1)
        cue.monthDay = 20
        XCTAssertEqual(cue.practiceRhythm, .monthly)
        cue.practiceRhythm = .weekdays
        XCTAssertNil(cue.monthDay)
        XCTAssertEqual(cue.days, .weekday)
        XCTAssertEqual(cue.every, 1)
    }
}
