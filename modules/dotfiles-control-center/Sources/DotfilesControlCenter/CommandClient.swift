import Foundation

protocol CommandRunning: Sendable {
    func run(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL
    ) async throws -> CommandOutput
}

struct FoundationProcessRunner: CommandRunning {
    func run(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL
    ) async throws -> CommandOutput {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let captureDirectory = fileManager.temporaryDirectory
                .appendingPathComponent("dotfiles-control-center-\(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(at: captureDirectory, withIntermediateDirectories: false)
            defer { try? fileManager.removeItem(at: captureDirectory) }

            let stdoutURL = captureDirectory.appendingPathComponent("stdout")
            let stderrURL = captureDirectory.appendingPathComponent("stderr")
            guard fileManager.createFile(atPath: stdoutURL.path, contents: nil),
                  fileManager.createFile(atPath: stderrURL.path, contents: nil) else {
                throw CommandClientError.captureSetupFailed
            }

            let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
            let stderrHandle = try FileHandle(forWritingTo: stderrURL)
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments
            process.currentDirectoryURL = currentDirectoryURL
            process.standardOutput = stdoutHandle
            process.standardError = stderrHandle

            do {
                try process.run()
                process.waitUntilExit()
                try stdoutHandle.close()
                try stderrHandle.close()
            } catch {
                try? stdoutHandle.close()
                try? stderrHandle.close()
                throw error
            }

            return CommandOutput(
                stdout: try Data(contentsOf: stdoutURL),
                stderr: try Data(contentsOf: stderrURL),
                terminationStatus: process.terminationStatus
            )
        }.value
    }
}

struct ToolPaths: Equatable, Sendable {
    let module: URL
    let dependencies: URL
    let uninstall: URL

    static func live(environment: [String: String]) -> ToolPaths {
        let home = environment["HOME"] ?? NSHomeDirectory()
        func command(_ key: String, _ name: String) -> URL {
            URL(fileURLWithPath: environment[key] ?? "\(home)/bin/\(name)")
        }
        return ToolPaths(
            module: command("DOTFILES_MODULE_BIN", "dotfiles-module"),
            dependencies: command("DOTFILES_DEPS_BIN", "dotfiles-deps"),
            uninstall: command("DOTFILES_UNINSTALL_BIN", "dotfiles-uninstall")
        )
    }
}

struct AppEnvironment: Equatable, Sendable {
    let tools: ToolPaths
    let workingDirectory: URL

    static func live(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath
    ) -> AppEnvironment {
        let requestedDirectory = environment["DOTFILES_CONTROL_CENTER_CWD"] ?? currentDirectoryPath
        var isDirectory: ObjCBool = false
        let usable = FileManager.default.fileExists(atPath: requestedDirectory, isDirectory: &isDirectory)
            && isDirectory.boolValue
        let path = usable ? requestedDirectory : currentDirectoryPath
        return AppEnvironment(
            tools: .live(environment: environment),
            workingDirectory: URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        )
    }
}

enum CommandClientError: LocalizedError, Equatable {
    case captureSetupFailed
    case commandFailed(command: String, status: Int32, stderr: String)
    case invalidJSON(command: String, message: String, stderr: String)
    case unsupportedSchema(command: String, version: Int)
    case confirmationMismatch(expected: String)

    var errorDescription: String? {
        switch self {
        case .captureSetupFailed:
            return "Could not prepare private command output capture."
        case let .commandFailed(command, status, stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? "\(command) exited with status \(status)."
                : "\(command) exited with status \(status): \(detail)"
        case let .invalidJSON(command, message, stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? "\(command) returned invalid JSON: \(message)"
                : "\(command) returned invalid JSON: \(message). \(detail)"
        case let .unsupportedSchema(command, version):
            return "\(command) returned unsupported schema version \(version)."
        case let .confirmationMismatch(expected):
            return "Confirmation must exactly match \(expected)."
        }
    }
}

struct CommandClient: Sendable {
    let paths: ToolPaths
    let workingDirectory: URL
    let runner: any CommandRunning

    init(
        paths: ToolPaths,
        workingDirectory: URL,
        runner: any CommandRunning = FoundationProcessRunner()
    ) {
        self.paths = paths
        self.workingDirectory = workingDirectory
        self.runner = runner
    }

    func moduleStatus() async throws -> [ModuleStatus] {
        let output = try await invoke(paths.module, ["status", "--json"])
        return try decode([ModuleStatus].self, output: output, command: "dotfiles-module status")
    }

    func modulePlan(action: ModuleAction, moduleID: String) async throws -> ModulePlan {
        let output = try await invoke(paths.module, ["plan", action.rawValue, moduleID, "--json"])
        let plan = try decode(ModulePlan.self, output: output, command: "dotfiles-module plan")
        try requireSchema(plan.schemaVersion, command: "dotfiles-module plan")
        return plan
    }

    func executeModule(
        action: ModuleAction,
        moduleID: String,
        typedConfirmation: String,
        stateRoot: URL?
    ) async throws -> ModuleActionResult {
        if action.requiresExactModuleID, typedConfirmation != moduleID {
            throw CommandClientError.confirmationMismatch(expected: moduleID)
        }

        var arguments = [action.rawValue, moduleID]
        if action == .purge {
            arguments += ["--confirm", moduleID]
        }
        if let stateRoot {
            arguments += ["--state-root", stateRoot.path]
        }
        arguments.append("--json")

        let output = try await invoke(paths.module, arguments)
        let result = try decode(ModuleActionResult.self, output: output, command: "dotfiles-module \(action.rawValue)")
        try requireSchema(result.schemaVersion, command: "dotfiles-module \(action.rawValue)")
        return result
    }

    func dependencyStatus(check: Bool) async throws -> CommandOutcome<DependencyReport> {
        let action = check ? "check" : "status"
        let output = try await invoke(paths.dependencies, [action, "--json"], requireSuccess: false)
        let report = try decode(
            DependencyReport.self,
            output: output,
            command: "dotfiles-deps \(action)",
            requireSuccess: false
        )
        try requireSchema(report.schemaVersion, command: "dotfiles-deps \(action)")
        return CommandOutcome(
            value: report,
            terminationStatus: output.terminationStatus,
            stderr: output.stderrText
        )
    }

    func dependencySnapshot() async throws -> DependencySnapshot {
        let output = try await invoke(paths.dependencies, ["snapshot", "--json"])
        let snapshot = try decode(DependencySnapshot.self, output: output, command: "dotfiles-deps snapshot")
        try requireSchema(snapshot.schemaVersion, command: "dotfiles-deps snapshot")
        return snapshot
    }

    func systemUninstallPlan() async throws -> SystemUninstallPlan {
        let output = try await invoke(paths.uninstall, ["plan", "--json"])
        let plan = try decode(SystemUninstallPlan.self, output: output, command: "dotfiles-uninstall plan")
        try requireSchema(plan.schemaVersion, command: "dotfiles-uninstall plan")
        return plan
    }

    func executeSystemUninstall(
        plan: SystemUninstallPlan,
        typedConfirmation: String
    ) async throws -> SystemUninstallLedger {
        guard typedConfirmation == plan.confirmation else {
            throw CommandClientError.confirmationMismatch(expected: plan.confirmation)
        }
        let output = try await invoke(
            paths.uninstall,
            ["execute", "--confirm", plan.confirmation, "--json"]
        )
        let ledger = try decode(SystemUninstallLedger.self, output: output, command: "dotfiles-uninstall execute")
        try requireSchema(ledger.schemaVersion, command: "dotfiles-uninstall execute")
        return ledger
    }

    private func invoke(
        _ executableURL: URL,
        _ arguments: [String],
        requireSuccess: Bool = true
    ) async throws -> CommandOutput {
        let output = try await runner.run(
            executableURL: executableURL,
            arguments: arguments,
            currentDirectoryURL: workingDirectory
        )
        if requireSuccess, output.terminationStatus != 0 {
            throw CommandClientError.commandFailed(
                command: executableURL.lastPathComponent,
                status: output.terminationStatus,
                stderr: output.stderrText
            )
        }
        return output
    }

    private func decode<Value: Decodable>(
        _ type: Value.Type,
        output: CommandOutput,
        command: String,
        requireSuccess: Bool = true
    ) throws -> Value {
        do {
            let value = try JSONDecoder().decode(type, from: output.stdout)
            if requireSuccess, output.terminationStatus != 0 {
                throw CommandClientError.commandFailed(
                    command: command,
                    status: output.terminationStatus,
                    stderr: output.stderrText
                )
            }
            return value
        } catch let error as CommandClientError {
            throw error
        } catch {
            if output.terminationStatus != 0 {
                throw CommandClientError.commandFailed(
                    command: command,
                    status: output.terminationStatus,
                    stderr: output.stderrText
                )
            }
            throw CommandClientError.invalidJSON(
                command: command,
                message: error.localizedDescription,
                stderr: output.stderrText
            )
        }
    }

    private func requireSchema(_ version: Int, command: String) throws {
        guard version == 1 else {
            throw CommandClientError.unsupportedSchema(command: command, version: version)
        }
    }
}
