import AppKit
import SwiftUI

struct ModulesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Modules")
                        .font(.headline)
                    Spacer()
                    Button {
                        Task { await model.refreshModules() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.isBusy)
                    .help("Refresh module status")
                }
                .padding(12)

                Divider()
                List(model.modules, selection: $model.selectedModuleID) { module in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: module.enabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(module.enabled ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(module.id)
                                .font(.body.monospaced())
                            Text(module.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 3)
                    .tag(module.id)
                }
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 390)

            ScrollView {
                moduleDetail
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 600)
        }
    }

    @ViewBuilder
    private var moduleDetail: some View {
        if let module = model.selectedModule {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(module.id)
                            .font(.title2.monospaced())
                        Text(module.description)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(
                        module.enabled ? "Enabled" : "Disabled",
                        systemImage: module.enabled ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(module.enabled ? .green : .secondary)
                }

                GroupBox("Lifecycle action") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Picker("Action", selection: $model.selectedModuleAction) {
                                ForEach(ModuleAction.allCases) { action in
                                    Text(action.title).tag(action)
                                }
                            }
                            .pickerStyle(.segmented)

                            Button("Preview plan") {
                                Task { await model.loadModulePlan() }
                            }
                            .disabled(model.isBusy)
                        }

                        if let plan = model.modulePlan {
                            planDetails(plan)

                            if plan.stateRootRequired {
                                HStack {
                                    TextField("Required absolute state root", text: $model.moduleStateRootPath)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Choose…", action: chooseStateRoot)
                                }
                            }

                            if model.selectedModuleAction.requiresExactModuleID {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Type **\(module.id)** to confirm this destructive action.")
                                    TextField(module.id, text: $model.moduleConfirmation)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            HStack {
                                if !plan.blockers.isEmpty {
                                    Label("The backend reported safety blockers.", systemImage: "hand.raised.fill")
                                        .foregroundStyle(.red)
                                }
                                Spacer()
                                Button(
                                    model.selectedModuleAction.title,
                                    role: model.selectedModuleAction.isDestructive ? .destructive : nil
                                ) {
                                    Task { await model.executeSelectedModuleAction() }
                                }
                                .disabled(!model.canExecuteModule)
                                .keyboardShortcut(.defaultAction)
                            }
                        } else {
                            Text("Preview the backend plan before executing an action.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                }

                if let result = model.moduleResult {
                    GroupBox("Last result") {
                        HStack {
                            Label(result.status.capitalized, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(result.operation)
                                .font(.body.monospaced())
                            Spacer()
                            Text(result.changed ? "Configuration changed" : "Already in target state")
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                    }
                }
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("No module selected")
                    .font(.headline)
                Text("Refresh the module inventory and select a module.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func planDetails(_ plan: ModulePlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(plan.operation)
                    .font(.headline.monospaced())
                Spacer()
                Text("Schema \(plan.schemaVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            targetList("Exclusive targets", values: plan.exclusiveTargets)
            targetList("Shared contributions", values: plan.contributionTargets)
            targetList("Preserved state", values: plan.preservedState)
            if model.selectedModuleAction == .uninstall || model.selectedModuleAction == .purge {
                targetList("Ephemeral state removed", values: plan.ephemeralState)
            }
            Label(
                plan.sourcePreserved ? "Module source is preserved" : "Module source policy is unknown",
                systemImage: plan.sourcePreserved ? "checkmark.shield" : "questionmark.diamond"
            )
            .font(.caption)
        }
    }

    @ViewBuilder
    private func targetList(_ title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if values.isEmpty {
                Text("None")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(values, id: \.self) { value in
                    Text("• \(value)")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func chooseStateRoot() {
        let panel = NSOpenPanel()
        panel.title = "Choose module state root"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            model.moduleStateRootPath = url.path
        }
    }
}
