import Foundation
import ExtensionKit

do {
    let context = try UtilityContext()
    print("Hello, \(context.settings["name"] ?? "world")!")
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}
