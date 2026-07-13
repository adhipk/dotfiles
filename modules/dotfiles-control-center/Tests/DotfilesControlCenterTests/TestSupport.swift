import Foundation
@testable import DotfilesControlCenter

func fixtureData(_ name: String) throws -> Data {
    guard let url = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "Fixtures"
    ) else {
        throw TestSupportError.missingFixture(name)
    }
    return try Data(contentsOf: url)
}

enum TestSupportError: Error {
    case missingFixture(String)
    case missingOutput
}

actor RecordingRunner: CommandRunning {
    struct Invocation: Equatable {
        let executableURL: URL
        let arguments: [String]
        let currentDirectoryURL: URL
    }

    private var queuedOutputs: [CommandOutput]
    private var recordedInvocations: [Invocation] = []

    init(outputs: [CommandOutput]) {
        queuedOutputs = outputs
    }

    var invocations: [Invocation] {
        recordedInvocations
    }

    func run(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL
    ) async throws -> CommandOutput {
        recordedInvocations.append(
            Invocation(
                executableURL: executableURL,
                arguments: arguments,
                currentDirectoryURL: currentDirectoryURL
            )
        )
        guard !queuedOutputs.isEmpty else { throw TestSupportError.missingOutput }
        return queuedOutputs.removeFirst()
    }
}

func fixtureOutput(_ name: String, status: Int32 = 0, stderr: String = "") throws -> CommandOutput {
    CommandOutput(
        stdout: try fixtureData(name),
        stderr: Data(stderr.utf8),
        terminationStatus: status
    )
}

func testClient(runner: any CommandRunning) -> CommandClient {
    CommandClient(
        paths: ToolPaths(
            module: URL(fileURLWithPath: "/test/bin/dotfiles-module"),
            dependencies: URL(fileURLWithPath: "/test/bin/dotfiles-deps"),
            uninstall: URL(fileURLWithPath: "/test/bin/dotfiles-uninstall")
        ),
        workingDirectory: URL(fileURLWithPath: "/test/workspace", isDirectory: true),
        runner: runner
    )
}
