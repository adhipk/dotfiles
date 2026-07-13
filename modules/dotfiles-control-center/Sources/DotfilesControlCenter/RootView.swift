import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                ModulesView(model: model)
                    .tabItem { Label("Modules", systemImage: "shippingbox") }
                DependenciesView(model: model)
                    .tabItem { Label("Dependencies", systemImage: "puzzlepiece.extension") }
                SystemUninstallView(model: model)
                    .tabItem { Label("System", systemImage: "externaldrive.badge.xmark") }
            }

            Divider()
            statusBar
        }
        .task {
            await model.loadInitialState()
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if model.isBusy {
                ProgressView()
                    .controlSize(.small)
                Text("Working…")
            } else if let error = model.lastError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .lineLimit(2)
            } else if let notice = model.notice {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
                Text(notice)
                    .lineLimit(1)
            } else {
                Text("Ready")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(model.client.workingDirectory.path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .help("Backend command working directory")
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .frame(minHeight: 32)
    }
}
