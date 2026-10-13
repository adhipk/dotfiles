import Foundation
import Darwin

/// A single cross-process transaction boundary for both the app and CLI.
/// Registry reads remain available; mutation and action execution hold a lease.
public final class UtilityLifecycle {
    public let store: UtilityStore
    public let services: UtilityServices
    private let fm = FileManager.default
    private struct Journal: Codable {
        var schemaVersion = 1
        var operation: String
        var committed = false
        var before: [InstalledUtility]
        var candidate: UtilityManifest?
        var servicesTouched: Bool?
    }
    private var journalURL: URL { store.root.appendingPathComponent("lifecycle.json") }
    public init(store: UtilityStore, services: UtilityServices = UtilityServices()) {
        self.store = store; self.services = services
    }
    private func lease<T>(_ body: () async throws -> T) async throws -> T {
        try fm.createDirectory(at: store.root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let fd = Darwin.open(store.root.appendingPathComponent(".lifecycle-lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw UtilityError("Cannot open utility lifecycle lock") }
        defer { Darwin.close(fd) }
        let deadline = Date().addingTimeInterval(30)
        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK || errno == EAGAIN else { throw UtilityError("Cannot lock utility lifecycle") }
            guard Date() < deadline else { throw UtilityError("Another app or CLI action is still running. Retry after it finishes.") }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        defer { flock(fd, LOCK_UN) }
        try Task.checkCancellation()
        return try await body()
    }
    private func save(_ journal: Journal) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(journal).write(to: journalURL, options: .atomic)
    }
    private func record(_ id: String) throws -> InstalledUtility {
        guard let record = try store.list().first(where: { $0.id == id }) else { throw UtilityError("Unknown utility: \(id)") }
        return record
    }
    private func markServicesTouched() throws {
        guard fm.fileExists(atPath: journalURL.path) else { return }
        var journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: journalURL))
        if journal.servicesTouched != true { journal.servicesTouched = true; try save(journal) }
    }
    private func stop(_ record: InstalledUtility) async throws {
        for service in record.manifest.services ?? [] {
            try markServicesTouched()
            try await services.stop(service, context: ExecutionContext(utility: record, store: store))
        }
    }
    private func resume(_ record: InstalledUtility) async throws {
        guard record.enabled else { return }
        for service in record.manifest.services ?? [] where record.runningServices.contains(service.id) {
            try markServicesTouched()
            try await services.start(service, context: ExecutionContext(utility: record, store: store))
        }
    }
    private func cleanupUnregisteredPackages() throws {
        let root = store.root.appendingPathComponent("packages")
        guard fm.fileExists(atPath: root.path) else { return }
        let records = try store.list()
        let retained = Set(records.map(\.id))
        for directory in try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            where UtilityManifest.validID(directory.lastPathComponent) && !retained.contains(directory.lastPathComponent) {
            try fm.removeItem(at: directory)
        }
    }
    private func recoverLocked() async throws {
        guard fm.fileExists(atPath: journalURL.path) else { return }
        let journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: journalURL))
        guard journal.schemaVersion == 1 else { throw UtilityError("Unsupported lifecycle journal; no recovery changes made") }
        if !journal.committed {
            guard Set(journal.before.map(\.id)).count == journal.before.count else { throw UtilityError("Duplicate recovery identity") }
            for record in journal.before {
                guard UtilityManifest.validID(record.id), UtilityManifest.validVersion(record.activeVersion),
                      try UtilityManifest.load(from: store.package(record)) == record.manifest else {
                    throw UtilityError("Recovery package is missing or changed")
                }
            }
            let current = try store.list()
            // Only utilities changed by this transaction are restarted. Other
            // desired services and user sessions are left alone.
            let changed = Set((current + journal.before).map(\.id)).filter { id in
                guard journal.servicesTouched == true else { return false }
                return current.first(where: { $0.id == id }) != journal.before.first(where: { $0.id == id })
                    || journal.operation.hasSuffix("/" + id)
            }
            for record in current where changed.contains(record.id) { try await stop(record) }
            for record in journal.before where changed.contains(record.id) { try await stop(record) }
            try store.restore(journal.before)
            for record in journal.before where changed.contains(record.id) { try await resume(record) }
            // An interrupted install can leave code staged even before its
            // registry write. The journal identifies exactly that candidate.
            if let candidate = journal.candidate,
               UtilityManifest.validID(candidate.id), UtilityManifest.validVersion(candidate.version) {
                let old = journal.before.first { $0.id == candidate.id }
                if old?.activeVersion != candidate.version, old?.previousVersion != candidate.version {
                    let path = store.root.appendingPathComponent("packages/\(candidate.id)/\(candidate.version)")
                    if fm.fileExists(atPath: path.path) { try fm.removeItem(at: path) }
                }
            }
        }
        try cleanupUnregisteredPackages()
        try cleanupStaging()
        try fm.removeItem(at: journalURL)
    }
    private func cleanupStaging() throws {
        for path in try fm.contentsOfDirectory(at: store.root, includingPropertiesForKeys: nil)
            where path.lastPathComponent.range(of: "^staging-[A-Fa-f0-9]{8}(-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}$", options: .regularExpression) != nil {
            try fm.removeItem(at: path)
        }
    }
    public func recover() async throws { try await lease { try await self.recoverLocked() } }
    private func mutate<T>(_ operation: String, candidate: UtilityManifest? = nil, _ body: () async throws -> T) async throws -> T {
        try await lease {
            try await self.recoverLocked()
            if let candidate {
                let path = self.store.root.appendingPathComponent("packages/\(candidate.id)/\(candidate.version)")
                guard !self.fm.fileExists(atPath: path.path) else { throw UtilityError("Version already installed or retained; use rollback or a new version") }
            }
            var journal = Journal(operation: operation, before: try self.store.list(), candidate: candidate)
            try self.save(journal)
            do {
                let result = try await body()
                journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: self.journalURL))
                journal.committed = true; try self.save(journal)
                try self.recoverLockedCleanup()
                return result
            } catch {
                let original = error
                // Recovery must run even if the initiating task was cancelled.
                do { try await Task.detached { try await self.recoverLocked() }.value }
                catch { throw UtilityError("\(original.localizedDescription). Recovery needs attention: \(error.localizedDescription). Retry recovery before making more changes.") }
                throw original
            }
        }
    }
    private func recoverLockedCleanup() throws {
        try cleanupUnregisteredPackages()
        try cleanupStaging()
        try fm.removeItem(at: journalURL)
    }
    @discardableResult public func install(from source: URL) async throws -> InstalledUtility {
        try PackagePaths.validateTree(source)
        let manifest = try UtilityManifest.load(from: source)
        return try await mutate("install/" + manifest.id, candidate: manifest) {
            let candidatePath = self.store.root.appendingPathComponent("packages/\(manifest.id)/\(manifest.version)")
            guard !self.fm.fileExists(atPath: candidatePath.path) else { throw UtilityError("Version already installed or retained; use rollback or a new version") }
            if let old = try self.store.list().first(where: { $0.id == manifest.id }) { try await self.stop(old) }
            let next = try self.store.install(from: source)
            try await self.resume(next)
            return next
        }
    }
    public func enable(_ id: String, _ enabled: Bool) async throws {
        try await mutate("enable/" + id) {
            let old = try self.record(id)
            if !enabled { try await self.stop(old) }
            try self.store.change(id) { $0.enabled = enabled; if !enabled { $0.runningServices = [] } }
            if enabled { try await self.resume(self.record(id)) }
        }
    }
    public func remove(_ id: String) async throws {
        try await mutate("remove/" + id) {
            try await self.stop(self.record(id))
            try self.store.remove(id, deletePackages: false)
        }
    }
    public func rollback(_ id: String) async throws {
        try await mutate("rollback/" + id) {
            try await self.stop(self.record(id))
            try self.store.rollback(id)
            try await self.resume(self.record(id))
        }
    }
    public func configure(_ id: String, key: String, value: String) async throws {
        try await mutate("configure/" + id) {
            let old = try self.record(id)
            guard let setting = old.manifest.settings?.first(where: { $0.key == key }) else { throw UtilityError("Unknown setting") }
            try setting.validate(value)
            try await self.stop(old)
            try self.store.configure(id, key: key, value: value)
            try await self.resume(self.record(id))
        }
    }
    public func shortcut(_ id: String, command: String, binding: KeyBinding?) async throws {
        try await mutate("shortcut/" + id) { try self.store.change(id) { $0.shortcuts[command] = binding } }
    }
    public func service(_ id: String, serviceID: String, start: Bool) async throws {
        try await mutate("service/" + id) {
            let record = try self.record(id)
            guard let service = record.manifest.services?.first(where: { $0.id == serviceID }) else { throw UtilityError("Unknown service") }
            let context = ExecutionContext(utility: record, store: self.store)
            try self.markServicesTouched()
            if start {
                guard record.enabled else { throw UtilityError("Utility is disabled") }
                try await self.services.start(service, context: context)
            } else { try await self.services.stop(service, context: context) }
            try self.store.change(id) {
                if start { $0.runningServices.insert(serviceID) } else { $0.runningServices.remove(serviceID) }
            }
        }
    }
    public func inspect(_ id: String, serviceID: String) async throws -> (String, String, ExecutionResult?) {
        try await lease {
            try await self.recoverLocked()
            let record = try self.record(id)
            guard let service = record.manifest.services?.first(where: { $0.id == serviceID }) else { throw UtilityError("Unknown service") }
            let context = ExecutionContext(utility: record, store: self.store)
            let state = try await self.services.status(service, context: context)
            let logs = self.services.logs(service, context: context)
            var health: ExecutionResult?
            if let invocation = service.health { health = try await ManagedJob.run(invocation, context: context) }
            return (state, logs, health)
        }
    }
    public func run(_ id: String, command: String, input: String = "", confirmed: Bool = false, reviewed: InstalledUtility? = nil, hotkey: KeyBinding? = nil) async throws -> ExecutionResult {
        try await lease {
            try await self.recoverLocked()
            let record = try self.record(id)
            guard record.enabled else { throw UtilityError("Utility is disabled") }
            if let reviewed, reviewed != record { throw UtilityError("Utility changed while waiting. Review the action again.") }
            guard let action = record.manifest.commands.first(where: { $0.id == command }) else { throw UtilityError("Unknown command") }
            if let hotkey {
                guard record.shortcuts[command] == hotkey, action.input != true, action.confirmation == nil else {
                    throw UtilityError("Shortcut changed while waiting. Invoke the current shortcut again.")
                }
            }
            guard confirmed || action.confirmation == nil else { throw UtilityError("Run this action in the app to review its confirmation") }
            return try await ManagedJob.run(action.invocation, context: ExecutionContext(utility: record, store: self.store), input: action.input == true ? input : "")
        }
    }
}
