import Foundation

public struct UtilityDependency: Identifiable {
    public let name: String
    public let path: String?
    public var id: String { name }
    public var available: Bool { path != nil }
}

public enum DependencySetup {
    /// Report every external executable, including tool placeholders in arguments.
    public static func dependencies(_ utility: InstalledUtility, store: UtilityStore) -> [UtilityDependency] {
        var names = Set<String>()
        let pattern = try! NSRegularExpression(pattern: "\\{tool:([a-zA-Z0-9_.+-]+)\\}")
        for invocation in utility.manifest.allInvocations {
            if let tool = invocation.tool { names.insert(tool) }
            for value in (invocation.arguments ?? []) + Array((invocation.environment ?? [:]).values) + [invocation.workingDirectory ?? ""] {
                for match in pattern.matches(in: value, range: NSRange(value.startIndex..., in: value)) {
                    if let range = Range(match.range(at: 1), in: value) { names.insert(String(value[range])) }
                }
            }
        }
        let context = ExecutionContext(utility: utility, store: store)
        return names.sorted().map { UtilityDependency(name: $0, path: try? context.tool($0).path) }
    }

    public static func guidance(for id: String) -> String {
        switch id {
        case "dotfiles.markdown-clipboard":
            return "Pandoc is included. Formatting reads your clipboard only when you run the action or start Watch clipboard. Stop the watcher to end clipboard monitoring. No Accessibility permission is needed."
        case "dotfiles.app-focus", "dotfiles.scratchpads":
            return "Install the consumer desktop profile for hotkeys, Ghostty, yabai and skhd. Grant Accessibility to the desktop tools. Space scripting also needs the documented yabai SIP setup; this app never changes SIP."
        case "dotfiles.notifications":
            return "Install the consumer desktop profile for desktop-notify and its notification backend. Allow notifications in macOS System Settings if prompted."
        case "dotfiles.tts":
            return "Install the consumer desktop profile for Kit and its Python runtime. Kit downloads voice models on first use; this needs network access and disk space."
        case "example.hello": return "Uses the macOS printf executable. No additional software or permissions."
        default: return "Install the consumer desktop profile for this utility and its declared runtime dependencies. Your account credentials are configured separately; the app includes no credentials."
        }
    }
}
