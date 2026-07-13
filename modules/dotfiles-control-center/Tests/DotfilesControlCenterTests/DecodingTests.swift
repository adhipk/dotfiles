import XCTest
@testable import DotfilesControlCenter

final class DecodingTests: XCTestCase {
    func testModuleSchemasDecode() throws {
        let decoder = JSONDecoder()
        let status = try decoder.decode([ModuleStatus].self, from: fixtureData("module-status"))
        let plan = try decoder.decode(ModulePlan.self, from: fixtureData("module-plan"))
        let result = try decoder.decode(ModuleActionResult.self, from: fixtureData("module-result"))

        XCTAssertEqual(status.map(\.id), ["alpha", "beta"])
        XCTAssertEqual(plan.schemaVersion, 1)
        XCTAssertEqual(plan.module.dataKey, "modules.alpha")
        XCTAssertTrue(plan.stateRootRequired)
        XCTAssertEqual(result.operation, "module-purge")
        XCTAssertTrue(result.sourcePreserved)
    }

    func testDependencySchemasDecode() throws {
        let decoder = JSONDecoder()
        let status = try decoder.decode(DependencyReport.self, from: fixtureData("deps-status"))
        let check = try decoder.decode(DependencyReport.self, from: fixtureData("deps-check-error"))
        let snapshot = try decoder.decode(DependencySnapshot.self, from: fixtureData("deps-snapshot"))

        XCTAssertEqual(status.summary.total, 2)
        XCTAssertEqual(status.dependencies.map(\.manager), ["homebrew", "neovim"])
        XCTAssertEqual(check.managerErrors, ["brew is unavailable"])
        XCTAssertTrue(snapshot.complete)
        XCTAssertEqual(snapshot.dependencies["homebrew:formula:alpha"]?.resolvedVersion, "1.1.0")
    }

    func testSystemSchemasDecodeAndExposeRestoreCommand() throws {
        let decoder = JSONDecoder()
        let plan = try decoder.decode(SystemUninstallPlan.self, from: fixtureData("uninstall-plan"))
        let ledger = try decoder.decode(SystemUninstallLedger.self, from: fixtureData("uninstall-ledger"))

        XCTAssertEqual(plan.schemaVersion, 1)
        XCTAssertEqual(plan.targets.count, 2)
        XCTAssertEqual(plan.changedTargets, ["bin/alpha"])
        XCTAssertEqual(
            ledger.restoreCommand,
            "'/tmp/test-source/modules/system-uninstall/bin/dotfiles-uninstall' restore '20260713T120000Z-42' --confirm 'RESTORE DOTFILES TO /tmp/test-home'"
        )
    }

    func testAppEnvironmentUsesCapturedWorkingDirectoryAndExplicitToolOverrides() {
        let environment = AppEnvironment.live(
            environment: [
                "HOME": "/tmp/home",
                "DOTFILES_CONTROL_CENTER_CWD": "/tmp",
                "DOTFILES_MODULE_BIN": "/custom/module",
                "DOTFILES_DEPS_BIN": "/custom/deps",
                "DOTFILES_UNINSTALL_BIN": "/custom/uninstall",
            ],
            currentDirectoryPath: "/"
        )

        XCTAssertEqual(environment.workingDirectory.path, "/tmp")
        XCTAssertEqual(environment.tools.module.path, "/custom/module")
        XCTAssertEqual(environment.tools.dependencies.path, "/custom/deps")
        XCTAssertEqual(environment.tools.uninstall.path, "/custom/uninstall")
    }
}
