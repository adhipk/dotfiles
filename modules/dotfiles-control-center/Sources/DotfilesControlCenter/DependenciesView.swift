import SwiftUI

struct DependenciesView: View {
    @ObservedObject var model: AppModel

    private var managers: [String] {
        let values = Set(model.dependencyReport?.dependencies.map(\.manager) ?? [])
        return ["All"] + values.sorted()
    }

    private var filteredDependencies: [Dependency] {
        guard let report = model.dependencyReport else { return [] }
        let query = model.dependencySearch
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return report.dependencies.filter { dependency in
            let managerMatches = model.dependencyManager == "All"
                || dependency.manager == model.dependencyManager
            let textMatches = query.isEmpty || [
                dependency.id,
                dependency.name,
                dependency.manager,
                dependency.kind,
                dependency.state,
                dependency.updateStatus,
                dependency.owners.joined(separator: " "),
            ].joined(separator: " ").lowercased().contains(query)
            return managerMatches && textMatches
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Dependencies and plugins")
                        .font(.title2)
                    Text("Inventory and preview only—this view never installs, updates, removes, or writes the lock file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Offline status") {
                    Task { await model.refreshDependencies(check: false) }
                }
                .disabled(model.isBusy)
                Button("Check now") {
                    Task { await model.refreshDependencies(check: true) }
                }
                .disabled(model.isBusy)
                Button("Preview snapshot") {
                    Task { await model.previewDependencySnapshot() }
                }
                .disabled(model.isBusy)
            }

            if let report = model.dependencyReport {
                summary(report)

                if model.dependencyExitStatus != 0 {
                    Label(
                        "The check returned status \(model.dependencyExitStatus) with \(report.summary.managerErrors) manager error(s). Diagnostic JSON is still shown.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                }

                HStack {
                    TextField("Filter name, state, owner, or update status", text: $model.dependencySearch)
                        .textFieldStyle(.roundedBorder)
                    Picker("Manager", selection: $model.dependencyManager) {
                        ForEach(managers, id: \.self) { manager in
                            Text(manager).tag(manager)
                        }
                    }
                    .frame(width: 190)
                }

                List(filteredDependencies) { dependency in
                    dependencyRow(dependency)
                }
                .frame(minHeight: 260)

                if !report.managerErrors.isEmpty {
                    DisclosureGroup("Manager errors (\(report.managerErrors.count))") {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(report.managerErrors, id: \.self) { error in
                                Text("• \(error)")
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            } else {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("No dependency inventory loaded")
                            .font(.headline)
                    }
                    Spacer()
                }
                Spacer()
            }

            if !model.dependencySnapshotPreview.isEmpty {
                DisclosureGroup("Read-only snapshot preview") {
                    ScrollView([.horizontal, .vertical]) {
                        Text(model.dependencySnapshotPreview)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 220)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(18)
    }

    private func summary(_ report: DependencyReport) -> some View {
        HStack(spacing: 10) {
            summaryItem("Total", report.summary.total, color: .primary)
            summaryItem("Missing", report.summary.missing, color: report.summary.missing > 0 ? .red : .green)
            summaryItem("Outdated", report.summary.outdated, color: report.summary.outdated > 0 ? .orange : .green)
            summaryItem("Drifted", report.summary.drifted, color: report.summary.drifted > 0 ? .orange : .green)
            summaryItem("Unpinned", report.summary.unpinned, color: report.summary.unpinned > 0 ? .orange : .green)
            Spacer()
            Label(report.offline ? "Offline snapshot" : "Live local check", systemImage: report.offline ? "internaldrive" : "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func summaryItem(_ title: String, _ value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func dependencyRow(_ dependency: Dependency) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: dependency.state == "missing" ? "xmark.circle.fill" : "checkmark.circle")
                .foregroundStyle(dependency.state == "missing" ? .red : .green)
            VStack(alignment: .leading, spacing: 3) {
                Text(dependency.name)
                    .font(.body.weight(.medium))
                Text(dependency.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("\(dependency.manager) · \(dependency.kind) · \(dependency.pinStatus)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(dependency.updateStatus)
                    .font(.caption.monospaced())
                    .foregroundStyle(dependency.outdated || dependency.drifted ? .orange : .secondary)
                Text(dependency.installedVersion ?? "not installed")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                if !dependency.owners.isEmpty {
                    Text(dependency.owners.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
