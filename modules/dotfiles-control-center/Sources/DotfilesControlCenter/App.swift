import SwiftUI

@main
struct DotfilesControlCenterApp: App {
    @StateObject private var model: AppModel

    init() {
        let environment = AppEnvironment.live()
        let client = CommandClient(
            paths: environment.tools,
            workingDirectory: environment.workingDirectory
        )
        _model = StateObject(wrappedValue: AppModel(client: client))
    }

    var body: some Scene {
        WindowGroup("Dotfiles Control Center") {
            RootView(model: model)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowResizability(.contentMinSize)
    }
}
