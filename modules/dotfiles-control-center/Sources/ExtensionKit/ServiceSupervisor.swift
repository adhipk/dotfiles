import Foundation
import Darwin

/// A launchd-owned worker: pipes are drained and rotated independently of the UI.
/// Utilities must stay in the foreground, just as they must for direct launchd use.
public final class ServiceSupervisor {
    public struct State: Codable {
        public let phase: String
        public let attempt: Int
        public let status: Int32?
        public let error: String?
    }
    private let condition = NSCondition()
    private var child: Process?
    private var stopped = false
    public init() {}
    public func stop() {
        condition.lock()
        stopped = true
        if let child, child.isRunning {
            child.terminate()
            // A foreground service may ignore TERM. Bound graceful shutdown;
            // launchd also owns the entire job's process group at bootout.
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) {
                self.condition.lock(); defer { self.condition.unlock() }
                if self.child === child, child.isRunning { _ = kill(child.processIdentifier, SIGKILL) }
            }
        }
        condition.broadcast()
        condition.unlock()
    }
    public func run(executable: URL, arguments: [String], logs: URL,
                    environment: [String: String], directory: URL,
                    maxRetries: Int = 3, retryDelay: TimeInterval = 2,
                    logLimit: Int = 1024 * 1024) throws -> Int32 {
        guard maxRetries >= 0, retryDelay >= 0, logLimit > 0 else { throw UtilityError("Invalid service recovery limits") }
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let stdout = try RotatingServiceLog(url: logs.appendingPathComponent("stdout.log"), limit: logLimit)
        let stderr = try RotatingServiceLog(url: logs.appendingPathComponent("stderr.log"), limit: logLimit)
        func state(_ phase: String, _ attempt: Int, _ status: Int32? = nil, error: String? = nil) throws {
            try JSONEncoder().encode(State(phase: phase, attempt: attempt, status: status, error: error.map { String($0.prefix(4096)) })).write(to: logs.appendingPathComponent("state.json"), options: .atomic)
        }
        for attempt in 0...maxRetries {
            let process = Process(), out = Pipe(), err = Pipe()
            process.executableURL = executable; process.arguments = arguments
            process.environment = environment; process.currentDirectoryURL = directory
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = out; process.standardError = err
            try state("running", attempt)
            condition.lock()
            if stopped { condition.unlock(); try state("stopped", attempt); return 0 }
            do { try process.run(); child = process; condition.unlock() }
            catch { condition.unlock(); try state("failed", attempt, error: error.localizedDescription); throw error }
            let group = DispatchGroup(), errors = ServiceReadErrors()
            for (pipe, log) in [(out, stdout), (err, stderr)] {
                group.enter()
                DispatchQueue.global(qos: .utility).async {
                    defer { try? pipe.fileHandleForReading.close(); group.leave() }
                    do {
                        while let data = try pipe.fileHandleForReading.read(upToCount: 65536), !data.isEmpty { try log.append(data) }
                    } catch { errors.set(error); self.stop() }
                }
            }
            process.waitUntilExit(); group.wait()
            condition.lock(); child = nil; let stopping = stopped; condition.unlock()
            if let error = errors.get() { try state("failed", attempt, process.terminationStatus, error: error.localizedDescription); throw error }
            if stopping { try state("stopped", attempt); return 0 }
            let status = process.terminationStatus
            if process.terminationReason == .exit && status == 0 { try state("completed", attempt, status); return 0 }
            if attempt == maxRetries { try state("exhausted", attempt, status); return status == 0 ? 1 : status }
            try state("backoff", attempt, status)
            condition.lock()
            let deadline = Date().addingTimeInterval(min(retryDelay * pow(2, Double(attempt)), 30))
            while !stopped && Date() < deadline { _ = condition.wait(until: deadline) }
            condition.unlock()
        }
        return 1
    }
}

private final class ServiceReadErrors {
    private let lock = NSLock()
    private var error: Error?
    func set(_ value: Error) { lock.lock(); defer { lock.unlock() }; error = value }
    func get() -> Error? { lock.lock(); defer { lock.unlock() }; return error }
}

/// One active file and one backup per channel; each is strictly bounded.
public final class RotatingServiceLog {
    private let url: URL
    private let limit: Int
    private var handle: FileHandle
    private var size: Int
    public init(url: URL, limit: Int) throws {
        guard limit > 0 else { throw UtilityError("Invalid log limit") }
        self.url = url; self.limit = limit
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) }
        handle = try FileHandle(forWritingTo: url)
        size = Int(try handle.seekToEnd())
        // Migrate pre-supervisor unbounded logs without carrying excess bytes.
        if size > limit { try handle.truncate(atOffset: 0); size = 0 }
        let backup = URL(fileURLWithPath: url.path + ".1")
        if let bytes = try? FileManager.default.attributesOfItem(atPath: backup.path)[.size] as? NSNumber, bytes.intValue > limit { try FileManager.default.removeItem(at: backup) }
    }
    deinit { try? handle.close() }
    public func append(_ data: Data) throws {
        var offset = 0
        while offset < data.count {
            if size == limit {
                try handle.close()
                let backup = URL(fileURLWithPath: url.path + ".1")
                if FileManager.default.fileExists(atPath: backup.path) { try FileManager.default.removeItem(at: backup) }
                try FileManager.default.moveItem(at: url, to: backup)
                FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
                handle = try FileHandle(forWritingTo: url); size = 0
            }
            let count = min(limit - size, data.count - offset)
            try handle.write(contentsOf: data.subdata(in: offset..<(offset + count)))
            size += count; offset += count
        }
    }
}
