import Foundation
import Darwin

public struct ExecutionResult {
    public let status: Int32
    public let output: String
    public let error: String
}
public struct ExecutionContext {
    public let utility: InstalledUtility
    public let package: URL
    public let data: URL
    public let toolDirectories: [String]
    public init(utility: InstalledUtility, store: UtilityStore, toolDirectories: [String]? = nil) {
        self.utility = utility; package = store.package(utility); data = store.dataDirectory(utility.id)
        self.toolDirectories = toolDirectories ?? ["/opt/homebrew/bin", "/usr/local/bin", FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("bin").path, "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
    }
    public func tool(_ name: String) throws -> URL {
        guard !name.contains("/") else { throw UtilityError("Invalid tool name") }
        for directory in toolDirectories {
            let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: url.path) { return url }
        }
        throw UtilityError("Missing dependency: \(name). Install it before running this utility.")
    }
    public func expand(_ value: String) throws -> String {
        var result = value
        let regex = try NSRegularExpression(pattern: "\\{(?:(setting|tool):([a-zA-Z0-9_.+-]+)|(data|package|home))\\}")
        for match in regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).reversed() {
            let replacement: String
            if let range = Range(match.range(at: 3), in: value) {
                switch value[range] {
                case "data": replacement = data.path
                case "package": replacement = package.path
                default: replacement = FileManager.default.homeDirectoryForCurrentUser.path
                }
            } else {
                let key = String(value[Range(match.range(at: 2), in: value)!])
                let kind = String(value[Range(match.range(at: 1), in: value)!])
                if kind == "tool" { replacement = try tool(key).path }
                else {
                    guard let setting = utility.settings[key] else { throw UtilityError("Missing setting: \(key)") }
                    replacement = setting
                }
            }
            result.replaceSubrange(Range(match.range, in: result)!, with: replacement)
        }
        return result
    }
    public func resolve(_ invocation: Invocation) throws -> (URL, [String], [String: String], URL) {
        let executable: URL
        if let name = invocation.tool { executable = try tool(name) }
        else if let path = invocation.executable { executable = try PackagePaths.executable(path, in: package) }
        else { throw UtilityError("Missing executable") }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var environment = ["HOME": home, "PATH": toolDirectories.joined(separator: ":"), "LANG": "en_US.UTF-8", "TMPDIR": NSTemporaryDirectory()]
        for (key, value) in invocation.environment ?? [:] { environment[key] = try expand(value) }
        // Explicitly scoped task stores are intentional. Never substitute the global store.
        if let tasks = ProcessInfo.processInfo.environment["AGENT_TODO_DIR"] { environment["AGENT_TODO_DIR"] = tasks }
        environment["DOTFILES_UTILITY_ID"] = utility.id
        environment["DOTFILES_UTILITY_DATA"] = data.path
        environment["DOTFILES_UTILITY_SETTINGS"] = String(data: try JSONEncoder().encode(utility.settings), encoding: .utf8)!
        let directory = try invocation.workingDirectory.map(expand) ?? home
        let cwd = NSString(string: directory).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard cwd.hasPrefix("/"), FileManager.default.fileExists(atPath: cwd, isDirectory: &isDirectory), isDirectory.boolValue else { throw UtilityError("Working directory does not exist: \(cwd)") }
        return (executable, try (invocation.arguments ?? []).map(expand), environment, URL(fileURLWithPath: cwd))
    }
}

/// One directly owned process. Utilities must not daemonize; launchd/tmux remain
/// responsible for workloads explicitly handed off to those external services.
public final class ManagedJob {
    public let process: Process
    public let startedAt = Date()
    public let directory: URL
    private let stdout: URL
    private let stderr: URL
    private let handles: [FileHandle]
    private let fm = FileManager.default
    public static let outputLimit = 1024 * 1024
    public init(invocation: Invocation, context: ExecutionContext, input: String = "") throws {
        let (executable, arguments, environment, cwd) = try context.resolve(invocation)
        try fm.createDirectory(at: context.data, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        directory = context.data.appendingPathComponent("runs/\(UUID().uuidString)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        stdout = directory.appendingPathComponent("stdout.log"); stderr = directory.appendingPathComponent("stderr.log")
        let stdin = directory.appendingPathComponent("input")
        try Data(input.utf8).write(to: stdin, options: .atomic)
        fm.createFile(atPath: stdout.path, contents: nil, attributes: [.posixPermissions: 0o600])
        fm.createFile(atPath: stderr.path, contents: nil, attributes: [.posixPermissions: 0o600])
        handles = [try FileHandle(forReadingFrom: stdin), try FileHandle(forWritingTo: stdout), try FileHandle(forWritingTo: stderr)]
        process = Process(); process.executableURL = executable; process.arguments = arguments
        process.environment = environment; process.currentDirectoryURL = cwd
        process.standardInput = handles[0]; process.standardOutput = handles[1]; process.standardError = handles[2]
        do { try process.run() } catch { handles.forEach { try? $0.close() }; try? fm.removeItem(at: directory); throw error }
        // Input is never retained as a log (notably clipboard text).
        try? fm.removeItem(at: stdin)
    }
    deinit { handles.forEach { try? $0.close() } }
    public var running: Bool { process.isRunning }
    public var exceededOutputLimit: Bool {
        [stdout, stderr].contains { ((try? fm.attributesOfItem(atPath: $0.path)[.size] as? NSNumber)?.intValue ?? 0) > Self.outputLimit }
    }
    private func tail(_ url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > 65536 ? size - 65536 : 0)
        return String(decoding: (try? handle.readToEnd()) ?? Data(), as: UTF8.self)
    }
    public var output: String { tail(stdout) }
    public var errorOutput: String { tail(stderr) }
    public func stop() async {
        // Cleanup must retain its grace period even when the caller is cancelled.
        let process = self.process
        await Task.detached {
            guard process.isRunning else { return }
            process.terminate()
            for _ in 0..<20 {
                if !process.isRunning { return }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
            for _ in 0..<20 {
                if !process.isRunning { return }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }.value
    }
    public func removeLogs() { try? fm.removeItem(at: directory) }
    public static func run(_ invocation: Invocation, context: ExecutionContext, input: String = "") async throws -> ExecutionResult {
        guard input.utf8.count <= outputLimit else { throw UtilityError("Input exceeds 1 MiB") }
        let job = try ManagedJob(invocation: invocation, context: context, input: input)
        defer { job.removeLogs() }
        do {
            while job.running {
                try Task.checkCancellation()
                if job.exceededOutputLimit { throw UtilityError("Utility exceeded the output limit") }
                if Date().timeIntervalSince(job.startedAt) > (invocation.timeoutSeconds ?? 30) { throw UtilityError("Utility timed out") }
                try await Task.sleep(nanoseconds: 25_000_000)
            }
            guard !job.exceededOutputLimit else { throw UtilityError("Utility exceeded the output limit") }
            return ExecutionResult(status: job.process.terminationStatus, output: job.output, error: job.errorOutput)
        } catch { await job.stop(); throw error }
    }
}
