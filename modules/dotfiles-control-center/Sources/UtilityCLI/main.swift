import Foundation
import ExtensionKit

@main struct UtilityCLI {
    static func main() async {
        do { try await run(Array(CommandLine.arguments.dropFirst())) }
        catch { FileHandle.standardError.write(Data("dotfiles-utility: \(error.localizedDescription)\n".utf8)); exit(1) }
    }
    static func run(_ input: [String]) async throws {
        var args = input
        var root: URL?
        if args.first == "--root", args.count >= 3 { root = URL(fileURLWithPath: args[1]); args.removeFirst(2) }
        let store = UtilityStore(root: root)
        let lifecycle = UtilityLifecycle(store: store)
        func record(_ id: String) throws -> InstalledUtility {
            guard let value = try store.list().first(where: { $0.id == id }) else { throw UtilityError("Unknown utility: \(id)") }; return value
        }
        func emit<T: Encodable>(_ value: T) throws {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(value), as: UTF8.self))
        }
        switch args.first {
        case "check" where args.count == 2:
            let path = URL(fileURLWithPath: args[1]); try PackagePaths.validateTree(path)
            try emit(UtilityManifest.load(from: path))
        case "install" where args.count == 2:
            try emit(await lifecycle.install(from: URL(fileURLWithPath: args[1])))
        case "list": try emit(store.list())
        case "enable" where args.count == 2: try await lifecycle.enable(args[1], true)
        case "disable" where args.count == 2: try await lifecycle.enable(args[1], false)
        case "remove" where args.count == 2: try await lifecycle.remove(args[1])
        case "rollback" where args.count == 2: try await lifecycle.rollback(args[1])
        case "recover" where args.count == 1: try await lifecycle.recover()
        case "service" where args.count == 4:
            guard ["start", "stop", "status", "logs"].contains(args[3]) else { throw UtilityError("Service action must be start, stop, status, or logs") }
            if ["start", "stop"].contains(args[3]) {
                try await lifecycle.service(args[1], serviceID: args[2], start: args[3] == "start")
            } else {
                let utility = try record(args[1])
                guard let service = utility.manifest.services?.first(where: { $0.id == args[2] }) else { throw UtilityError("Unknown service") }
                let context = ExecutionContext(utility: utility, store: store)
                if args[3] == "status" { print(try await lifecycle.services.status(service, context: context)) }
                else { print(lifecycle.services.logs(service, context: context)) }
            }
        case "set" where args.count == 4:
            try await lifecycle.configure(args[1], key: args[2], value: args[3])
        case "run" where args.count == 3:
            let utility = try record(args[1]); guard utility.enabled else { throw UtilityError("Utility is disabled") }
            guard let action = utility.manifest.commands.first(where: { $0.id == args[2] }) else { throw UtilityError("Unknown command") }
            guard action.confirmation == nil else { throw UtilityError("Run this action in the app to review its confirmation") }
            var data = Data()
            if action.input == true {
                while let chunk = try FileHandle.standardInput.read(upToCount: 65536), !chunk.isEmpty {
                    data.append(chunk)
                    guard data.count <= 1048576 else { throw UtilityError("Input exceeds 1 MiB") }
                }
            }
            let input = String(decoding: data, as: UTF8.self)
            let result = try await lifecycle.run(utility.id, command: action.id, input: input)
            FileHandle.standardOutput.write(Data(result.output.utf8)); FileHandle.standardError.write(Data(result.error.utf8))
            if result.status != 0 { throw UtilityError("Command exited with status \(result.status)") }
        case "doctor":
            var errors: [String] = []
            for utility in try store.list() {
                do {
                    _ = try UtilityManifest.load(from: store.package(utility))
                    let context = ExecutionContext(utility: utility, store: store)
                    for invocation in utility.manifest.allInvocations { _ = try context.resolve(invocation) }
                } catch { errors.append("\(utility.id): \(error.localizedDescription)") }
            }
            try emit(errors)
            if !errors.isEmpty { throw UtilityError("Dependencies or packages need attention") }
        case "new" where args.count == 3:
            guard UtilityManifest.validID(args[1]) else { throw UtilityError("Invalid utility ID") }
            let path = URL(fileURLWithPath: args[2]); guard !FileManager.default.fileExists(atPath: path.path) else { throw UtilityError("Destination already exists") }
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            let manifest: [String: Any] = ["schemaVersion": 1, "id": args[1], "name": args[1], "version": "0.1.0", "summary": "Replace this sample with your utility.", "commands": [["id": "hello", "title": "Say hello", "invocation": ["tool": "printf", "arguments": ["%s\\n", "Hello from \(args[1])"]]]]]
            try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]).write(to: path.appendingPathComponent("extension.json"))
            print(path.path)
        default:
            print("""
            dotfiles-utility [--root DIRECTORY] COMMAND
              new ID DIRECTORY     Create an independent utility package
              check DIRECTORY      Validate a package without executing it
              install DIRECTORY    Install a trusted local package (initially disabled)
              rollback ID          Restore the retained previous version
              recover              Recover an interrupted lifecycle operation
              service ID NAME ACTION  start, stop, status, or logs
              list                 List installed utilities as JSON
              enable ID            Enable commands
              disable ID           Stop owned services and disable commands
              remove ID            Remove package and services; preserve user data
              set ID KEY VALUE     Validate and save a setting
              run ID COMMAND       Run a noninteractive command
              doctor               Check packages and external tools
            Global shortcuts are provided by the app.
            """)
        }
    }
}
