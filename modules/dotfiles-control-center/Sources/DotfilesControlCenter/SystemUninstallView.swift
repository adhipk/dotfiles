import SwiftUI

struct SystemUninstallView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Whole-system uninstall")
                            .font(.title2)
                        Text("Back up and remove only the applied dotfiles target state. Source, projects, module state, and ambiguous shared side effects stay preserved.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh plan") {
                        Task { await model.refreshSystemPlan() }
                    }
                    .disabled(model.isBusy)
                }

                if let plan = model.systemPlan {
                    GroupBox("Schema-v\(plan.schemaVersion) safety plan") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 22) {
                                metric("Managed targets", plan.targets.count)
                                metric("Changed targets", plan.changedTargets.count)
                                metric("Safety blockers", plan.blockers.count)
                                Spacer()
                                Label(
                                    plan.executable ? "Executable" : "Blocked",
                                    systemImage: plan.executable ? "checkmark.shield.fill" : "hand.raised.fill"
                                )
                                .foregroundStyle(plan.executable ? .green : .red)
                            }

                            Divider()
                            keyValue("Destination", plan.destination)
                            keyValue("Preserved source", plan.source)

                            DisclosureGroup("Preserved by policy (\(plan.preserved.count))") {
                                valueList(plan.preserved)
                            }
                            DisclosureGroup("Changed targets backed up (\(plan.changedTargets.count))") {
                                valueList(plan.changedTargets)
                            }

                            if !plan.blockers.isEmpty {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Safety blockers")
                                        .font(.headline)
                                        .foregroundStyle(.red)
                                    ForEach(plan.blockers) { blocker in
                                        Text("• \(blocker.path): \(blocker.reason)")
                                            .font(.caption.monospaced())
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                        .padding(8)
                    }

                    GroupBox("Exact confirmation") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Type this destination-bound phrase exactly:")
                            Text(plan.confirmation)
                                .font(.body.monospaced().weight(.semibold))
                                .textSelection(.enabled)
                            TextField(plan.confirmation, text: $model.systemConfirmation)
                                .textFieldStyle(.roundedBorder)
                            HStack {
                                Label("This operation removes installed targets and writes a private backup ledger.", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Spacer()
                                Button("Back up and uninstall", role: .destructive) {
                                    Task { await model.executeSystemUninstall() }
                                }
                                .disabled(!model.canExecuteSystemUninstall)
                            }
                        }
                        .padding(8)
                    }
                } else {
                    Text("Load the backend plan before considering system removal.")
                        .foregroundStyle(.secondary)
                }

                if let ledger = model.systemLedger {
                    GroupBox("Durable uninstall ledger") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label(ledger.status.capitalized, systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(ledger.status == "complete" ? .green : .orange)
                                Text(ledger.id)
                                    .font(.body.monospaced())
                                    .textSelection(.enabled)
                            }
                            keyValue("Backup", ledger.backupPath ?? "Unavailable")
                            Text("Restore from the preserved source")
                                .font(.headline)
                            Text(ledger.restoreCommand)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .textBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(8)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title3.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private func valueList(_ values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if values.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(values, id: \.self) { value in
                    Text("• \(value)")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 5)
    }
}
