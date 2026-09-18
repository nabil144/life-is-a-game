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
    func testInnerMazeContainsOnlyItsOwnOpenQuestsAndRoutines() {
        let quest = node("Quest"), routine = node("Routine",kind: .practice)
        var done = node("Done"); done.state = .done(Day(Date()))
        var canceled = node("Canceled"); canceled.state = .notTaken
        var paused = node("Paused"); paused.state = .paused
        let a = path("A",nodes: [quest,routine,done,canceled,paused])
        let b = path("B",nodes: [node("Other")])
        let inputs = WorldScene.path(a.id).inputs(paths: [a,b])
        XCTAssertEqual(inputs.map(\.id),[quest.id,routine.id])
        XCTAssertTrue(inputs.allSatisfy { $0.work.isEmpty })
        let layout = WorldLayout(paths: inputs)
        let maze = WorldMaze(layout: layout)
        XCTAssertEqual(layout.rooms.count,3)
        XCTAssertTrue(maze.ownershipRouted)
        XCTAssertEqual(maze.routes.count,3)
        XCTAssertEqual(maze.roomFrames["you"]?.midX,maze.size.width/2)
        XCTAssertEqual(maze.roomFrames["you"]?.midY,maze.size.height/2)
    }
    func testEmptyDeletedAndArchivedPathsHaveNoChildDestinations() {
        var a = path("A")
        XCTAssertTrue(WorldScene.path(a.id).inputs(paths: [a]).isEmpty)
        a.nodes = [node("Quest")]; a.status = .archived
        XCTAssertTrue(WorldScene.path(a.id).inputs(paths: [a]).isEmpty)
        XCTAssertTrue(WorldScene.path(a.id).inputs(paths: []).isEmpty)
    }
}
