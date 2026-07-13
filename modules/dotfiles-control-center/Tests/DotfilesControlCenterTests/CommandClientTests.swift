import Foundation
import XCTest
@testable import DotfilesControlCenter

final class CommandClientTests: XCTestCase {
    func testModulePlanUsesExplicitArgumentsAndPreservesWorkingDirectory() async throws {
        let runner = RecordingRunner(outputs: [try fixtureOutput("module-plan")])
        let client = testClient(runner: runner)

        let plan = try await client.modulePlan(action: .purge, moduleID: "alpha")
        let invocations = await runner.invocations

        XCTAssertEqual(plan.operation, "module-purge")
        XCTAssertEqual(
            invocations,
            [
                .init(
                    executableURL: URL(fileURLWithPath: "/test/bin/dotfiles-module"),
                    arguments: ["plan", "purge", "alpha", "--json"],
                    currentDirectoryURL: URL(fileURLWithPath: "/test/workspace", isDirectory: true)
                ),
            ]
        )
    }

    func testPurgeRequiresExactIDAndForwardsBackendConfirmationAndStateRoot() async throws {
        let runner = RecordingRunner(outputs: [try fixtureOutput("module-result")])
        let client = testClient(runner: runner)

        do {
            _ = try await client.executeModule(
                action: .purge,
                moduleID: "alpha",
                typedConfirmation: "wrong",
                stateRoot: URL(fileURLWithPath: "/test/state", isDirectory: true)
            )
            XCTFail("Expected exact-ID confirmation failure")
        } catch let error as CommandClientError {
            XCTAssertEqual(error, .confirmationMismatch(expected: "alpha"))
        }
        let invocationsBeforeConfirmation = await runner.invocations
        XCTAssertTrue(invocationsBeforeConfirmation.isEmpty)

        let result = try await client.executeModule(
            action: .purge,
            moduleID: "alpha",
            typedConfirmation: "alpha",
            stateRoot: URL(fileURLWithPath: "/test/state", isDirectory: true)
        )

        XCTAssertEqual(result.status, "complete")
        let invocations = await runner.invocations
        XCTAssertEqual(
            invocations.last?.arguments,
            ["purge", "alpha", "--confirm", "alpha", "--state-root", "/test/state", "--json"]
        )
    }

    func testUninstallAlsoRequiresExactIDWithoutInventingBackendFlag() async throws {
        let uninstallResult = CommandOutput(
            stdout: Data(
                String(data: try fixtureData("module-result"), encoding: .utf8)!
                    .replacingOccurrences(of: "module-purge", with: "module-uninstall")
                    .utf8
            ),
            stderr: Data(),
            terminationStatus: 0
        )
        let runner = RecordingRunner(outputs: [uninstallResult])
        let client = testClient(runner: runner)

        _ = try await client.executeModule(
            action: .uninstall,
            moduleID: "alpha",
            typedConfirmation: "alpha",
            stateRoot: nil
        )

        let invocations = await runner.invocations
        XCTAssertEqual(invocations.last?.arguments, ["uninstall", "alpha", "--json"])
    }

    func testDependencyCheckDecodesDiagnosticJSONOnNonzeroExit() async throws {
        let runner = RecordingRunner(outputs: [
            try fixtureOutput("deps-check-error", status: 17, stderr: "brew failed\n"),
        ])
        let client = testClient(runner: runner)

        let outcome = try await client.dependencyStatus(check: true)

        XCTAssertEqual(outcome.terminationStatus, 17)
        XCTAssertEqual(outcome.value.managerErrors, ["brew is unavailable"])
        XCTAssertEqual(outcome.stderr, "brew failed\n")
        let invocations = await runner.invocations
        XCTAssertEqual(invocations.last?.arguments, ["check", "--json"])
    }

    func testSnapshotFailureWithoutJSONSurfacesCommandError() async throws {
        let runner = RecordingRunner(outputs: [
            CommandOutput(stdout: Data(), stderr: Data("inventory incomplete".utf8), terminationStatus: 9),
        ])
        let client = testClient(runner: runner)

        do {
            _ = try await client.dependencySnapshot()
            XCTFail("Expected snapshot failure")
        } catch let error as CommandClientError {
            guard case let .commandFailed(command, status, stderr) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(command, "dotfiles-deps")
            XCTAssertEqual(status, 9)
            XCTAssertEqual(stderr, "inventory incomplete")
        }
    }

    func testSystemExecutionRequiresPlanConfirmationAndUsesExactArgv() async throws {
        let decoder = JSONDecoder()
        let plan = try decoder.decode(SystemUninstallPlan.self, from: fixtureData("uninstall-plan"))
        let runner = RecordingRunner(outputs: [try fixtureOutput("uninstall-ledger")])
        let client = testClient(runner: runner)

        do {
            _ = try await client.executeSystemUninstall(plan: plan, typedConfirmation: "wrong")
            XCTFail("Expected exact system confirmation failure")
        } catch let error as CommandClientError {
            XCTAssertEqual(error, .confirmationMismatch(expected: plan.confirmation))
        }
        let invocationsBeforeConfirmation = await runner.invocations
        XCTAssertTrue(invocationsBeforeConfirmation.isEmpty)

        let ledger = try await client.executeSystemUninstall(
            plan: plan,
            typedConfirmation: plan.confirmation
        )

        XCTAssertEqual(ledger.id, "20260713T120000Z-42")
        let invocations = await runner.invocations
        XCTAssertEqual(
            invocations.last?.arguments,
            ["execute", "--confirm", "REMOVE DOTFILES FROM /tmp/test-home", "--json"]
        )
    }

    func testFoundationRunnerPreservesCWDAndTreatsShellSyntaxLiterally() async throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("control-center-runner-test-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: directory) }

        let runner = FoundationProcessRunner()
        let pwd = try await runner.run(
            executableURL: URL(fileURLWithPath: "/bin/pwd"),
            arguments: [],
            currentDirectoryURL: directory
        )
        let reportedDirectory = String(data: pwd.stdout, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            reportedDirectory == directory.path || reportedDirectory == "/private\(directory.path)",
            "pwd should report the requested directory, allowing macOS's /var to /private/var canonicalization"
        )

        let literal = "$(touch should-not-exist)"
        let printed = try await runner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/printf"),
            arguments: ["%s", literal],
            currentDirectoryURL: directory
        )
        XCTAssertEqual(String(data: printed.stdout, encoding: .utf8), literal)
        XCTAssertFalse(fileManager.fileExists(atPath: directory.appendingPathComponent("should-not-exist").path))
    }
}
