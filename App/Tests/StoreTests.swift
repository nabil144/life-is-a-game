import XCTest
import LifeEngine
@testable import LifeIsAGame

final class StoreTests: XCTestCase {
    func makeStore() -> Store {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return Store(directory: dir)
    }

    func testPlanPersistsAndIsIdempotent() throws {
        let store = makeStore()
        let path = try PathDraft(name: "A", identity: "A", glyph: "star", role: .hobby, milestones: ["m"],
                                 nodes: [.init(kind: .quest, title: "one"), .init(kind: .quest, title: "two")])
            .instantiate(on: store.today)
        store.add(path)
        let first = store.refreshPlan()
        let second = store.refreshPlan()
        XCTAssertEqual(Set(second.map(\.day)), Set(first.map(\.day).filter { $0 > store.today }), "replanning keeps today and rebuilds the future")
        XCTAssertEqual(store.world.history.filter { $0.day > store.today }.count, second.count)
    }

    func testUpdatePathKeepsNodesAndTicks() throws {
        let store = makeStore()
        var path = try PathDraft(name: "Guitar", identity: "Guitarist", glyph: "guitars", role: .hobby, milestones: ["It holds tune"],
                                 nodes: [.init(kind: .quest, title: "Change the strings")]).begun(on: store.today)
        path.milestones[0].tickedOn = store.today
        store.add(path)
        let nodeID = store.paths[0].nodes[0].id
        var edited = store.paths[0]
        edited.name = "The guitar"
        edited.identity = "Player"
        edited.milestones[0].text = "It stays in tune"
        store.update(edited)
        XCTAssertEqual(store.paths[0].name, "The guitar")
        XCTAssertEqual(store.paths[0].identity, "Player")
        XCTAssertEqual(store.paths[0].milestones[0].text, "It stays in tune")
        XCTAssertEqual(store.paths[0].milestones[0].tickedOn, store.today)
        XCTAssertEqual(store.paths[0].nodes[0].id, nodeID)
    }

    func testDoneWritesALogEntry() throws {
        let store = makeStore()
        let path = try PathDraft(name: "A", identity: "A", glyph: "star", role: .hobby, milestones: ["m"],
                                 nodes: [.init(kind: .quest, title: "one")]).instantiate(on: store.today)
        store.add(path)
        let node = store.paths[0].nodes[0]
        store.respond(.done, nodeID: node.id, note: "did it")
        XCTAssertEqual(store.world.log.count, 1)
        XCTAssertEqual(store.world.log[0].text, "did it")
        XCTAssertTrue(store.paths[0].nodes[0].isDone)
    }

    func testImportWorldKeepsTicksAndLog() throws {
        let store = makeStore()
        var path = try PathDraft(name: "Guitar", identity: "Guitarist", glyph: "guitars", role: .hobby, milestones: ["It holds tune"],
                                 nodes: [.init(kind: .quest, title: "Change the strings")]).begun(on: store.today)
        path.milestones[0].tickedOn = store.today
        store.add(path)
        store.respond(.done, nodeID: store.paths[0].nodes[0].id, note: "did it")
        let data = try store.exportWorld()

        let other = makeStore()
        try other.importData(data)
        XCTAssertEqual(other.paths[0].name, "Guitar")
        XCTAssertEqual(other.paths[0].milestones[0].tickedOn, store.today)
        XCTAssertEqual(other.world.log.count, 1)
        XCTAssertTrue(other.world.onboarded)
    }

    func testImportBundleAppendsDrafts() throws {
        let store = makeStore()
        let bundle = PathBundle(paths: [
            PathDraft(name: "Lab", identity: "Tinkerer", glyph: "cpu", role: .lab, milestones: ["It runs"], nodes: []),
        ])
        try store.importData(JSONFiles.encoder().encode(bundle))
        XCTAssertEqual(store.paths[0].name, "Lab")
        XCTAssertEqual(store.paths[0].identity, "Tinkerer")
        XCTAssertTrue(store.world.onboarded)
    }

    func testLoadReadsTheMirrorWhenLocalIsGone() throws {
        let local = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mirror = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: mirror, withIntermediateDirectories: true)
        let first = Store(directory: local, mirrorDirectory: mirror)
        first.add(try PathDraft(name: "Magic", identity: "Magician", glyph: "wand.and.stars", role: .hobby, milestones: ["The double lift"],
                                nodes: []).begun(on: first.today))
        try FileManager.default.removeItem(at: local.appendingPathComponent("world.json"))
        let second = Store(directory: local, mirrorDirectory: mirror)
        XCTAssertEqual(second.paths.map(\.name), ["Magic"])
        XCTAssertTrue(second.world.onboarded)
    }

    func testKeepACopyRestoresAnExistingMirror() throws {
        let local = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mirror = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: mirror, withIntermediateDirectories: true)
        let first = Store(directory: local, mirrorDirectory: mirror)
        first.add(try PathDraft(name: "Car", identity: "Owner", glyph: "car", role: .craft, milestones: ["It starts"],
                                nodes: []).begun(on: first.today))
        let empty = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let second = Store(directory: empty)
        XCTAssertTrue(second.paths.isEmpty)
        try second.keepACopy(in: mirror)
        XCTAssertEqual(second.paths.map(\.name), ["Car"])
    }
}
