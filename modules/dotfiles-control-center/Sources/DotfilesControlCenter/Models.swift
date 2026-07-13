import Foundation

struct ModuleStatus: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let enabled: Bool
    let description: String
}

enum ModuleAction: String, CaseIterable, Identifiable, Sendable {
    case enable
    case disable
    case uninstall
    case purge

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var requiresExactModuleID: Bool { self == .uninstall || self == .purge }
    var isDestructive: Bool { requiresExactModuleID }
}

struct ModulePlan: Codable, Equatable, Sendable {
    struct Module: Codable, Equatable, Sendable {
        let id: String
        let enabled: Bool
        let targetEnabled: Bool
        let description: String
        let dataKey: String
    }

    struct Blocker: Codable, Equatable, Sendable {
        let path: String?
        let reason: String?
    }

    let schemaVersion: Int
    let operation: String
    let module: Module
    let exclusiveTargets: [String]
    let contributionTargets: [String]
    let preservedState: [String]
    let ephemeralState: [String]
    let stateRootRequired: Bool
    let confirmation: String?
    let sourcePreserved: Bool
    let executable: Bool
    let blockers: [Blocker]
}

struct ModuleActionResult: Codable, Equatable, Sendable {
    struct Module: Codable, Equatable, Sendable {
        let id: String
        let dataKey: String
        let enabled: Bool
        let previouslyEnabled: Bool
    }

    let schemaVersion: Int
    let operation: String
    let status: String
    let module: Module
    let changed: Bool
    let sourcePreserved: Bool
}

struct DependencyReport: Codable, Equatable, Sendable {
    struct Summary: Codable, Equatable, Sendable {
        let total: Int
        let missing: Int
        let unpinned: Int
        let outdated: Int
        let drifted: Int
        let managerErrors: Int
        let missingLockIds: Int
        let staleLockIds: Int
    }

    struct LockDrift: Codable, Equatable, Sendable {
        let missingIds: [String]
        let staleIds: [String]
    }

    let schemaVersion: Int
    let offline: Bool
    let summary: Summary
    let managerErrors: [String]
    let lockDrift: LockDrift
    let dependencies: [Dependency]
}

struct Dependency: Codable, Equatable, Identifiable, Sendable {
    let declaredVersion: String?
    let drifted: Bool
    let id: String
    let installedPath: String?
    let installedVersion: String?
    let kind: String
    let lockedVersion: String?
    let manager: String
    let name: String
    let outdated: Bool
    let owners: [String]
    let pinStatus: String
    let providedExecutables: [String]?
    let remoteStatus: String?
    let required: Bool
    let resolvedVersion: String?
    let snapshotState: String
    let source: String
    let sources: [String]
    let state: String
    let target: String?
    let updateStatus: String
}

struct DependencySnapshot: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        let installedPath: String?
        let installedVersion: String?
        let resolvedVersion: String?
    }

    let schemaVersion: Int
    let complete: Bool
    let managerStatus: [String: String]
    let errors: [String]
    let dependencies: [String: Entry]
}

struct SystemUninstallPlan: Codable, Equatable, Sendable {
    struct Target: Codable, Equatable, Identifiable, Sendable {
        let path: String
        let type: String
        let status: String
        let actualType: String?

        var id: String { "\(type):\(path)" }
    }

    struct Blocker: Codable, Equatable, Identifiable, Sendable {
        let path: String
        let reason: String

        var id: String { "\(path):\(reason)" }
    }

    let schemaVersion: Int
    let operation: String
    let destination: String
    let source: String
    let targets: [Target]
    let changedTargets: [String]
    let backupPath: String?
    let preserved: [String]
    let blockers: [Blocker]
    let executable: Bool
    let confirmation: String
}

struct SystemUninstallLedger: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let operation: String
    let destination: String
    let source: String
    let backupPath: String?
    let id: String
    let status: String
    let error: String?
    let restoreStatus: String?

    var restoreConfirmation: String {
        "RESTORE DOTFILES TO \(destination)"
    }

    var restoreCommand: String {
        let command = "\(source)/modules/system-uninstall/bin/dotfiles-uninstall"
        return "\(shellQuote(command)) restore \(shellQuote(id)) --confirm \(shellQuote(restoreConfirmation))"
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

struct CommandOutput: Equatable, Sendable {
    let stdout: Data
    let stderr: Data
    let terminationStatus: Int32

    var stderrText: String {
        String(data: stderr, encoding: .utf8) ?? ""
    }
}

struct CommandOutcome<Value: Sendable>: Sendable {
    let value: Value
    let terminationStatus: Int32
    let stderr: String
}
