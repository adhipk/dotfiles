import Foundation
import CryptoKit

/// launchd owns persistent process lifetime. The app owns only these registrations.
public final class UtilityServices {
    public typealias Runner = ([String], ExecutionContext) async throws -> ExecutionResult
    private let agents: URL
    private let runner: Runner
    private let supervisor: URL
    public init(agents: URL? = nil, supervisor: URL? = nil, runner: Runner? = nil) {
        self.agents = agents ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        self.supervisor = supervisor ?? URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.resolvingSymlinksInPath().deletingLastPathComponent().appendingPathComponent("dotfiles-service-runner")
        self.runner = runner ?? { arguments, context in
            try await ManagedJob.run(Invocation(tool: "launchctl", arguments: arguments, timeoutSeconds: 10), context: context)
        }
    }
    public func label(_ utility: String, _ service: String) -> String {
        "dev.dotfiles.utility." + SHA256.hash(data: Data("\(utility)/\(service)".utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
    }
    private var domain: String { "gui/\(getuid())" }
    private func confirmsAbsence(_ result: ExecutionResult, label: String) -> Bool {
        guard result.status != 0 else { return false }
        // A nonzero print can also mean permission or transport failure. Only
        // launchctl's explicit missing-service diagnostic establishes absence.
        let missing = "Could not find service \"\(label)\" in domain for user gui: \(getuid())"
        return (result.output + "\n" + result.error).components(separatedBy: .newlines)
            .contains { $0.trimmingCharacters(in: .whitespaces) == missing }
    }
    public func definition(_ service: UtilityService, context: ExecutionContext) throws -> [String: Any] {
        let (executable, args, environment, cwd) = try context.resolve(service.invocation)
        let logRoot = context.data.appendingPathComponent("services/\(service.id)")
        return ["Label": label(context.utility.id, service.id), "ProgramArguments": [supervisor.path, "--logs", logRoot.path, "--"] + [executable.path] + args,
                "EnvironmentVariables": environment, "WorkingDirectory": cwd.path,
                "RunAtLoad": true, "KeepAlive": false, "ThrottleInterval": 10,
                "ExitTimeOut": 10]
    }
    public func start(_ service: UtilityService, context: ExecutionContext) async throws {
        guard FileManager.default.isExecutableFile(atPath: supervisor.path) else { throw UtilityError("Missing bundled service runner: \(supervisor.path)") }
        let definition = try definition(service, context: context)
        let logRoot = context.data.appendingPathComponent("services/\(service.id)")
        try FileManager.default.createDirectory(at: logRoot, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        let path = agents.appendingPathComponent(label(context.utility.id, service.id) + ".plist")
        // Only this host's deterministic label is touched. Repeated Start is a restart.
        try await stop(service, context: context)
        try PropertyListSerialization.data(fromPropertyList: definition, format: .xml, options: 0).write(to: path, options: .atomic)
        do {
            let result = try await runner(["bootstrap", domain, path.path], context)
            guard result.status == 0 else { throw UtilityError("Service could not start: \(result.error)") }
        } catch {
            let startError = error
            // A timed-out launchctl may already have registered the process.
            // Confirm removal before deleting its persistent registration.
            do { try await stop(service, context: context) }
            catch { throw UtilityError("Start failed: \(startError.localizedDescription). Cleanup failed: \(error.localizedDescription)") }
            throw startError
        }
    }
    public func stop(_ service: UtilityService, context: ExecutionContext) async throws {
        let target = "\(domain)/\(label(context.utility.id, service.id))"
        let result = try await runner(["bootout", target], context)
        if result.status != 0 {
            let check = try await runner(["print", target], context)
            guard confirmsAbsence(check, label: label(context.utility.id, service.id)) else {
                throw UtilityError("Service could not stop; registration preserved: \(result.error). Status could not confirm absence: \(check.error.isEmpty ? check.output : check.error)")
            }
        }
        let file = agents.appendingPathComponent(label(context.utility.id, service.id) + ".plist")
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
    public func status(_ service: UtilityService, context: ExecutionContext) async throws -> String {
        let result = try await runner(["print", "\(domain)/\(label(context.utility.id, service.id))"], context)
        if result.status != 0 {
            if confirmsAbsence(result, label: label(context.utility.id, service.id)) { return "Stopped" }
            throw UtilityError("Service status is unknown: \(result.error.isEmpty ? result.output : result.error)")
        }
        if result.output.contains("state = running") {
            let file = context.data.appendingPathComponent("services/\(service.id)/state.json")
            if let data = try? Data(contentsOf: file), let state = try? JSONDecoder().decode(ServiceSupervisor.State.self, from: data), state.phase == "backoff" { return "Recovering — attempt \(state.attempt + 1)" }
            return "Running"
        }
        return "Exited — inspect logs or restart"
    }
    public func logs(_ service: UtilityService, context: ExecutionContext) -> String {
        let stateFile = context.data.appendingPathComponent("services/\(service.id)/state.json")
        var summary = ""
        if let data = try? Data(contentsOf: stateFile), let state = try? JSONDecoder().decode(ServiceSupervisor.State.self, from: data) {
            summary = "Supervisor: \(state.phase), attempt \(state.attempt + 1)" +
                (state.status.map { ", exit \($0)" } ?? "") +
                (state.error.map { "\n" + $0 } ?? "") + "\n"
        }
        return summary + ["stdout", "stderr"].map { channel in
            let file = context.data.appendingPathComponent("services/\(service.id)/\(channel).log")
            guard let handle = try? FileHandle(forReadingFrom: file) else { return "\(channel): (empty)" }
            defer { try? handle.close() }
            let size = (try? handle.seekToEnd()) ?? 0
            try? handle.seek(toOffset: size > 32768 ? size - 32768 : 0)
            return "\(channel):\n" + String(decoding: (try? handle.readToEnd()) ?? Data(), as: UTF8.self)
        }.joined(separator: "\n")
    }
}
