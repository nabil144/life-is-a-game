import XCTest
@testable import LifeEngine

final class AppLaunchTests: XCTestCase {
    func testShortcutNameIsOneEncodedQueryValue() throws {
        let name = "Workout & stretch #1 + café"
        let launch = AppLaunch(kind: .shortcut, target: name)
        let parts = try XCTUnwrap(URLComponents(url: try XCTUnwrap(launch.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.scheme, "shortcuts")
        XCTAssertEqual(parts.host, "run-shortcut")
        XCTAssertEqual(parts.queryItems, [URLQueryItem(name: "name", value: name)])
    }
    func testLinksAreValidatedWithoutRewritingAppSchemes() {
        XCTAssertEqual(AppLaunch(kind: .appLink, target: "  exampleapp://home  ").url?.absoluteString, "exampleapp://home")
        for invalid in ["", "Just an app name", "https://", "file:///tmp/file", "javascript:alert(1)", "data:text/plain,hi"] {
            XCTAssertNil(AppLaunch(kind: .appLink, target: invalid).url, invalid)
        }
        XCTAssertNil(AppLaunch(kind: .shortcut, target: "  ").url)
    }
    func testOldNodesDecodeAndLauncherSurvivesBackupRoundTrip() throws {
        var node = Node(kind: .practice, title: "Practice", createdOn: Day(Date()))
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        let legacy = try encoder.encode(node)
        XCTAssertNil(try decoder.decode(Node.self, from: legacy).appLaunch)
        node.appLaunch = AppLaunch(kind: .shortcut, name: "Workout", target: "Open Workout")
        let restored = try decoder.decode(Node.self, from: encoder.encode(node))
        XCTAssertEqual(restored.appLaunch, node.appLaunch)
        XCTAssertEqual(restored.state, .todo)
        node.appLaunch = nil
        XCTAssertNil(try decoder.decode(Node.self, from: encoder.encode(node)).appLaunch)
    }
}
