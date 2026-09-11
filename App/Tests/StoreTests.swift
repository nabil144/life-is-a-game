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
}
