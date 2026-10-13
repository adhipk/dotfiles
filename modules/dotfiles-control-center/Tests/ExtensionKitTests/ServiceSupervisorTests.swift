import XCTest
@testable import ExtensionKit

final class ServiceSupervisorTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("service tests \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func testCrashBudgetPersistsExhaustionAndRotatesOutput() throws {
        let script = "printf 'attempt\\n' >> attempts; /usr/bin/yes x | /usr/bin/head -c 4097; /usr/bin/yes e | /usr/bin/head -c 3073 >&2; exit 7"
        let result = try ServiceSupervisor().run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script], logs: root,
                                                 environment: ["PATH":"/usr/bin:/bin"], directory: root, maxRetries: 2, retryDelay: 0, logLimit: 1024)
        XCTAssertEqual(result, 7)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("attempts")).components(separatedBy: "\n").count - 1, 3)
        let state = try JSONDecoder().decode(ServiceSupervisor.State.self, from: Data(contentsOf: root.appendingPathComponent("state.json")))
        XCTAssertEqual(state.phase, "exhausted"); XCTAssertEqual(state.attempt, 2)
        for channel in ["stdout", "stderr"] {
            for suffix in [".log", ".log.1"] {
                XCTAssertLessThanOrEqual(try Data(contentsOf: root.appendingPathComponent(channel + suffix)).count, 1024)
            }
        }
    }
    func testCleanExitDoesNotRestart() throws {
        let result = try ServiceSupervisor().run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf done"], logs: root,
                                                 environment: [:], directory: root, retryDelay: 0)
        XCTAssertEqual(result, 0)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("stdout.log")), "done")
        let state = try JSONDecoder().decode(ServiceSupervisor.State.self, from: Data(contentsOf: root.appendingPathComponent("state.json")))
        XCTAssertEqual(state.phase, "completed"); XCTAssertEqual(state.attempt, 0)
    }
    func testStopDuringBackoffPreventsRestart() throws {
        let supervisor = ServiceSupervisor(), finished = expectation(description: "Stopped")
        DispatchQueue.global().async {
            defer { finished.fulfill() }
            do {
                let status = try supervisor.run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "exit 3"], logs: self.root,
                                                environment: [:], directory: self.root, retryDelay: 10)
                XCTAssertEqual(status, 0)
            } catch { XCTFail("\(error)") }
        }
        let deadline = Date().addingTimeInterval(3)
        var reachedBackoff = false
        while Date() < deadline {
            if let bytes = try? Data(contentsOf: root.appendingPathComponent("state.json")),
               let state = try? JSONDecoder().decode(ServiceSupervisor.State.self, from: bytes), state.phase == "backoff" { reachedBackoff = true; break }
            Thread.sleep(forTimeInterval: 0.01)
        }
        XCTAssertTrue(reachedBackoff)
        supervisor.stop(); wait(for: [finished], timeout: 3)
        let state = try JSONDecoder().decode(ServiceSupervisor.State.self, from: Data(contentsOf: root.appendingPathComponent("state.json")))
        XCTAssertEqual(state.phase, "stopped")
    }
    func testOversizedExistingLogMigratesToBoundedFiles() throws {
        let file = root.appendingPathComponent("stdout.log")
        try Data(repeating: 120, count: 8192).write(to: file)
        try Data(repeating: 121, count: 8192).write(to: URL(fileURLWithPath: file.path + ".1"))
        let log = try RotatingServiceLog(url: file, limit: 1024)
        try log.append(Data(repeating: 122, count: 3073))
        XCTAssertEqual(try Data(contentsOf: file).count, 1)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: file.path + ".1")).count, 1024)
    }
    func testLaunchFailurePersistsBoundedDiagnostic() throws {
        XCTAssertThrowsError(try ServiceSupervisor().run(executable: root.appendingPathComponent("missing"), arguments: [], logs: root,
            environment: [:], directory: root, retryDelay: 0))
        let state = try JSONDecoder().decode(ServiceSupervisor.State.self, from: Data(contentsOf: root.appendingPathComponent("state.json")))
        XCTAssertEqual(state.phase, "failed")
        XCTAssertFalse(state.error?.isEmpty ?? true)
        XCTAssertLessThanOrEqual(state.error?.count ?? 0, 4096)
    }

}
