import XCTest
@testable import LifeEngine

final class TemplateTests: XCTestCase {
    /// `Engine/Tests/LifeEngineTests/TemplateTests.swift` -> project root.
    var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    func testEveryTemplateFileDecodesAndInstantiates() throws {
        let dir = root.appendingPathComponent("templates")
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertEqual(files.count, 4)
        for file in files {
            let t = try JSONFiles.decoder().decode(Template.self, from: Data(contentsOf: file))
            XCTAssertEqual(t.id, file.deletingPathExtension().lastPathComponent)
            let path = try t.path.instantiate(on: Day(2026, 9, 11))
            XCTAssertFalse(path.milestones.isEmpty, t.id)
            XCTAssertGreaterThanOrEqual(path.nodes.count, 3, t.id)
            for n in path.nodes where n.after != nil {
                XCTAssertNotNil(path.node(n.after!), "\(t.id): blocker of \(n.title) resolves")
            }
        }
    }

    func testOwnerTestDataDecodesAndPlansAWeek() throws {
        let url = root.appendingPathComponent("testdata/owner-paths.json")
        let bundle = try JSONFiles.decoder().decode(PathBundle.self, from: Data(contentsOf: url))
        let paths = try bundle.paths.map { try $0.instantiate(on: Day(2026, 9, 11)) }
        XCTAssertEqual(paths.count, 4)

        let sat = Day(2026, 9, 12)
        let plan = Planner().plan(days: (0..<7).map { sat.adding(days: $0) }, paths: paths, history: [])
        XCTAssertFalse(plan.isEmpty)
        XCTAssertEqual(Set(plan.map(\.day)).count, plan.count, "one objective per day")
        XCTAssertTrue(Set(plan.map(\.pathID)).count >= 2, "a week touches more than one path")
    }

    func testUnknownBlockerFailsLoudly() {
        let draft = PathDraft(name: "x", identity: "x", glyph: "star", role: .hobby, deadline: nil, milestones: ["m"],
                              nodes: [.init(kind: .quest, title: "b", after: "typo")])
        XCTAssertThrowsError(try draft.instantiate(on: Day(2026, 9, 11))) { error in
            XCTAssertEqual(error as? PathDraft.DraftError, .unknownBlocker(node: "b", after: "typo"))
        }
    }

    func testRoundTripThroughJSON() throws {
        let draft = PathDraft(name: "x", identity: "y", glyph: "star", role: .lab, deadline: Day(2026, 10, 1), milestones: ["m"],
                              nodes: [.init(kind: .practice, title: "p", cue: Cue(days: .weekend, window: .morning))])
        let data = try JSONFiles.encoder().encode(PathBundle(paths: [draft]))
        let back = try JSONFiles.decoder().decode(PathBundle.self, from: data)
        XCTAssertEqual(back.paths[0].deadline, Day(2026, 10, 1))
        XCTAssertEqual(back.paths[0].nodes[0].cue, Cue(days: .weekend, window: .morning))
    }
}
