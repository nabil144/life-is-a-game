import XCTest
@testable import LifeEngine

final class WorldSceneTests: XCTestCase {
    private func path(_ name: String, nodes: [Node] = []) -> Path {
        Path(name: name, identity: name, glyph: "star", role: .hobby, nodes: nodes)
    }
    private func node(_ name: String, kind: NodeKind = .quest) -> Node {
        Node(kind: kind, title: name, createdOn: Day(Date()))
    }
    func testWorldContainsOnlyPathsAndRetainsRestingPaths() {
        let a = path("Home", nodes: [node("Fix")])
        var b = path("Music", nodes: [node("Play",kind: .practice)])
        b.status = .resting
        var archived = path("Old"); archived.status = .archived
        let inputs = WorldScene.world.inputs(paths: [a,b,archived])
        XCTAssertEqual(inputs.map(\.id),[a.id,b.id])
        XCTAssertTrue(inputs.allSatisfy { $0.work.isEmpty })
        var changed = a; changed.nodes.append(node("Another"))
        XCTAssertEqual(inputs,WorldScene.world.inputs(paths: [changed,b,archived]),"Child edits must not rebuild the outer maze")
    }
    func testInnerMazeContainsOnlyItsOwnMilestonesIncludingReachedOnes() {
        let pending = Milestone(text: "Can play a whole song")
        let reached = Milestone(text: "Own a guitar", tickedOn: Day(Date()))
        var a = path("A", nodes: [node("Quest"), node("Routine",kind: .practice)])
        a.milestones = [pending,reached]
        var b = path("B"); b.milestones = [Milestone(text: "Other")]
        let inputs = WorldScene.path(a.id).inputs(paths: [a,b])
        XCTAssertEqual(inputs.map(\.id),[pending.id,reached.id])
        XCTAssertTrue(inputs.allSatisfy { $0.work.isEmpty })
        let layout = WorldLayout(paths: inputs, portrait: true)
        let maze = WorldMaze(layout: layout)
        XCTAssertEqual(layout.rooms.count,3)
        XCTAssertTrue(maze.ownershipRouted)
        XCTAssertEqual(maze.routes.count,3)
        XCTAssertEqual(maze.roomFrames["you"]?.midX,maze.size.width/2)
        XCTAssertEqual(maze.roomFrames["you"]?.midY,maze.size.height/2)
        a.milestones[0].tickedOn = Day(Date())
        a.nodes.append(node("Another quest"))
        XCTAssertEqual(inputs,WorldScene.path(a.id).inputs(paths: [a,b]),
                       "Completing a milestone or editing quests must not move maze rooms")
        a.milestones.removeFirst()
        XCTAssertEqual(WorldScene.path(a.id).inputs(paths: [a,b]).map(\.id),[reached.id])
    }
    func testEmptyDeletedAndArchivedPathsHaveNoChildDestinations() {
        var a = path("A")
        XCTAssertTrue(WorldScene.path(a.id).inputs(paths: [a]).isEmpty)
        a.milestones = [Milestone(text: "Milestone")]; a.status = .archived
        XCTAssertTrue(WorldScene.path(a.id).inputs(paths: [a]).isEmpty)
        XCTAssertTrue(WorldScene.path(a.id).inputs(paths: []).isEmpty)
    }
}
