import XCTest
@testable import ExtensionKit

final class DependencySetupTests: XCTestCase {
    func testReportsNestedMissingToolsAndSystemExecutableOnce() throws {
        let manifest = try JSONDecoder().decode(UtilityManifest.self, from: Data(#"""
        {"schemaVersion":1,"id":"test.dependencies","name":"Dependencies","version":"1.0.0","summary":"Test",
         "commands":[{"id":"action","title":"Action","invocation":{"tool":"printf","arguments":["{tool:dotfiles-nonexistent-test-tool}","{tool:printf}"],"environment":{"TEST":"{tool:dotfiles-nonexistent-test-tool}"}}}]}
        """#.utf8))
        let utility = InstalledUtility(manifest: manifest, activeVersion: "1.0.0", enabled: false,
                                       settings: [:], shortcuts: [:], runningServices: [])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let dependencies = DependencySetup.dependencies(utility, store: UtilityStore(root: root))
        XCTAssertEqual(dependencies.map(\.name), ["dotfiles-nonexistent-test-tool", "printf"])
        XCTAssertFalse(dependencies[0].available)
        XCTAssertTrue(dependencies[1].available)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }
}
