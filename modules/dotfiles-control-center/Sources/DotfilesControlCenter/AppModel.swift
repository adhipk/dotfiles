import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let client: CommandClient

    @Published private(set) var modules: [ModuleStatus] = []
    @Published var selectedModuleID: String? {
        didSet {
            if selectedModuleID != oldValue {
                modulePlan = nil
                moduleResult = nil
                moduleConfirmation = ""
                moduleStateRootPath = ""
            }
        }
    }
    @Published var selectedModuleAction: ModuleAction = .disable {
        didSet {
            if selectedModuleAction != oldValue {
                modulePlan = nil
                moduleResult = nil
                moduleConfirmation = ""
                moduleStateRootPath = ""
            }
        }
    }
    @Published private(set) var modulePlan: ModulePlan?
    @Published private(set) var moduleResult: ModuleActionResult?
    @Published var moduleConfirmation = ""
    @Published var moduleStateRootPath = ""

    @Published private(set) var dependencyReport: DependencyReport?
    @Published private(set) var dependencyExitStatus: Int32 = 0
    @Published private(set) var dependencyStderr = ""
    @Published private(set) var dependencySnapshot: DependencySnapshot?
    @Published private(set) var dependencySnapshotPreview = ""
    @Published var dependencySearch = ""
    @Published var dependencyManager = "All"

    @Published private(set) var systemPlan: SystemUninstallPlan?
    @Published private(set) var systemLedger: SystemUninstallLedger?
    @Published var systemConfirmation = ""

    @Published private(set) var isBusy = false
    @Published private(set) var lastError: String?
    @Published private(set) var notice: String?

    init(client: CommandClient) {
        self.client = client
    }

    var selectedModule: ModuleStatus? {
        modules.first { $0.id == selectedModuleID }
    }

    var canExecuteModule: Bool {
        guard !isBusy,
              let id = selectedModuleID,
              let plan = modulePlan,
              plan.schemaVersion == 1,
              plan.operation == "module-\(selectedModuleAction.rawValue)",
              plan.module.id == id,
              plan.executable,
              plan.blockers.isEmpty else {
            return false
        }
        if selectedModuleAction.requiresExactModuleID, moduleConfirmation != id {
            return false
        }
        if plan.stateRootRequired,
           moduleStateRootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return true
    }

    var canExecuteSystemUninstall: Bool {
        guard !isBusy, let plan = systemPlan else { return false }
        return plan.schemaVersion == 1
            && plan.executable
            && plan.blockers.isEmpty
            && systemConfirmation == plan.confirmation
    }

    func loadInitialState() async {
        await refreshModules()
        await refreshDependencies(check: false)
        await refreshSystemPlan()
    }

    func refreshModules() async {
        await perform {
            let previousSelection = selectedModuleID
            modules = try await client.moduleStatus().sorted { $0.id < $1.id }
            if let previousSelection, modules.contains(where: { $0.id == previousSelection }) {
                selectedModuleID = previousSelection
            } else {
                selectedModuleID = modules.first?.id
            }
            notice = "Loaded \(modules.count) modules."
        }
    }

    func loadModulePlan() async {
        guard let selectedModuleID else { return }
        await perform {
            modulePlan = try await client.modulePlan(
                action: selectedModuleAction,
                moduleID: selectedModuleID
            )
            moduleResult = nil
            notice = "Loaded the \(selectedModuleAction.rawValue) plan for \(selectedModuleID)."
        }
    }

    func executeSelectedModuleAction() async {
        guard canExecuteModule, let selectedModuleID else { return }
        let stateRoot: URL?
        if moduleStateRootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            stateRoot = nil
        } else {
            stateRoot = URL(fileURLWithPath: moduleStateRootPath, isDirectory: true).standardizedFileURL
        }

        await perform {
            moduleResult = try await client.executeModule(
                action: selectedModuleAction,
                moduleID: selectedModuleID,
                typedConfirmation: moduleConfirmation,
                stateRoot: stateRoot
            )
            modules = try await client.moduleStatus().sorted { $0.id < $1.id }
            moduleConfirmation = ""
            notice = "\(selectedModuleAction.title) completed for \(selectedModuleID)."
        }
    }

    func refreshDependencies(check: Bool) async {
        await perform {
            let outcome = try await client.dependencyStatus(check: check)
            dependencyReport = outcome.value
            dependencyExitStatus = outcome.terminationStatus
            dependencyStderr = outcome.stderr
            let suffix = outcome.terminationStatus == 0
                ? ""
                : " with \(outcome.value.summary.managerErrors) manager error(s)"
            notice = "Dependency \(check ? "check" : "status") completed\(suffix)."
        }
    }

    func previewDependencySnapshot() async {
        await perform {
            let snapshot = try await client.dependencySnapshot()
            dependencySnapshot = snapshot
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            dependencySnapshotPreview = String(
                data: try encoder.encode(snapshot),
                encoding: .utf8
            ) ?? ""
            notice = "Dependency snapshot preview generated; no lock file was changed."
        }
    }

    func refreshSystemPlan() async {
        await perform {
            systemPlan = try await client.systemUninstallPlan()
            systemLedger = nil
            systemConfirmation = ""
            notice = "Whole-system uninstall plan refreshed."
        }
    }

    func executeSystemUninstall() async {
        guard canExecuteSystemUninstall, let systemPlan else { return }
        await perform {
            systemLedger = try await client.executeSystemUninstall(
                plan: systemPlan,
                typedConfirmation: systemConfirmation
            )
            notice = "Dotfiles target removal completed; the restore command is shown below."
        }
    }

    func clearMessage() {
        lastError = nil
        notice = nil
    }

    private func perform(_ operation: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        lastError = nil
        notice = nil
        defer { isBusy = false }
        do {
            try await operation()
        } catch {
            lastError = error.localizedDescription
        }
    }
}
