import Foundation
import Darwin

/// Shared author context, usable from a normal command or a persistent worker.
public struct UtilityContext {
    public let id: String
    public let dataDirectory: URL
    public let settings: [String: String]
    public init(environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        guard let id = environment["DOTFILES_UTILITY_ID"], UtilityManifest.validID(id),
              let directory = environment["DOTFILES_UTILITY_DATA"], directory.hasPrefix("/") else { throw UtilityError("Run through the utility host or its dev command") }
        self.id = id; dataDirectory = URL(fileURLWithPath: directory)
        settings = try JSONDecoder().decode([String: String].self, from: Data((environment["DOTFILES_UTILITY_SETTINGS"] ?? "{}").utf8))
    }
    public func writeState<T: Encodable>(_ value: T, name: String) throws {
        guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else { throw UtilityError("State name must be a filename") }
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(value).write(to: dataDirectory.appendingPathComponent(name), options: .atomic)
    }
    public func readState<T: Decodable>(_ type: T.Type, name: String) throws -> T? {
        guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else { throw UtilityError("State name must be a filename") }
        let url = dataDirectory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
    public func log(_ message: String) {
        FileHandle.standardError.write(Data("[\(id)] \(message)\n".utf8))
    }
}

/// Optional hooks for service authors. Stop is delivered once for SIGTERM or
/// SIGINT. The host supplies updated settings by stopping/restarting the worker.
public final class ServiceHooks {
    private var sources: [DispatchSourceSignal] = []
    private let queue = DispatchQueue(label: "dotfiles.utility.signals")
    public init(onShutdown: @escaping () -> Void) {
        var stopped = false
        for number in [SIGTERM, SIGINT] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: queue)
            source.setEventHandler {
                guard !stopped else { return }; stopped = true; onShutdown()
            }
            source.resume(); sources.append(source)
        }
    }
    deinit { sources.forEach { $0.cancel() } }
}
