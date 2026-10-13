import Foundation

public struct UtilityError: LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public struct Invocation: Codable, Equatable {
    public var executable: String? // package-relative executable
    public var tool: String?       // external executable, resolved without a shell
    public var arguments: [String]?
    public var timeoutSeconds: Double?
    public var environment: [String: String]?
    public var workingDirectory: String?
}
public struct UtilityAction: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var invocation: Invocation
    public var input: Bool?
    public var confirmation: String?
}
public struct UtilityService: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var invocation: Invocation
    public var health: Invocation?
}
public struct UtilitySetting: Codable, Identifiable, Equatable {
    public var key: String
    public var title: String
    public var kind: String // string, boolean, integer, choice, directory
    public var defaultValue: String
    public var choices: [String]?
    public var id: String { key }
    public func validate(_ value: String) throws {
        switch kind {
        case "boolean": guard ["true", "false"].contains(value) else { throw UtilityError("\(title) must be true or false") }
        case "integer": guard Int(value) != nil else { throw UtilityError("\(title) must be an integer") }
        case "choice": guard choices?.contains(value) == true else { throw UtilityError("Invalid choice for \(title)") }
        case "directory": guard value.hasPrefix("/") || value.hasPrefix("~/") || value.isEmpty else { throw UtilityError("\(title) must be an absolute directory") }
        case "string": break
        default: throw UtilityError("Unknown setting kind: \(kind)")
        }
    }
}
public struct UtilityManifest: Codable, Equatable {
    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var version: String
    public var summary: String
    public var commands: [UtilityAction]
    public var services: [UtilityService]?
    public var settings: [UtilitySetting]?
    public var homepage: String?
    public var minimumHostVersion: Int?
    public var allInvocations: [Invocation] {
        commands.map(\.invocation) + (services ?? []).flatMap { [$0.invocation] + ($0.health.map { [$0] } ?? []) }
    }
    public static func validID(_ id: String) -> Bool {
        id.range(of: "^[a-z][a-z0-9.-]{0,95}$", options: .regularExpression) != nil
    }
    public static func validVersion(_ version: String) -> Bool {
        version.range(of: "^[0-9]+\\.[0-9]+\\.[0-9]+(-[a-zA-Z0-9.-]+)?$", options: .regularExpression) != nil
    }
    public func validate(at package: URL) throws {
        guard schemaVersion == 1, (minimumHostVersion ?? 1) <= 1 else { throw UtilityError("Unsupported extension API version") }
        guard Self.validID(id), !name.isEmpty, name.count < 150,
              Self.validVersion(version) else { throw UtilityError("Invalid utility identity or version") }
        let ids = commands.map(\.id) + (services ?? []).map(\.id)
        guard !ids.isEmpty, ids.count <= 256, Set(ids).count == ids.count, ids.allSatisfy(Self.validID) else { throw UtilityError("Command/service IDs must be unique and valid") }
        let keys = (settings ?? []).map(\.key)
        guard Set(keys).count == keys.count, keys.allSatisfy(Self.validID) else { throw UtilityError("Setting keys must be unique and valid") }
        for setting in settings ?? [] { try setting.validate(setting.defaultValue) }
        for invocation in allInvocations {
            guard (invocation.executable == nil) != (invocation.tool == nil) else { throw UtilityError("Specify exactly one of executable or tool") }
            if let tool = invocation.tool {
                guard tool.range(of: "^[a-zA-Z0-9_][a-zA-Z0-9_.+-]*$", options: .regularExpression) != nil else { throw UtilityError("External tools must be command names") }
            }
            if let path = invocation.executable { _ = try PackagePaths.executable(path, in: package) }
            let timeout = invocation.timeoutSeconds ?? 30
            guard timeout.isFinite, timeout >= 0.1, timeout <= 3600 else { throw UtilityError("Timeout must be between 0.1 and 3600 seconds") }
            for key in invocation.environment?.keys ?? Dictionary<String, String>().keys {
                guard key.range(of: "^[A-Z_][A-Z0-9_]*$", options: .regularExpression) != nil,
                      !["HOME", "PATH", "DYLD_INSERT_LIBRARIES"].contains(key), !key.hasPrefix("DOTFILES_UTILITY_") else { throw UtilityError("Reserved or invalid environment key: \(key)") }
            }
        }
    }
    public static func load(from package: URL) throws -> Self {
        let data = try Data(contentsOf: package.appendingPathComponent("extension.json"))
        guard data.count <= 262144 else { throw UtilityError("Manifest exceeds 256 KiB") }
        let result = try JSONDecoder().decode(Self.self, from: data)
        try result.validate(at: package)
        return result
    }
}

public enum PackagePaths {
    public static func executable(_ path: String, in root: URL) throws -> URL {
        guard !path.hasPrefix("/"), !path.split(separator: "/").contains(".."), !path.isEmpty else { throw UtilityError("Executable must stay inside the package") }
        let base = root.resolvingSymlinksInPath().standardizedFileURL
        let url = base.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
        guard url.path.hasPrefix(base.path + "/"), FileManager.default.isExecutableFile(atPath: url.path),
              (try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true else { throw UtilityError("Missing or unsafe executable: \(path)") }
        return url
    }
    public static func validateTree(_ root: URL) throws {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey]) else { throw UtilityError("Cannot read package") }
        var total = 0
        for case let file as URL in enumerator {
            let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true || values.isDirectory == true else { throw UtilityError("Packages cannot contain symlinks or special files") }
            total += values.fileSize ?? 0
            guard total <= 512 * 1024 * 1024 else { throw UtilityError("Package exceeds 512 MiB") }
        }
    }
}
