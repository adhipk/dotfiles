import XCTest
@testable import ExtensionKit

final class ExtensionKitTests: XCTestCase {
    var root: URL!
    var store: UtilityStore!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("utility tests \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = UtilityStore(root: root.appendingPathComponent("registry"))
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func package(_ id: String = "test.utility", version: String = "1.0.0", script: String = "printf '%s' \"$1\"") throws -> URL {
        let dir = root.appendingPathComponent("\(id)-\(version).dotutility")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try Data("#!/bin/sh\n\(script)\n".utf8).write(to: dir.appendingPathComponent("bin/tool"))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.appendingPathComponent("bin/tool").path)
        let manifest: [String: Any] = ["schemaVersion":1,"id":id,"name":"Test","version":version,"summary":"Fixture",
            "settings":[["key":"text","title":"Text","kind":"string","defaultValue":"literal $(touch nope) `id` ; spaces"]],
            "commands":[["id":"echo","title":"Echo","invocation":["executable":"bin/tool","arguments":["{setting:text}"]]]],
            "services":[["id":"worker","title":"Worker","invocation":["executable":"bin/tool"]]]]
        try JSONSerialization.data(withJSONObject: manifest).write(to: dir.appendingPathComponent("extension.json"))
        return dir
    }
    func edit(_ path: URL, _ body: (inout [String: Any]) -> Void) throws {
        let url = path.appendingPathComponent("extension.json")
        var value = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        body(&value); try JSONSerialization.data(withJSONObject: value).write(to: url)
    }
    func testInstallDisabledAndRoundTrip() throws {
        let utility = try store.install(from: package())
        XCTAssertFalse(utility.enabled)
        XCTAssertEqual(try UtilityStore(root: store.root).list().first?.manifest, utility.manifest)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: store.package(utility).appendingPathComponent("bin/tool").path))
    }
    func testDuplicateVersionDoesNotChangeRegistry() throws {
        let path = try package(); _ = try store.install(from: path)
        XCTAssertThrowsError(try store.install(from: path)); XCTAssertEqual(try store.list().count, 1)
    }
    func testCorruptRegistryCannotEscapePackageDirectory() throws {
        _ = try store.install(from: package())
        let file = store.root.appendingPathComponent("registry.json")
        var registry = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
        var utilities = registry["utilities"] as! [[String: Any]]
        utilities[0]["previousVersion"] = "../../outside"
        registry["utilities"] = utilities
        try JSONSerialization.data(withJSONObject: registry).write(to: file)
        XCTAssertThrowsError(try store.list())
        XCTAssertThrowsError(try store.rollback("test.utility"))
        XCTAssertThrowsError(try store.remove("test.utility"))
    }
    func testUpgradeAndRollbackPreserveSettings() throws {
        _ = try store.install(from: package())
        try store.configure("test.utility", key: "text", value: "custom")
        try store.change("test.utility") { $0.enabled = true }
        let next = try store.install(from: package(version: "2.0.0"))
        XCTAssertTrue(next.enabled); XCTAssertEqual(next.settings["text"], "custom")
        XCTAssertEqual(next.previousVersion, "1.0.0")
        try store.rollback(next.id)
        XCTAssertEqual(try store.list().first?.activeVersion, "1.0.0")
        XCTAssertEqual(try store.list().first?.settings["text"], "custom")
    }
    func testFailedUpgradePreservesPreviousVersion() throws {
        _ = try store.install(from: package())
        let bad = try package(version: "2.0.0")
        try edit(bad) { $0["schemaVersion"] = 999 }
        XCTAssertThrowsError(try store.install(from: bad))
        XCTAssertEqual(try store.list().first?.activeVersion, "1.0.0")
    }
    func testRemovePreservesUserData() throws {
        let utility = try store.install(from: package())
        let data = store.dataDirectory(utility.id)
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: data.appendingPathComponent("notes"))
        try store.remove(utility.id)
        XCTAssertTrue(try store.list().isEmpty)
        XCTAssertEqual(try String(contentsOf: data.appendingPathComponent("notes")), "keep")
    }
    func testTraversalAndSymlinkRejected() throws {
        let path = try package()
        try edit(path) { $0["id"] = "../../escape" }
        XCTAssertThrowsError(try store.install(from: path))
        let other = try package("test.other")
        try FileManager.default.createSymbolicLink(at: other.appendingPathComponent("escape"), withDestinationURL: root)
        XCTAssertThrowsError(try store.install(from: other))
    }
    func testExecutableCannotEscapePackage() throws {
        let path = try package()
        try edit(path) { $0["commands"] = [["id":"escape","title":"Escape","invocation":["executable":"../../bin/sh"]]] }
        XCTAssertThrowsError(try store.install(from: path))
    }
    func testDuplicateActionsRejected() throws {
        let path = try package()
        try edit(path) { value in let commands = value["commands"] as! [[String: Any]]; value["commands"] = commands + commands }
        XCTAssertThrowsError(try store.install(from: path))
    }
    func testSettingValidation() throws {
        let path = try package()
        try edit(path) { $0["settings"] = [["key":"count","title":"Count","kind":"integer","defaultValue":"1"]] }
        _ = try store.install(from: path)
        XCTAssertThrowsError(try store.configure("test.utility", key: "count", value: "no"))
        XCTAssertEqual(try store.list().first?.settings["count"], "1")
    }
    func testShortcutConflictIsTransactional() throws {
        let a = try store.install(from: package("test.a"))
        let b = try store.install(from: package("test.b"))
        let binding = KeyBinding(keyCode: 40, modifiers: 2048)
        try store.change(a.id) { $0.enabled = true; $0.shortcuts["echo"] = binding }
        XCTAssertThrowsError(try store.change(b.id) { $0.enabled = true; $0.shortcuts["echo"] = binding })
        XCTAssertFalse(try store.list().first(where: { $0.id == b.id })!.enabled)
        try store.change(a.id) { $0.enabled = false }
        XCTAssertNoThrow(try store.change(b.id) { $0.enabled = true; $0.shortcuts["echo"] = binding })
    }
    func testLiteralArgumentsAndPathsWithSpaces() async throws {
        let utility = try store.install(from: package())
        let result = try await ManagedJob.run(utility.manifest.commands[0].invocation, context: ExecutionContext(utility: utility, store: store))
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.output, utility.settings["text"])
    }
    func testSettingsAreNotExpandedRecursively() throws {
        _ = try store.install(from: package())
        try store.configure("test.utility", key: "text", value: "{data} {tool:missing} {home}")
        let utility = try store.list()[0]
        let context = ExecutionContext(utility: utility, store: store)
        XCTAssertEqual(try context.expand("prefix {setting:text} {data}"), "prefix {data} {tool:missing} {home} " + context.data.path)
    }
    func testMissingToolReported() throws {
        let utility = try store.install(from: package())
        XCTAssertThrowsError(try ExecutionContext(utility: utility, store: store, toolDirectories: []).resolve(Invocation(tool: "missing")))
    }
    func testFailedExitAndStderrPreserved() async throws {
        let utility = try store.install(from: package(script: "printf 'problem' >&2; exit 7"))
        let result = try await ManagedJob.run(utility.manifest.commands[0].invocation, context: ExecutionContext(utility: utility, store: store))
        XCTAssertEqual(result.status, 7); XCTAssertEqual(result.error, "problem")
    }
    func testTimeoutStopsProcess() async throws {
        let utility = try store.install(from: package(script: "while :; do :; done"))
        var invocation = utility.manifest.commands[0].invocation; invocation.timeoutSeconds = 0.1
        do { _ = try await ManagedJob.run(invocation, context: ExecutionContext(utility: utility, store: store)); XCTFail("Expected timeout") }
        catch { XCTAssertTrue(error.localizedDescription.contains("timed out")) }
    }
    func testCancellationStopsProcess() async throws {
        let utility = try store.install(from: package(script: "while :; do :; done"))
        let task = Task { try await ManagedJob.run(utility.manifest.commands[0].invocation, context: ExecutionContext(utility: utility, store: store)) }
        try await Task.sleep(nanoseconds: 80_000_000); task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
    }
    func testCancellationAllowsGracefulShutdown() async throws {
        let utility = try store.install(from: package(script: "trap 'printf stopped > \"$DOTFILES_UTILITY_DATA/stopped\"; exit 0' TERM\nwhile :; do :; done"))
        let task = Task { try await ManagedJob.run(utility.manifest.commands[0].invocation, context: ExecutionContext(utility: utility, store: store)) }
        try await Task.sleep(nanoseconds: 80_000_000); task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(try String(contentsOf: store.dataDirectory(utility.id).appendingPathComponent("stopped")), "stopped")
    }
    func testOutputLimit() async throws {
        let utility = try store.install(from: package(script: "while :; do printf 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'; done"))
        do { _ = try await ManagedJob.run(utility.manifest.commands[0].invocation, context: ExecutionContext(utility: utility, store: store)); XCTFail("Expected limit") }
        catch { XCTAssertTrue(error.localizedDescription.contains("output limit")) }
    }
    func testServiceUsesArgvAndOwnedLabel() throws {
        let utility = try store.install(from: package())
        let controller = UtilityServices(agents: root.appendingPathComponent("agents"))
        let definition = try controller.definition(utility.manifest.services![0], context: ExecutionContext(utility: utility, store: store))
        XCTAssertEqual(definition["KeepAlive"] as? Bool, false)
        XCTAssertEqual(definition["RunAtLoad"] as? Bool, true)
        let arguments = definition["ProgramArguments"] as! [String]
        XCTAssertTrue(arguments[0].hasSuffix("dotfiles-service-runner"))
        XCTAssertTrue(arguments[4].contains("utility tests "))
        XCTAssertNil(definition["StandardOutPath"])
        XCTAssertNotEqual(controller.label("a.b", "c"), controller.label("a", "b.c"))
    }
    func testFailedServiceStartRemovesRegistration() async throws {
        let utility = try store.install(from: package())
        let agents = root.appendingPathComponent("agents")
        let controller = UtilityServices(agents: agents, supervisor: URL(fileURLWithPath: "/usr/bin/true")) { args, _ in ExecutionResult(status: args.first == "bootstrap" ? 1 : 0, output: "", error: "fixture failure") }
        do { try await controller.start(utility.manifest.services![0], context: ExecutionContext(utility: utility, store: store)); XCTFail("Expected failure") }
        catch { XCTAssertTrue(error.localizedDescription.contains("fixture failure")) }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: agents.path), [])
    }
    func testFailedServiceStopPreservesRegistration() async throws {
        let utility = try store.install(from: package())
        let agents = root.appendingPathComponent("agents")
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        let controller = UtilityServices(agents: agents, supervisor: URL(fileURLWithPath: "/usr/bin/true")) { args, _ in
            ExecutionResult(status: args.first == "bootout" ? 1 : 0, output: "state = running", error: "denied")
        }
        let file = agents.appendingPathComponent(controller.label(utility.id, "worker") + ".plist")
        try Data("original".utf8).write(to: file)
        let context = ExecutionContext(utility: utility, store: store)
        do { try await controller.stop(utility.manifest.services![0], context: context); XCTFail("Expected stop failure") }
        catch { XCTAssertTrue(error.localizedDescription.contains("denied")) }
        do { try await controller.start(utility.manifest.services![0], context: context); XCTFail("Expected restart failure") }
        catch { XCTAssertTrue(error.localizedDescription.contains("denied")) }
        XCTAssertEqual(try String(contentsOf: file), "original")
    }
    func testUnknownServiceTelemetryPreservesRegistration() async throws {
        let utility = try store.install(from: package())
        let agents = root.appendingPathComponent("agents")
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        let controller = UtilityServices(agents: agents, supervisor: URL(fileURLWithPath: "/usr/bin/true")) { _, _ in
            ExecutionResult(status: 1, output: "", error: "Operation not permitted")
        }
        let file = agents.appendingPathComponent(controller.label(utility.id, "worker") + ".plist")
        try Data("original".utf8).write(to: file)
        let context = ExecutionContext(utility: utility, store: store), service = utility.manifest.services![0]
        do { try await controller.stop(service, context: context); XCTFail("Expected unknown stop") }
        catch { XCTAssertTrue(error.localizedDescription.contains("registration preserved")) }
        XCTAssertEqual(try String(contentsOf: file), "original")
        do { _ = try await controller.status(service, context: context); XCTFail("Expected unknown status") }
        catch { XCTAssertTrue(error.localizedDescription.contains("status is unknown")) }
    }
    func testExplicitMissingServiceAllowsCleanupAndStoppedStatus() async throws {
        let utility = try store.install(from: package())
        let agents = root.appendingPathComponent("agents")
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        let controller = UtilityServices(agents: agents, supervisor: URL(fileURLWithPath: "/usr/bin/true")) { args, _ in
            let label = args.last!.split(separator: "/").last!
            return ExecutionResult(status: 113, output: "", error: "Could not find service \"\(label)\" in domain for user gui: \(getuid())\n")
        }
        let file = agents.appendingPathComponent(controller.label(utility.id, "worker") + ".plist")
        try Data("original".utf8).write(to: file)
        let context = ExecutionContext(utility: utility, store: store), service = utility.manifest.services![0]
        try await controller.stop(service, context: context)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        let status = try await controller.status(service, context: context)
        XCTAssertEqual(status, "Stopped")
    }
    func testMissingDifferentServiceDoesNotProveAbsence() async throws {
        let utility = try store.install(from: package())
        let controller = UtilityServices(agents: root.appendingPathComponent("agents")) { _, _ in
            ExecutionResult(status: 113, output: "", error: "Could not find service \"another.label\" in domain for user gui: \(getuid())")
        }
        do { _ = try await controller.status(utility.manifest.services![0], context: ExecutionContext(utility: utility, store: store)); XCTFail("Expected unknown status") }
        catch { XCTAssertTrue(error.localizedDescription.contains("status is unknown")) }
    }
    func testServiceTransportFailureRemovesNewRegistration() async throws {
        let utility = try store.install(from: package())
        let agents = root.appendingPathComponent("agents")
        let controller = UtilityServices(agents: agents, supervisor: URL(fileURLWithPath: "/usr/bin/true")) { args, _ in
            if args.first == "bootstrap" { throw UtilityError("launchctl timed out") }
            return ExecutionResult(status: 0, output: "", error: "")
        }
        do { try await controller.start(utility.manifest.services![0], context: ExecutionContext(utility: utility, store: store)); XCTFail("Expected failure") }
        catch { XCTAssertTrue(error.localizedDescription.contains("timed out")) }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: agents.path), [])
    }
    func testSDKAtomicState() throws {
        let ctx = try UtilityContext(environment: ["DOTFILES_UTILITY_ID":"test.sdk", "DOTFILES_UTILITY_DATA":root.path, "DOTFILES_UTILITY_SETTINGS":"{\"example\":\"yes\"}"])
        XCTAssertEqual(ctx.settings["example"], "yes")
        try ctx.writeState(["count":1], name: "state.json")
        XCTAssertEqual(try ctx.readState([String:Int].self, name: "state.json"), ["count":1])
        XCTAssertThrowsError(try ctx.writeState(1, name: "../bad"))
    }
}
