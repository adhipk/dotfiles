import XCTest
@testable import DotfilesControlCenter

@MainActor
final class AppModelTests: XCTestCase {
    func testModuleExecutionGatingRequiresPlanStateRootAndExactID() async throws {
        let runner = RecordingRunner(outputs: [try fixtureOutput("module-plan")])
        let model = AppModel(client: testClient(runner: runner))
        model.selectedModuleID = "alpha"
        model.selectedModuleAction = .purge

        await model.loadModulePlan()
        XCTAssertFalse(model.canExecuteModule)

        model.moduleConfirmation = "alpha"
        XCTAssertFalse(model.canExecuteModule)

        model.moduleStateRootPath = "/test/state"
        XCTAssertTrue(model.canExecuteModule)
    }

    func testSystemExecutionGatingRequiresExactDestinationPhrase() async throws {
        let runner = RecordingRunner(outputs: [try fixtureOutput("uninstall-plan")])
        let model = AppModel(client: testClient(runner: runner))

        await model.refreshSystemPlan()
        XCTAssertFalse(model.canExecuteSystemUninstall)

        model.systemConfirmation = "REMOVE DOTFILES FROM /tmp/test-home"
        XCTAssertTrue(model.canExecuteSystemUninstall)
    }
}
