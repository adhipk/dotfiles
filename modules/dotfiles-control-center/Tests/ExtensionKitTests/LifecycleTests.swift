import XCTest
@testable import ExtensionKit

private actor LifecycleTransport {
    var calls: [String] = []
    var rejectedVersion: String?
    var rejectStop = false
    var running = false
    func reject(_ version: String?) { rejectedVersion = version }
    func stopFailure(_ value: Bool) { rejectStop = value }
    func history() -> [String] { calls }
    func run(_ args: [String], _ context: ExecutionContext) throws -> ExecutionResult {
        let command = args[0]
        calls.append("\(command)/\(context.utility.activeVersion)/\(context.utility.settings["name"] ?? "")")
        if command == "print" { return ExecutionResult(status: running ? 0 : 1, output: running ? "state = running" : "", error: "") }
        if command == "bootout" {
            if rejectStop && running { return ExecutionResult(status: 1, output: "", error: "stop denied") }
            running = false; return ExecutionResult(status: 0, output: "", error: "")
        }
        if command == "bootstrap" {
            if context.utility.activeVersion == rejectedVersion { return ExecutionResult(status: 1, output: "", error: "candidate failed") }
            running = true
        }
        return ExecutionResult(status: 0, output: "", error: "")
    }
}

final class LifecycleTests: XCTestCase {
    var directory: URL!
    var store: UtilityStore!
    private var transport: LifecycleTransport!
    var lifecycle: UtilityLifecycle!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("lifecycle tests \(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = UtilityStore(root: directory.appendingPathComponent("store with spaces"))
        transport = LifecycleTransport()
        let transport = self.transport!
        let services = UtilityServices(agents: directory.appendingPathComponent("agents"), supervisor: URL(fileURLWithPath: "/usr/bin/true")) {
            try await transport.run($0, $1)
        }
        lifecycle = UtilityLifecycle(store: store, services: services)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    func package(_ version: String = "1.0.0", command: [String: Any]? = nil) throws -> URL {
        let path = directory.appendingPathComponent(version + ".dotutility")
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        let manifest: [String: Any] = ["schemaVersion": 1, "id": "test.lifecycle", "version": version, "name": "Lifecycle", "summary": "Fixture",
            "commands": [["id": "hello", "title": "Hello", "invocation": command ?? ["tool": "printf", "arguments": ["%s", "{setting:name}"]]]],
            "services": [["id": "worker", "title": "Worker", "invocation": ["tool": "true"]]],
            "settings": [["key": "name", "title": "Name", "kind": "string", "defaultValue": "original"]]]
        try JSONSerialization.data(withJSONObject: manifest).write(to: path.appendingPathComponent("extension.json"))
        return path
    }
    func running() async throws -> InstalledUtility {
        let record = try await lifecycle.install(from: package())
        try await lifecycle.enable(record.id, true)
        try await lifecycle.service(record.id, serviceID: "worker", start: true)
        return try store.list()[0]
    }
    func journal(before: [InstalledUtility], operation: String, candidate: UtilityManifest? = nil, committed: Bool = false) throws {
        struct FixtureJournal: Encodable {
            let schemaVersion = 1
            let servicesTouched = true
            let operation: String
            let committed: Bool
            let before: [InstalledUtility]
            let candidate: UtilityManifest?
        }
        try JSONEncoder().encode(FixtureJournal(operation: operation, committed: committed, before: before, candidate: candidate))
            .write(to: store.root.appendingPathComponent("lifecycle.json"), options: .atomic)
    }
    func testFailedActivationRestoresSettingsAndRunningOldService() async throws {
        let original = try await running()
        try await lifecycle.configure(original.id, key: "name", value: "custom")
        await transport.reject("2.0.0")
        do { _ = try await lifecycle.install(from: package("2.0.0")); XCTFail("Expected failed update") }
        catch { XCTAssertTrue(error.localizedDescription.contains("candidate failed")) }
        let restored = try store.list()[0]
        XCTAssertEqual(restored.activeVersion, "1.0.0")
        XCTAssertEqual(restored.settings["name"], "custom")
        XCTAssertEqual(restored.runningServices, ["worker"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.root.appendingPathComponent("packages/test.lifecycle/2.0.0").path))
        let history = await transport.history()
        XCTAssertEqual(history.last, "bootstrap/1.0.0/custom")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.root.appendingPathComponent("lifecycle.json").path))
        // A repaired version can retry the exact same candidate.
        await transport.reject(nil)
        let retry = try await lifecycle.install(from: directory.appendingPathComponent("2.0.0.dotutility"))
        XCTAssertEqual(retry.activeVersion, "2.0.0")
    }
    func testInterruptedUpdateBeforeRegistryWriteRemovesCandidateAndRestartsOld() async throws {
        let original = try await running()
        let source = try package("2.0.0")
        let candidate = try UtilityManifest.load(from: source)
        let target = store.root.appendingPathComponent("packages/test.lifecycle/2.0.0")
        try FileManager.default.copyItem(at: source, to: target)
        try journal(before: [original], operation: "install/test.lifecycle", candidate: candidate)
        let second = UtilityLifecycle(store: UtilityStore(root: store.root), services: lifecycle.services)
        try await second.recover()
        XCTAssertEqual(try store.list()[0], original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        let history = await transport.history()
        XCTAssertEqual(history.last, "bootstrap/1.0.0/original")
    }
    func testInterruptedUpdateAfterRegistryWriteRestoresOld() async throws {
        let original = try await running()
        let source = try package("2.0.0")
        try journal(before: [original], operation: "install/test.lifecycle", candidate: UtilityManifest.load(from: source))
        _ = try store.install(from: source)
        try await lifecycle.recover()
        XCTAssertEqual(try store.list()[0], original)
    }
    func testFailedRollbackRestoresNewVersionAndServices() async throws {
        let original = try await running()
        _ = try await lifecycle.install(from: package("2.0.0"))
        await transport.reject("1.0.0")
        do { try await lifecycle.rollback(original.id); XCTFail("Expected rollback failure") } catch {}
        XCTAssertEqual(try store.list()[0].activeVersion, "2.0.0")
        let history = await transport.history()
        XCTAssertEqual(history.last, "bootstrap/2.0.0/original")
    }
    func testCommittedRemoveFinishesCleanupAndKeepsData() async throws {
        let original = try await running()
        let data = store.dataDirectory(original.id)
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: data.appendingPathComponent("user.txt"))
        try await lifecycle.services.stop(original.manifest.services![0], context: ExecutionContext(utility: original, store: store))
        try store.remove(original.id, deletePackages: false)
        try journal(before: [original], operation: "remove/test.lifecycle", committed: true)
        try await lifecycle.recover()
        XCTAssertTrue(try store.list().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.package(original).path))
        XCTAssertEqual(try String(contentsOf: data.appendingPathComponent("user.txt")), "keep")
    }
    func testUncommittedRemoveRestoresCodeAndRegistration() async throws {
        let original = try await running()
        try journal(before: [original], operation: "remove/test.lifecycle")
        try store.remove(original.id, deletePackages: false)
        try await lifecycle.recover()
        XCTAssertEqual(try store.list()[0], original)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.package(original).path))
    }
    func testConcurrentActionKeepsDisableFromRacingExecution() async throws {
        let record = try await lifecycle.install(from: package(command: ["tool": "sleep", "arguments": ["0.3"]]))
        try await lifecycle.enable(record.id, true)
        let action = Task { try await self.lifecycle.run(record.id, command: "hello") }
        try await Task.sleep(nanoseconds: 80_000_000)
        let other = UtilityLifecycle(store: UtilityStore(root: store.root), services: lifecycle.services)
        let disable = Task { try await other.enable(record.id, false) }
        try await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertTrue(try store.list()[0].enabled)
        let result = try await action.value
        XCTAssertEqual(result.status, 0)
        try await disable.value
        XCTAssertFalse(try store.list()[0].enabled)
    }
    func testStopFailureKeepsJournalAndBlocksRemovalUntilRecoverable() async throws {
        let original = try await running()
        await transport.stopFailure(true)
        do { try await lifecycle.remove(original.id); XCTFail("Expected refusal") }
        catch { XCTAssertTrue(error.localizedDescription.contains("Recovery needs attention")) }
        XCTAssertEqual(try store.list()[0], original)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.root.appendingPathComponent("lifecycle.json").path))
        await transport.stopFailure(false)
        try await lifecycle.recover()
        try await lifecycle.remove(original.id)
        XCTAssertTrue(try store.list().isEmpty)
    }
    func testRejectedRetainedInstallDoesNotDeleteOldVersion() async throws {
        let original = try await running()
        _ = try await lifecycle.install(from: package("2.0.0"))
        _ = try await lifecycle.install(from: package("3.0.0"))
        do { _ = try await lifecycle.install(from: directory.appendingPathComponent("1.0.0.dotutility")); XCTFail("Expected retained version rejection") } catch {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.package(original).path))
        XCTAssertEqual(try store.list()[0].activeVersion, "3.0.0")
    }
    func testInvalidSettingAndShortcutDoNotRestartServices() async throws {
        let original = try await running()
        let history = await transport.history()
        do { try await lifecycle.configure(original.id, key: "missing", value: "bad"); XCTFail("Expected setting refusal") } catch {}
        do { try await lifecycle.shortcut(original.id, command: "missing", binding: KeyBinding(keyCode: 40, modifiers: 2048)); XCTFail("Expected shortcut refusal") } catch {}
        let after = await transport.history()
        XCTAssertEqual(after, history)
    }
    func testStaleReviewedActionCannotRunReplacement() async throws {
        let original = try await lifecycle.install(from: package())
        try await lifecycle.enable(original.id, true)
        let reviewed = try store.list()[0]
        try await lifecycle.configure(original.id, key: "name", value: "replacement")
        do { _ = try await lifecycle.run(original.id, command: "hello", confirmed: true, reviewed: reviewed); XCTFail("Expected stale approval refusal") }
        catch { XCTAssertTrue(error.localizedDescription.contains("Review the action again")) }
    }
    func testStaleHotkeyIsRejectedInsideLease() async throws {
        let original = try await lifecycle.install(from: package())
        try await lifecycle.enable(original.id, true)
        let binding = KeyBinding(keyCode: 40, modifiers: 2048)
        try await lifecycle.shortcut(original.id, command: "hello", binding: binding)
        try await lifecycle.shortcut(original.id, command: "hello", binding: nil)
        do { _ = try await lifecycle.run(original.id, command: "hello", hotkey: binding); XCTFail("Expected stale hotkey refusal") }
        catch { XCTAssertTrue(error.localizedDescription.contains("Shortcut changed")) }
    }
    func testInterruptedStagingIsCleanedWithoutTouchingUserData() async throws {
        let original = try await running()
        let stage = store.root.appendingPathComponent("staging-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
        let other = store.root.appendingPathComponent("staging-user-notes")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        try journal(before: [original], operation: "install/test.lifecycle")
        try await lifecycle.recover()
        XCTAssertFalse(FileManager.default.fileExists(atPath: stage.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.path))
    }

}
