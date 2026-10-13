import Foundation
import Darwin

public struct KeyBinding: Codable, Equatable {
    public var keyCode: UInt32
    public var modifiers: UInt32 // Carbon modifier flags; portable manifest stores no OS shortcuts
    public init(keyCode: UInt32, modifiers: UInt32) { self.keyCode = keyCode; self.modifiers = modifiers }
}
public struct InstalledUtility: Codable, Identifiable, Equatable {
    public var manifest: UtilityManifest
    public var activeVersion: String
    public var previousVersion: String?
    public var enabled: Bool
    public var settings: [String: String]
    public var shortcuts: [String: KeyBinding]
    public var runningServices: Set<String>
    public var id: String { manifest.id }
}
private struct Registry: Codable {
    var schemaVersion = 1
    var utilities: [InstalledUtility] = []
}
public final class UtilityStore {
    public let root: URL
    private let fm = FileManager.default
    public init(root: URL? = nil) {
        self.root = root ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Dotfiles/Utilities")
    }
    public func package(_ record: InstalledUtility) -> URL {
        root.appendingPathComponent("packages/\(record.id)/\(record.activeVersion)")
    }
    public func dataDirectory(_ id: String) -> URL { root.appendingPathComponent("data/\(id)") }
    private func locked<T>(_ operation: () throws -> T) throws -> T {
        try fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let fd = Darwin.open(root.appendingPathComponent(".lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw UtilityError("Cannot open utility registry lock") }
        defer { Darwin.close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw UtilityError("Cannot lock utility registry") }
        defer { flock(fd, LOCK_UN) }
        return try operation()
    }
    private func read() throws -> Registry {
        let file = root.appendingPathComponent("registry.json")
        guard fm.fileExists(atPath: file.path) else { return Registry() }
        let registry = try JSONDecoder().decode(Registry.self, from: Data(contentsOf: file))
        guard registry.schemaVersion == 1 else { throw UtilityError("Unsupported registry version; no changes made") }
        var ids = Set<String>()
        for utility in registry.utilities {
            guard UtilityManifest.validID(utility.id), ids.insert(utility.id).inserted,
                  UtilityManifest.validVersion(utility.activeVersion), utility.activeVersion == utility.manifest.version,
                  utility.previousVersion.map(UtilityManifest.validVersion) ?? true else {
                throw UtilityError("Invalid utility registry identity; no changes made")
            }
        }
        return registry
    }
    private func write(_ registry: Registry) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(registry).write(to: root.appendingPathComponent("registry.json"), options: .atomic)
    }
    public func list() throws -> [InstalledUtility] { try locked { try read().utilities.sorted { $0.manifest.name < $1.manifest.name } } }
    @discardableResult public func install(from source: URL) throws -> InstalledUtility {
        try locked {
            var registry = try read()
            let staging = root.appendingPathComponent("staging-\(UUID().uuidString)")
            defer { try? fm.removeItem(at: staging) }
            try PackagePaths.validateTree(source)
            try fm.copyItem(at: source, to: staging)
            try PackagePaths.validateTree(staging)
            let manifest = try UtilityManifest.load(from: staging)
            let existing = registry.utilities.first { $0.id == manifest.id }
            guard existing?.activeVersion != manifest.version else { throw UtilityError("This version is already installed; use a new version for updates") }
            var settings = existing?.settings ?? [:]
            for setting in manifest.settings ?? [] {
                let value = settings[setting.key] ?? setting.defaultValue
                try setting.validate(value); settings[setting.key] = value
            }
            settings = settings.filter { key, _ in (manifest.settings ?? []).contains { $0.key == key } }
            let record = InstalledUtility(manifest: manifest, activeVersion: manifest.version,
                previousVersion: existing?.activeVersion, enabled: existing?.enabled ?? false, settings: settings,
                shortcuts: (existing?.shortcuts ?? [:]).filter { key, _ in manifest.commands.contains { $0.id == key } },
                runningServices: (existing?.runningServices ?? []).intersection(Set((manifest.services ?? []).map(\.id))))
            let destination = package(record)
            guard !fm.fileExists(atPath: destination.path) else { throw UtilityError("Version already retained locally; use rollback or publish a new version") }
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: staging, to: destination)
            do {
                registry.utilities.removeAll { $0.id == manifest.id }; registry.utilities.append(record)
                try write(registry)
            } catch { try? fm.removeItem(at: destination); throw error }
            return record
        }
    }
    public func change(_ id: String, _ body: (inout InstalledUtility) throws -> Void) throws {
        try locked {
            var registry = try read()
            guard let index = registry.utilities.firstIndex(where: { $0.id == id }) else { throw UtilityError("Unknown utility: \(id)") }
            try body(&registry.utilities[index])
            let record = registry.utilities[index]
            for key in record.shortcuts.keys {
                guard record.manifest.commands.contains(where: { $0.id == key }) else { throw UtilityError("Unknown shortcut action") }
            }
            var bindings = Set<String>()
            for utility in registry.utilities where utility.enabled {
                for binding in utility.shortcuts.values {
                    guard binding.keyCode <= 127, binding.modifiers != 0,
                          binding.modifiers & ~UInt32(256 | 512 | 2048 | 4096) == 0 else { throw UtilityError("Shortcut requires a valid key and modifier") }
                    guard bindings.insert("\(binding.keyCode):\(binding.modifiers)").inserted else { throw UtilityError("That shortcut is assigned to another action") }
                }
            }
            try write(registry)
        }
    }
    public func configure(_ id: String, key: String, value: String) throws {
        try change(id) { utility in
            guard let setting = utility.manifest.settings?.first(where: { $0.key == key }) else { throw UtilityError("Unknown setting: \(key)") }
            try setting.validate(value); utility.settings[key] = value
        }
    }
    public func rollback(_ id: String) throws {
        try change(id) { record in
            guard let previous = record.previousVersion else { throw UtilityError("No previous version") }
            let url = root.appendingPathComponent("packages/\(id)/\(previous)")
            let manifest = try UtilityManifest.load(from: url)
            var settings: [String: String] = [:]
            for setting in manifest.settings ?? [] {
                let value = record.settings[setting.key] ?? setting.defaultValue
                try setting.validate(value); settings[setting.key] = value
            }
            record.previousVersion = record.activeVersion; record.activeVersion = previous; record.manifest = manifest
            record.settings = settings
            record.shortcuts = record.shortcuts.filter { key, _ in manifest.commands.contains { $0.id == key } }
            record.runningServices = record.runningServices.intersection(Set((manifest.services ?? []).map(\.id)))
        }
    }
    public func remove(_ id: String, deletePackages: Bool = true) throws {
        try locked {
            var registry = try read()
            guard registry.utilities.contains(where: { $0.id == id }), UtilityManifest.validID(id) else { throw UtilityError("Unknown utility") }
            registry.utilities.removeAll { $0.id == id }
            try write(registry) // remove registrations before deleting code; user data stays
            if deletePackages { try fm.removeItem(at: root.appendingPathComponent("packages/\(id)")) }
        }
    }
    // Used only while the lifecycle lock is held. Code is immutable and retained
    // until a transaction commits, so interrupted activation can restore this state.
    func restore(_ utilities: [InstalledUtility]) throws {
        try locked {
            for record in utilities {
                guard UtilityManifest.validID(record.id), UtilityManifest.validVersion(record.activeVersion),
                      try UtilityManifest.load(from: package(record)) == record.manifest else {
                    throw UtilityError("Recovery package is missing or changed: \(record.id)")
                }
            }
            try write(Registry(utilities: utilities))
        }
    }

}
