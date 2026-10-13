import SwiftUI

@main
struct DotfilesControlCenterApp: App {
    @StateObject private var utilities = UtilityModel()
    @StateObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    init() {
        let environment = AppEnvironment.live()
        let client = CommandClient(
            paths: environment.tools,
            workingDirectory: environment.workingDirectory
        )
        _model = StateObject(wrappedValue: AppModel(client: client))
    }

    var body: some Scene {
        WindowGroup("Dotfiles", id: "main") {
            RootView(model: model, utilities: utilities)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowResizability(.contentMinSize)
        MenuBarExtra("Dotfiles", systemImage: "square.grid.2x2") {
            Button("Open Dotfiles") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
            Divider()
            Button("Quit Dotfiles") { NSApp.terminate(nil) }
        }
    }
}
