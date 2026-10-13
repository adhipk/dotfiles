import Foundation
import Darwin
import ExtensionKit

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 4, args[0] == "--logs", args[2] == "--", args[1].hasPrefix("/"), args[3].hasPrefix("/") else {
    fputs("Usage: dotfiles-service-runner --logs ABSOLUTE_DIRECTORY -- ABSOLUTE_EXECUTABLE [ARGUMENTS]\n", stderr)
    exit(64)
}
let supervisor = ServiceSupervisor()
// Dispatch signal handlers remain active while the main thread waits for the child.
signal(SIGTERM, SIG_IGN); signal(SIGINT, SIG_IGN)
let signals = [SIGTERM, SIGINT].map { number -> DispatchSourceSignal in
    let source = DispatchSource.makeSignalSource(signal: number, queue: .global())
    source.setEventHandler { supervisor.stop() }; source.resume(); return source
}
do {
    let status = try supervisor.run(executable: URL(fileURLWithPath: args[3]), arguments: Array(args.dropFirst(4)),
                                    logs: URL(fileURLWithPath: args[1]), environment: ProcessInfo.processInfo.environment,
                                    directory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    withExtendedLifetime(signals) { exit(status) }
} catch {
    fputs("Service runner: \(error.localizedDescription)\n", stderr)
    exit(1)
}
