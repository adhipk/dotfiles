// man-me: name=whichkey
// man-me: category=Hotkeys and Keybindings
// man-me: usage=Alt+/; whichkey --dump-json [SKHDRC]; whichkey --self-test
// man-me: description=Searchable SwiftUI browser for the live skhd shortcut map.
// man-me: tags=hotkeys keyboard shortcut keybinding skhd whichkey swiftui search
import AppKit
import Combine
import Foundation
import SwiftUI

enum ShortcutCategory: String, CaseIterable, Codable, Identifiable {
    case projects = "Projects"
    case apps = "Apps & Focus"
    case windows = "Windows"
    case spaces = "Spaces & Displays"
    case capture = "Capture"
    case system = "System"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .projects: return "square.grid.2x2"
        case .apps: return "app.badge"
        case .windows: return "macwindow"
        case .spaces: return "rectangle.3.group"
        case .capture: return "camera.viewfinder"
        case .system: return "gearshape"
        }
    }
}

enum ShortcutSearchMode: String, CaseIterable, Identifiable {
    case keys = "Keys"
    case text = "Text"

    var id: String { rawValue }
    var symbol: String { self == .keys ? "keyboard" : "text.magnifyingglass" }
}

struct CapturedKey: Equatable {
    let parts: [String]
    var displayKey: String { parts.joined(separator: " ") }

    init?(event: NSEvent) {
        guard let parts = KeyFormatter.parts(for: event) else { return nil }
        self.parts = parts
    }

    init(parts: [String]) { self.parts = parts }
}

struct ShortcutBinding: Codable, Identifiable, Equatable {
    let id: String
    let owner: String
    let rawKey: String
    let displayKey: String
    let title: String
    let detail: String
    let category: ShortcutCategory
    let command: String
    let sourceSection: String
    let sourceLine: Int

    var keyParts: [String] { KeyFormatter.parts(for: rawKey) }

    func matches(query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        let modifierWords = rawKey
            .replacingOccurrences(of: "rcmd", with: "right command")
            .replacingOccurrences(of: "lcmd", with: "left command")
            .replacingOccurrences(of: "ralt", with: "right option")
            .replacingOccurrences(of: "lalt", with: "left option")
            .replacingOccurrences(of: "rctrl", with: "right control")
            .replacingOccurrences(of: "lctrl", with: "left control")
            .replacingOccurrences(of: "rshift", with: "right shift")
            .replacingOccurrences(of: "lshift", with: "left shift")
            .replacingOccurrences(of: "ctrl", with: "control")
            .replacingOccurrences(of: "alt", with: "option")
            .replacingOccurrences(of: "cmd", with: "command")
        let haystack = [
            rawKey, displayKey, modifierWords, title, detail, category.rawValue,
            command, sourceSection, owner,
        ].joined(separator: " ").lowercased()
        return needle.split(whereSeparator: \.isWhitespace).allSatisfy { haystack.contains($0) }
    }

}

struct ShortcutGroup: Identifiable, Equatable {
    let id: String
    let bindings: [ShortcutBinding]
    let title: String
    let detail: String

    var category: ShortcutCategory { bindings[0].category }
    var sourceSection: String { bindings[0].sourceSection }

    var keySequences: [[String]] {
        let sequences = bindings.map { $0.keyParts }
        guard sequences.count > 2, let first = sequences.first, !first.isEmpty else {
            return uniqueSequences(sequences)
        }
        let prefix = Array(first.dropLast())
        let numberStrings = sequences.compactMap { sequence -> String? in
            guard Array(sequence.dropLast()) == prefix, let last = sequence.last, Int(last) != nil else { return nil }
            return last
        }
        guard numberStrings.count == sequences.count,
              let minimum = numberStrings.compactMap(Int.init).min(),
              let maximum = numberStrings.compactMap(Int.init).max() else {
            return uniqueSequences(sequences)
        }
        return [prefix + [minimum == maximum ? "\(minimum)" : "\(minimum)–\(maximum)"]]
    }

    var implementationText: String {
        let commands = Array(Set(bindings.map(\.command))).sorted()
        if commands.count == 1 { return commands[0] }
        if id == "project-space-number" { return "~/.config/yabai/projects focus-space 1…9" }
        if id == "project-number" { return "~/.config/yabai/projects focus-project 1…5" }
        if id == "project-adopt-number" { return "~/.config/yabai/projects adopt --project-slot 1…5" }
        return "\(commands.count) related skhd commands"
    }

    var sourceLocation: String {
        let lines = bindings.map(\.sourceLine).sorted()
        guard let first = lines.first, let last = lines.last else { return sourceSection }
        if first == last { return "\(sourceSection) · line \(first)" }
        let contiguous = zip(lines, lines.dropFirst()).allSatisfy { $1 == $0 + 1 }
        return contiguous
            ? "\(sourceSection) · lines \(first)–\(last)"
            : "\(sourceSection) · lines \(lines.map(String.init).joined(separator: ", "))"
    }

    func matches(query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        if "\(title) \(detail) \(category.rawValue)".lowercased().contains(needle) { return true }
        return bindings.contains { $0.matches(query: query) }
    }

    func matches(capturedKey: CapturedKey) -> Bool {
        if capturedKey.parts.count == 1, let key = capturedKey.parts.last {
            return bindings.contains { $0.keyParts.last == key }
        }
        // AppKit's device-independent flags do not retain which physical
        // modifier side was pressed. Treat a captured generic modifier as a
        // match for either sided binding so RCmd+D still finds R⌘ D.
        let capturedParts = unsidedModifierParts(capturedKey.parts)
        return bindings.contains { unsidedModifierParts($0.keyParts) == capturedParts }
    }

    private func unsidedModifierParts(_ parts: [String]) -> [String] {
        parts.map {
            switch $0 {
            case "L⌃", "R⌃": return "⌃"
            case "L⌥", "R⌥": return "⌥"
            case "L⌘", "R⌘": return "⌘"
            case "L⇧", "R⇧": return "⇧"
            default: return $0
            }
        }
    }

    private func uniqueSequences(_ sequences: [[String]]) -> [[String]] {
        var seen = Set<String>()
        return sequences.filter { seen.insert($0.joined(separator: "\u{1f}")).inserted }
    }
}

enum ShortcutGrouper {
    static func groups(from bindings: [ShortcutBinding]) -> [ShortcutGroup] {
        var order: [String] = []
        var grouped: [String: [ShortcutBinding]] = [:]
        for binding in bindings {
            let key = groupKey(for: binding)
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(binding)
        }
        return order.compactMap { key in
            guard let members = grouped[key], let first = members.first else { return nil }
            let text = groupText(for: key, fallback: first)
            return ShortcutGroup(id: key, bindings: members, title: text.title, detail: text.detail)
        }
    }

    private static func groupKey(for binding: ShortcutBinding) -> String {
        let command = binding.command.lowercased()
        if command.range(of: #"focus-space\s+\d+$"#, options: .regularExpression) != nil {
            return "project-space-number"
        }
        if command.range(of: #"focus-project\s+\d+$"#, options: .regularExpression) != nil {
            return "project-number"
        }
        if command.range(of: #"adopt\s+--project-slot\s+\d+$"#, options: .regularExpression) != nil {
            return "project-adopt-number"
        }
        return [binding.category.rawValue, binding.title, binding.command].joined(separator: "\u{1f}")
    }

    private static func groupText(for key: String, fallback: ShortcutBinding) -> ActionInfo {
        switch key {
        case "project-space-number":
            return ActionInfo(title: "Open project Space 1–9", detail: "Jump to a numbered Space shortcut in the active project.")
        case "project-number":
            return ActionInfo(title: "Switch to project 1–5", detail: "Open the last-used Space for a Hyper project slot.")
        case "project-adopt-number":
            return ActionInfo(title: "Adopt Space into project 1–5", detail: "Attach the current Space to a Hyper project slot.")
        default:
            return ActionInfo(title: fallback.title, detail: fallback.detail)
        }
    }
}

struct ActionInfo {
    let title: String
    let detail: String
}

struct ParserContext {
    var section = "Other"
    var subsection = ""
    var owner = "root"
}

private struct LogicalLine {
    let number: Int
    let text: String
}

private struct ParsedBinding {
    let key: String
    let command: String
    let comment: String
    let contextDetail: String?
}

enum SKHDParser {
    static func parseFile(at path: String) throws -> [ShortcutBinding] {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return parse(content)
    }

    static func parse(_ content: String) -> [ShortcutBinding] {
        let lines = logicalLines(in: content)
        var context = ParserContext()
        var afterDivider = false
        var bindings: [ShortcutBinding] = []

        var lineIndex = 0
        while lineIndex < lines.count {
            let logicalLine = lines[lineIndex]
            let line = logicalLine.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                lineIndex += 1
                continue
            }

            if line.hasPrefix("#") {
                let comment = line.dropFirst().trimmingCharacters(in: .whitespaces)
                if comment.hasPrefix("dotfiles-owner:") {
                    context.owner = comment
                        .dropFirst("dotfiles-owner:".count)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    lineIndex += 1
                    continue
                }
                if isDivider(comment) {
                    afterDivider = true
                    lineIndex += 1
                    continue
                }
                if let subsection = subsectionTitle(from: comment) {
                    context.subsection = subsection
                    afterDivider = false
                    lineIndex += 1
                    continue
                }
                if afterDivider, !comment.isEmpty, !comment.hasPrefix("man-me:") {
                    context.section = normalizedSection(String(comment))
                    context.subsection = ""
                    afterDivider = false
                }
                lineIndex += 1
                continue
            }

            afterDivider = false
            let parsed: ParsedBinding?
            if let processMap = parseProcessMap(startingAt: lineIndex, in: lines) {
                parsed = processMap.binding
                lineIndex += processMap.consumedLineCount
            } else {
                parsed = parseBindingLine(line)
                lineIndex += 1
            }
            guard let parsed else { continue }
            if parsed.comment.contains("whichkey-internal") { continue }
            let category = category(for: context, command: parsed.command)
            let describedAction = ActionDescriber.describe(
                rawKey: parsed.key,
                command: parsed.command,
                inlineComment: parsed.comment,
                context: context
            )
            let action = ActionInfo(
                title: describedAction.title,
                detail: [describedAction.detail, parsed.contextDetail]
                    .compactMap { $0 }
                    .joined(separator: " ")
            )
            let displayKey = KeyFormatter.display(for: parsed.key)
            let id = "\(logicalLine.number):\(parsed.key):\(parsed.command)"
            bindings.append(ShortcutBinding(
                id: id,
                owner: context.owner,
                rawKey: parsed.key,
                displayKey: displayKey,
                title: action.title,
                detail: action.detail,
                category: category,
                command: parsed.command,
                sourceSection: context.subsection.isEmpty ? context.section : context.subsection,
                sourceLine: logicalLine.number
            ))
        }

        return bindings
    }

    private static func logicalLines(in content: String) -> [LogicalLine] {
        let physicalLines = content.components(separatedBy: .newlines)
        var result: [LogicalLine] = []
        var buffer = ""
        var startLine = 0

        for (offset, physical) in physicalLines.enumerated() {
            let lineNumber = offset + 1
            let trimmed = physical.trimmingCharacters(in: .whitespaces)
            let continues = trimmed.hasSuffix("\\")
            let fragment = continues
                ? String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
                : trimmed

            if buffer.isEmpty {
                startLine = lineNumber
                buffer = fragment
            } else {
                buffer += " " + fragment
            }

            if !continues {
                result.append(LogicalLine(number: startLine, text: buffer))
                buffer = ""
            }
        }

        if !buffer.isEmpty {
            result.append(LogicalLine(number: startLine, text: buffer))
        }
        return result
    }

    private static func isDivider(_ comment: String) -> Bool {
        let stripped = comment.replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
        return stripped.isEmpty && comment.contains("=")
    }

    private static func subsectionTitle(from comment: String) -> String? {
        guard comment.hasPrefix("--"), comment.hasSuffix("--") else { return nil }
        let start = comment.index(comment.startIndex, offsetBy: 2)
        let end = comment.index(comment.endIndex, offsetBy: -2)
        return comment[start..<end].trimmingCharacters(in: .whitespaces)
    }

    private static func normalizedSection(_ title: String) -> String {
        if title.localizedCaseInsensitiveContains("Window Management") { return "Window Management" }
        if title.localizedCaseInsensitiveContains("Space management") { return "Space Management" }
        if title.localizedCaseInsensitiveContains("App Focus") { return "App Focus" }
        if title.localizedCaseInsensitiveContains("Screenshots") { return "Screenshots" }
        if title.localizedCaseInsensitiveContains("Window close") { return "Window Actions" }
        if title.localizedCaseInsensitiveContains("Restart") { return "System" }
        if title.localizedCaseInsensitiveContains("Which-key") { return "Shortcut Guide" }
        return title
    }

    private static func parseBindingLine(_ line: String) -> ParsedBinding? {
        if line.hasPrefix("::") { return nil }
        if line.range(of: #"^[A-Za-z0-9_]+\s*<"#, options: .regularExpression) != nil { return nil }

        let (withoutComment, comment) = splitInlineComment(line)
        if let separator = firstUnquotedSeparator(in: withoutComment, character: ":") {
            let key = withoutComment[..<separator].trimmingCharacters(in: .whitespaces)
            let commandStart = withoutComment.index(after: separator)
            let command = withoutComment[commandStart...].trimmingCharacters(in: .whitespaces)
            guard isShortcutKey(key), !command.isEmpty else { return nil }
            return ParsedBinding(key: key, command: command, comment: comment, contextDetail: nil)
        }

        if let separator = firstUnquotedSeparator(in: withoutComment, character: ";") {
            let key = withoutComment[..<separator].trimmingCharacters(in: .whitespaces)
            let commandStart = withoutComment.index(after: separator)
            let mode = withoutComment[commandStart...].trimmingCharacters(in: .whitespaces)
            guard isShortcutKey(key), !mode.isEmpty else { return nil }
            return ParsedBinding(key: key, command: "mode:\(mode)", comment: comment, contextDetail: nil)
        }
        return nil
    }

    private static func parseProcessMap(
        startingAt startIndex: Int,
        in lines: [LogicalLine]
    ) -> (binding: ParsedBinding?, consumedLineCount: Int)? {
        let header = lines[startIndex].text.trimmingCharacters(in: .whitespacesAndNewlines)
        let (headerWithoutComment, _) = splitInlineComment(header)
        guard headerWithoutComment.hasSuffix("[") else { return nil }

        let key = headerWithoutComment.dropLast().trimmingCharacters(in: .whitespaces)
        guard isShortcutKey(key) else { return nil }

        var passthroughApps: [String] = []
        var applicationCommand: (application: String, command: String, comment: String)?
        var wildcardPassthrough = false
        var wildcardCommand: String?
        var wildcardComment = ""
        var index = startIndex + 1

        while index < lines.count {
            let entry = lines[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
            if entry == "]" {
                let consumedLineCount = index - startIndex + 1
                if let wildcardCommand {
                    let contextDetail: String?
                    if passthroughApps.isEmpty {
                        contextDetail = nil
                    } else {
                        let apps = friendlyList(passthroughApps)
                        let receives = passthroughApps.count == 1 ? "receives" : "receive"
                        contextDetail = "The global action runs outside \(apps); \(apps) \(receives) the chord directly."
                    }
                    return (
                        ParsedBinding(
                            key: key,
                            command: wildcardCommand,
                            comment: wildcardComment,
                            contextDetail: contextDetail
                        ),
                        consumedLineCount
                    )
                }

                if wildcardPassthrough, let applicationCommand {
                    return (
                        ParsedBinding(
                            key: key,
                            command: applicationCommand.command,
                            comment: applicationCommand.comment,
                            contextDetail: "Runs only in \(applicationCommand.application); every other app receives the chord directly."
                        ),
                        consumedLineCount
                    )
                }

                return (nil, consumedLineCount)
            }

            let (entryWithoutComment, comment) = splitInlineComment(entry)
            if wildcardPassthroughEntry(entryWithoutComment) {
                wildcardPassthrough = true
            } else if let application = passthroughApplication(from: entryWithoutComment) {
                passthroughApps.append(application)
            } else if let separator = firstUnquotedSeparator(in: entryWithoutComment, character: ":") {
                let selector = entryWithoutComment[..<separator].trimmingCharacters(in: .whitespaces)
                let commandStart = entryWithoutComment.index(after: separator)
                let command = entryWithoutComment[commandStart...].trimmingCharacters(in: .whitespaces)
                if selector == "*", !command.isEmpty {
                    wildcardCommand = command
                    wildcardComment = comment
                } else if let application = applicationName(from: selector), !command.isEmpty {
                    applicationCommand = (application, command, comment)
                }
            }
            index += 1
        }

        return nil
    }

    private static func passthroughApplication(from entry: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"^\"([^\"]+)\"\s*~$"#) else { return nil }
        let range = NSRange(entry.startIndex..., in: entry)
        guard let match = regex.firstMatch(in: entry, range: range),
              let applicationRange = Range(match.range(at: 1), in: entry) else { return nil }
        return String(entry[applicationRange])
    }

    private static func wildcardPassthroughEntry(_ entry: String) -> Bool {
        entry.range(of: #"^\*\s*~$"#, options: .regularExpression) != nil
    }

    private static func applicationName(from selector: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"^\"([^\"]+)\"$"#) else { return nil }
        let range = NSRange(selector.startIndex..., in: selector)
        guard let match = regex.firstMatch(in: selector, range: range),
              let applicationRange = Range(match.range(at: 1), in: selector) else { return nil }
        return String(selector[applicationRange])
    }

    private static func friendlyList(_ values: [String]) -> String {
        let unique = values.reduce(into: [String]()) { result, value in
            if !result.contains(value) { result.append(value) }
        }
        guard unique.count > 1 else { return unique.first ?? "the excluded app" }
        if unique.count == 2 { return unique.joined(separator: " and ") }
        return unique.dropLast().joined(separator: ", ") + ", and " + unique.last!
    }

    private static func isShortcutKey(_ key: String) -> Bool {
        guard key.contains(" - ") else { return false }
        let lower = key.lowercased()
        return ["alt", "ctrl", "cmd", "shift", "fn"].contains { lower.contains($0) }
    }

    private static func firstUnquotedSeparator(in text: String, character: Character) -> String.Index? {
        var quote: Character?
        var escaped = false
        for index in text.indices {
            let value = text[index]
            if escaped {
                escaped = false
                continue
            }
            if value == "\\" {
                escaped = true
                continue
            }
            if value == "\"" || value == "'" {
                if quote == value { quote = nil }
                else if quote == nil { quote = value }
                continue
            }
            if quote == nil, value == character { return index }
        }
        return nil
    }

    private static func splitInlineComment(_ line: String) -> (String, String) {
        guard let index = firstUnquotedSeparator(in: line, character: "#") else {
            return (line, "")
        }
        let before = line[..<index].trimmingCharacters(in: .whitespaces)
        let afterIndex = line.index(after: index)
        let after = line[afterIndex...].trimmingCharacters(in: .whitespaces)
        return (before, after)
    }

    private static func category(for context: ParserContext, command: String) -> ShortcutCategory {
        let source = "\(context.section) \(context.subsection) \(command)".lowercased()
        if source.contains("/projects ") || source.contains("project shortcuts") ||
            source.contains("space shortcuts") || source.contains("space_slot_mode") {
            return .projects
        }
        if source.contains("screenshot") {
            return .capture
        }
        if source.contains("window management") || source.contains("window close") ||
            source.contains("window actions") || command.contains("yabai -m window --") ||
            command.contains("snap_window") || command.contains("float-prefs") {
            return .windows
        }
        if source.contains("space management") || command.contains("create-space") ||
            command.contains("close_empty_spaces") || command.contains("--display") {
            return .spaces
        }
        if source.contains("app focus") || command.contains("focus_app") || command.contains("app-focus") ||
            command.contains("scratchpads") || command.contains("presentation") || command.contains("zen toggle") ||
            command.contains("terminal new") {
            return .apps
        }
        return .system
    }
}

enum KeyFormatter {
    private static let keyCodes: [String: String] = [
        "0x32": "`",
        "0x2C": "/",
        "0x21": "[",
        "0x1E": "]",
        "0x33": "⌫",
        "0x2B": ",",
        "0x2A": "\\",
        "0x18": "=",
        "0x1B": "-",
    ]

    static func display(for raw: String) -> String { parts(for: raw).joined(separator: " ") }

    static func parts(for raw: String) -> [String] {
        let pieces = raw.components(separatedBy: " - ")
        guard pieces.count >= 2 else { return [raw] }
        let modifierTokens = pieces[0]
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let keyToken = pieces.dropFirst().joined(separator: " - ")
            .trimmingCharacters(in: .whitespaces)

        var parts: [String] = []
        let hasHyper = modifierTokens.contains("ctrl") && modifierTokens.contains("alt") && modifierTokens.contains("cmd")
        if hasHyper {
            parts.append("Hyper")
        } else {
            if modifierTokens.contains("lctrl") { parts.append("L⌃") }
            if modifierTokens.contains("rctrl") { parts.append("R⌃") }
            if modifierTokens.contains("ctrl") { parts.append("⌃") }
            if modifierTokens.contains("lalt") { parts.append("L⌥") }
            if modifierTokens.contains("ralt") { parts.append("R⌥") }
            if modifierTokens.contains("alt") { parts.append("⌥") }
            if modifierTokens.contains("lcmd") { parts.append("L⌘") }
            if modifierTokens.contains("rcmd") { parts.append("R⌘") }
            if modifierTokens.contains("cmd") { parts.append("⌘") }
        }
        if modifierTokens.contains("lshift") { parts.append("L⇧") }
        if modifierTokens.contains("rshift") { parts.append("R⇧") }
        if modifierTokens.contains("shift") { parts.append("⇧") }
        if modifierTokens.contains("fn") { parts.append("fn") }
        parts.append(formatKeyToken(keyToken))
        return parts
    }

    static func parts(for event: NSEvent) -> [String]? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasControl = flags.contains(.control)
        let hasOption = flags.contains(.option)
        let hasCommand = flags.contains(.command)
        var parts: [String] = []

        if hasControl && hasOption && hasCommand {
            parts.append("Hyper")
        } else {
            if hasControl { parts.append("⌃") }
            if hasOption { parts.append("⌥") }
            if hasCommand { parts.append("⌘") }
        }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.function) { parts.append("fn") }

        let specialKeys: [UInt16: String] = [
            24: "=", 27: "-", 30: "]", 33: "[", 36: "↩", 42: "\\",
            43: ",", 44: "/", 48: "⇥", 50: "`", 51: "⌫",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        let key: String
        if let special = specialKeys[event.keyCode] {
            key = special
        } else if let characters = event.charactersIgnoringModifiers, !characters.isEmpty {
            let scalar = String(characters.prefix(1))
            guard !scalar.unicodeScalars.allSatisfy({ CharacterSet.controlCharacters.contains($0) }) else { return nil }
            key = scalar.uppercased()
        } else {
            return nil
        }
        parts.append(key)
        return parts
    }

    private static func formatKeyToken(_ token: String) -> String {
        if let mapped = keyCodes[token] { return mapped }
        switch token.lowercased() {
        case "left": return "←"
        case "right": return "→"
        case "up": return "↑"
        case "down": return "↓"
        case "return": return "↩"
        case "tab": return "⇥"
        case "escape": return "Esc"
        case "space": return "Space"
        default:
            return token.count == 1 ? token.uppercased() : token.capitalized
        }
    }
}

enum ActionDescriber {
    static func describe(
        rawKey: String,
        command: String,
        inlineComment: String,
        context: ParserContext
    ) -> ActionInfo {
        let lower = command.lowercased()

        if lower.contains("stack.next") {
            return info("Next stacked window", "Focus the next window in the current stack.")
        }
        if lower.contains("stack.prev") {
            return info("Previous stacked window", "Focus the previous window in the current stack.")
        }
        if lower.contains("snap_window.sh left") { return info("Snap window left", "Fill the left half of the display.") }
        if lower.contains("snap_window.sh right") { return info("Snap window right", "Fill the right half of the display.") }
        if let direction = argument(after: "--swap", in: command) {
            return info("Swap window \(friendlyDirection(direction))", "Exchange the focused window with its \(friendlyDirection(direction)) neighbor.")
        }
        if lower.contains("--resize") {
            if lower.contains("left:-") { return info("Grow window left", "Expand the focused window toward the left.") }
            if lower.contains("right:100") { return info("Grow window right", "Expand the focused window toward the right.") }
            if lower.contains("top:0:-") { return info("Grow window up", "Expand the focused window upward.") }
            if lower.contains("bottom:0:100") { return info("Grow window down", "Expand the focused window downward.") }
        }
        if lower.contains("zoom-fullscreen") { return info("Toggle window fullscreen", "Zoom the focused window without leaving the current Space.") }
        if lower.contains("--toggle split") { return info("Flip split direction", "Switch the current BSP split between horizontal and vertical.") }
        if lower.contains("space --balance") { return info("Balance windows", "Evenly rebalance the current BSP layout.") }
        if lower.contains("space --rotate") { return info("Rotate layout", "Rotate the current BSP tree by 90 degrees.") }
        if lower.contains("--mirror x-axis") { return info("Mirror layout horizontally", "Flip the current window layout across its horizontal axis.") }
        if lower.contains("--mirror y-axis") { return info("Mirror layout vertically", "Flip the current window layout across its vertical axis.") }
        if lower.contains("float-prefs toggle") { return info("Toggle floating window", "Float or tile this window and remember the choice for its app and title.") }
        if lower.contains("window --stack west") { return info("Stack window left", "Add the focused window to the stack on its left.") }
        if lower.contains("space --layout") { return info("Toggle BSP / stack layout", "Switch the current Space between tiled BSP and stacked layouts.") }

        if lower.hasPrefix("mode:space_slot_mode") {
            return info("Assign a project-space shortcut", "Choose a number from 1–9 for the current Space.")
        }
        if lower.hasPrefix("mode:clear_space_slot_mode") {
            return info("Clear a project-space shortcut", "Choose a number from 1–9 to remove that Space shortcut.")
        }
        if lower.hasPrefix("mode:shortcut_help") {
            return info("Open shortcut guide", "Search the live shortcut map with text or by pressing a key chord.")
        }
        if lower.contains("/projects cycle prev") { return info("Previous project Space", "Move to the previous Space in the active project.") }
        if lower.contains("/projects cycle next") { return info("Next project Space", "Move to the next Space in the active project.") }
        if let number = capture(#"focus-space\s+(\d+)"#, in: command) {
            return info("Open project Space \(number)", "Jump to Space shortcut \(number) in the active project.")
        }
        if lower.contains("/projects show") { return info("Show project status", "Display the active project and its Space shortcuts.") }
        if let number = capture(#"focus-project\s+(\d+)"#, in: command) {
            return info("Switch to project \(number)", "Open the last-used Space for Hyper project slot \(number).")
        }
        if let number = capture(#"adopt\s+--project-slot\s+(\d+)"#, in: command) {
            return info("Adopt Space into project \(number)", "Attach the current Space to Hyper project slot \(number).")
        }
        if lower.contains("/projects adopt") { return info("Adopt current Space", "Attach the current Space to the active project.") }
        if lower.contains("/projects pick") { return info("Open ProjectDeck", "Search projects, switch Spaces, or manage project context.") }
        if lower.contains("/projects new") { return info("Create a project", "Name a project and adopt the current Space.") }
        if lower.contains("/projects detach") { return info("Detach current Space", "Remove the current Space from its project context.") }

        if lower.contains("window --display prev") { return info("Move window to previous display", "Keep focus on the window after moving it.") }
        if lower.contains("window --display next") { return info("Move window to next display", "Keep focus on the window after moving it.") }
        if lower.contains("window --display 1") { return info("Move window to display 1", "Move the focused window to the first display and keep focus.") }
        if lower.contains("window --display 2") { return info("Move window to display 2", "Move the focused window to the second display and keep focus.") }
        if lower.contains("create-space move-window") { return info("Move window to a new Space", "Create a Space, move the focused window there, and focus it.") }
        if lower.contains("create-space auto") { return info("Create a new Space", "Create and focus a Space; move the focused non-scratchpad window when it is safe.") }
        if lower.contains("close_empty_spaces") { return info("Close empty Spaces", "Remove empty Spaces while keeping at least one available.") }

        if lower.contains("focus_app") && lower.contains("ghostty") { return info("Focus Ghostty", "Focus or cycle normal Ghostty windows; scratchpads stay excluded.") }
        if lower.contains("app-focus") && lower.contains("@browser") { return info("Focus browser", "Focus or cycle windows for the default browser.") }
        if lower.contains("app-focus") && lower.contains("@editor") { return info("Focus editor", "Focus or cycle windows for the configured editor.") }
        if lower.contains("app-focus") {
            let app = lastQuotedValue(in: command) ?? "app"
            return info("Focus \(app)", "Focus or cycle \(app) windows.")
        }
        if lower.contains("scratchpads open codex") { return info("Open dotfiles scratchpad", "Toggle the black terminal scratchpad on the dotfiles tmux session.") }
        if lower.contains("scratchpads open projects") { return info("Open projects scratchpad", "Toggle the black terminal scratchpad on the projects tmux session.") }
        if lower.contains("presentation toggle") { return info("Toggle presentation mode", "Switch the desktop between normal and presentation behavior.") }
        if lower.contains("zen toggle") { return info("Toggle zen mode", "Temporarily disable distracting app-focus shortcuts.") }
        if lower.contains("terminal new") { return info("Open a new terminal", "Create a normal Ghostty window on the focused Space.") }

        if lower.contains(#"skhd -k "cmd + shift - 3""#) { return info("Save full-screen screenshot", "Use macOS’ native full-screen capture.") }
        if lower.contains(#"skhd -k "ctrl + cmd + shift - 3""#) { return info("Copy full-screen screenshot", "Copy a full-screen capture to the clipboard.") }
        if lower.contains(#"skhd -k "cmd + shift - 4""#) { return info("Save selection screenshot", "Use macOS’ interactive area or window capture.") }
        if lower.contains(#"skhd -k "ctrl + cmd + shift - 4""#) { return info("Copy selection screenshot", "Copy an interactive area or window capture.") }

        if lower.contains("window --close") { return info("Close window", "Close the focused window.") }
        if lower.contains("window --minimize") { return info("Minimize window", "Minimize the focused window.") }
        if lower.contains("yabai --restart-service") { return info("Restart window shortcuts", "Restart yabai and skhd after configuration changes.") }
        if lower.contains("show_keys.sh") { return info("Open shortcut guide", "Search and browse the live skhd shortcut map.") }

        if !inlineComment.isEmpty, !inlineComment.contains("+") {
            return info(sentenceCase(inlineComment), "Defined in \(context.section).")
        }
        if !context.subsection.isEmpty {
            return info(sentenceCase(context.subsection), "Defined in \(context.section).")
        }
        let executable = command.split(separator: " ").first.map(String.init) ?? "Shortcut"
        let fallback = URL(fileURLWithPath: executable).lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return info(sentenceCase(fallback), "Defined in \(context.section).")
    }

    private static func info(_ title: String, _ detail: String) -> ActionInfo {
        ActionInfo(title: title, detail: detail)
    }

    private static func friendlyDirection(_ raw: String) -> String {
        switch raw.lowercased() {
        case "west": return "left"
        case "east": return "right"
        case "north": return "up"
        case "south": return "down"
        default: return raw
        }
    }

    private static func argument(after flag: String, in command: String) -> String? {
        let tokens = command.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let index = tokens.firstIndex(of: flag), index + 1 < tokens.count else { return nil }
        return tokens[index + 1]
    }

    private static func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }

    private static func lastQuotedValue(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #""([^"]+)""#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard let match = matches.last, let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }

    private static func sentenceCase(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}

@MainActor
final class ShortcutViewModel: ObservableObject {
    @Published var query = ""
    @Published var searchMode: ShortcutSearchMode = .keys
    @Published var capturedKey: CapturedKey?
    @Published var selectedCategory: ShortcutCategory?
    @Published var selectedIndex = 0
    @Published var focusSearchToken = 0

    let bindings: [ShortcutBinding]
    let groups: [ShortcutGroup]
    let sourcePath: String
    let loadError: String?

    init(bindings: [ShortcutBinding], sourcePath: String, loadError: String? = nil) {
        self.bindings = bindings
        groups = ShortcutGrouper.groups(from: bindings)
        self.sourcePath = sourcePath
        self.loadError = loadError
    }

    var filteredGroups: [ShortcutGroup] {
        groups.filter { group in
            let categoryMatches = selectedCategory == nil || group.category == selectedCategory
            let searchMatches: Bool
            switch searchMode {
            case .text:
                searchMatches = group.matches(query: query)
            case .keys:
                searchMatches = capturedKey.map { group.matches(capturedKey: $0) } ?? true
            }
            return categoryMatches && searchMatches
        }
    }

    var selectedGroup: ShortcutGroup? {
        guard !filteredGroups.isEmpty else { return nil }
        return filteredGroups[min(max(selectedIndex, 0), filteredGroups.count - 1)]
    }

    func count(for category: ShortcutCategory?) -> Int {
        guard let category else { return groups.count }
        return groups.filter { $0.category == category }.count
    }

    func selectCategory(_ category: ShortcutCategory?) {
        selectedCategory = category
        selectedIndex = 0
    }

    func moveCategory(_ delta: Int) {
        let categories: [ShortcutCategory?] = [nil] + ShortcutCategory.allCases.map(Optional.some)
        let current = categories.firstIndex { $0 == selectedCategory } ?? 0
        let next = (current + delta + categories.count) % categories.count
        selectCategory(categories[next])
    }

    func moveSelection(_ delta: Int) {
        guard !filteredGroups.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + filteredGroups.count) % filteredGroups.count
    }

    func select(_ group: ShortcutGroup) {
        if let index = filteredGroups.firstIndex(of: group) { selectedIndex = index }
    }

    func resetSelection() { selectedIndex = 0 }

    func selectSearchMode(_ mode: ShortcutSearchMode) {
        searchMode = mode
        if mode == .keys { query = "" }
        else { capturedKey = nil }
        resetSelection()
        if mode == .text { focusSearchToken += 1 }
    }

    func focusSearch() { selectSearchMode(.text) }

    func capture(_ key: CapturedKey) {
        searchMode = .keys
        capturedKey = key
        resetSelection()
    }

    func clearSearch() {
        query = ""
        capturedKey = nil
        resetSelection()
    }
}

@MainActor
final class ShortcutGuideController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var keyMonitor: Any?
    private var model: ShortcutViewModel?
    private var didFinish = false

    func run() -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let sourcePath = ProcessInfo.processInfo.environment["WHICHKEY_SKHDRC"]
            ?? (NSHomeDirectory() + "/.skhdrc")
        let bindings: [ShortcutBinding]
        let loadError: String?
        do {
            bindings = try SKHDParser.parseFile(at: sourcePath)
            loadError = nil
        } catch {
            bindings = []
            loadError = "Could not read \(abbreviate(path: sourcePath)): \(error.localizedDescription)"
        }

        present(bindings: bindings, sourcePath: sourcePath, loadError: loadError)
        app.run()
        return 0
    }

    private func present(bindings: [ShortcutBinding], sourcePath: String, loadError: String?) {
        let targetScreen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let width = min(CGFloat(960), visibleFrame.width - 64)
        let height = min(CGFloat(640), visibleFrame.height - 64)
        let rect = NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )

        let model = ShortcutViewModel(bindings: bindings, sourcePath: sourcePath, loadError: loadError)
        let hosting = NSHostingView(rootView: ShortcutGuideView(model: model))
        hosting.frame = NSRect(origin: .zero, size: rect.size)

        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.delegate = self
        panel.contentView = hosting
        panel.makeKeyAndOrderFront(nil)

        self.model = model
        self.panel = panel
        installKeyMonitor(for: model)
    }

    private func installKeyMonitor(for model: ShortcutViewModel) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isKeyWindow == true else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isOptionOnly = flags.contains(.option) &&
                !flags.contains(.control) && !flags.contains(.command) &&
                !flags.contains(.shift) && !flags.contains(.function)

            if isOptionOnly {
                switch event.keyCode {
                case 125:
                    model.moveSelection(1)
                    return nil
                case 126:
                    model.moveSelection(-1)
                    return nil
                case 123:
                    model.moveCategory(-1)
                    return nil
                case 124:
                    model.moveCategory(1)
                    return nil
                default:
                    break
                }
                if let key = event.charactersIgnoringModifiers?.lowercased() {
                    switch key {
                    case "f":
                        model.selectSearchMode(.text)
                        return nil
                    case "p":
                        model.selectSearchMode(.keys)
                        return nil
                    case "c":
                        model.clearSearch()
                        return nil
                    default:
                        break
                    }
                }
            }

            if event.keyCode == 53 {
                self.close()
                return nil
            }

            if model.searchMode == .keys {
                if flags.intersection([.control, .option, .command, .shift, .function]).isEmpty,
                   let key = CapturedKey(event: event) {
                    model.capture(key)
                    return nil
                }
            }
            return event
        }
    }

    private func close() {
        guard !didFinish else { return }
        didFinish = true
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        panel?.orderOut(nil)
        NSApp.terminate(nil)
    }

    func windowWillClose(_ notification: Notification) { close() }

    private func abbreviate(path: String) -> String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}

struct ShortcutGuideView: View {
    @ObservedObject var model: ShortcutViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            VisualEffectBackground()
            VStack(spacing: 0) {
                header
                Divider().opacity(0.5)
                HStack(spacing: 0) {
                    sidebar
                    Divider().opacity(0.5)
                    results
                    Divider().opacity(0.5)
                    details
                }
                footer
            }
        }
        .frame(minWidth: 820, minHeight: 520)
        .onAppear { searchFocused = model.searchMode == .text }
        .onChange(of: model.query) { _, _ in model.resetSelection() }
        .onChange(of: model.focusSearchToken) { _, _ in searchFocused = true }
        .onChange(of: model.searchMode) { _, mode in searchFocused = mode == .text }
        .onExitCommand {
            model.clearSearch()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keyboard shortcuts")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Live from \(abbreviatedSourcePath)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 20)
            HStack(spacing: 6) {
                ForEach(ShortcutSearchMode.allCases) { mode in
                    SearchModeButton(mode: mode, selected: model.searchMode == mode) {
                        model.selectSearchMode(mode)
                    }
                }
                Divider().frame(height: 22).padding(.horizontal, 3)
                if model.searchMode == .text {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search actions…", text: $model.query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                } else if let captured = model.capturedKey {
                    KeycapGroup(parts: captured.parts, compact: true)
                    Text("matching key")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else {
                    Image(systemName: "keyboard.badge.ellipsis").foregroundStyle(Color.accentColor)
                    Text("Press a shortcut…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                if !model.query.isEmpty || model.capturedKey != nil {
                    Button { model.clearSearch() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Keycap(text: model.searchMode == .keys ? "⌥P" : "⌥F", compact: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(width: 440)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 5) {
            CategoryButton(
                title: "All shortcuts",
                symbol: "square.grid.3x3",
                count: model.count(for: nil),
                selected: model.selectedCategory == nil
            ) { model.selectCategory(nil) }
            ForEach(ShortcutCategory.allCases) { category in
                CategoryButton(
                    title: category.rawValue,
                    symbol: category.symbol,
                    count: model.count(for: category),
                    selected: model.selectedCategory == category
                ) { model.selectCategory(category) }
            }
            Spacer()
            Text("⌥← / ⌥→ change category")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
        }
        .padding(12)
        .frame(width: 188)
    }

    private var results: some View {
        VStack(spacing: 0) {
            HStack {
                Text(resultTitle)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(model.filteredGroups.count)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if model.filteredGroups.isEmpty {
                emptyState
            } else {
                shortcutList
            }
        }
        .frame(minWidth: 390, maxWidth: .infinity)
    }

    private var shortcutList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(Array(model.filteredGroups.enumerated()), id: \.element.id) { index, group in
                        ShortcutRow(group: group, selected: index == model.selectedIndex) {
                            model.select(group)
                        }
                        .id(group.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .onChange(of: model.selectedIndex) { _, newIndex in
                guard newIndex >= 0, newIndex < model.filteredGroups.count else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(model.filteredGroups[newIndex].id, anchor: .center)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: model.loadError == nil
                ? (model.searchMode == .keys ? "keyboard.badge.ellipsis" : "text.magnifyingglass")
                : "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(model.loadError == nil ? "No matching shortcuts" : "Shortcut map unavailable")
                .font(.system(size: 14, weight: .semibold))
            Text(model.loadError ?? (model.searchMode == .keys
                ? "Press another key, or use Option+C to clear."
                : "Try a different action, key, or category."))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var details: some View {
        Group {
            if let group = model.selectedGroup {
                ShortcutDetail(group: group)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "keyboard.badge.ellipsis")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Select a shortcut")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 280)
    }

    private var footer: some View {
        HStack(spacing: 18) {
            FooterHint(keys: "⌥↑/↓", text: "browse")
            FooterHint(keys: "⌥←/→", text: "categories")
            if model.searchMode == .keys {
                FooterHint(keys: "key", text: "press any key to filter")
                FooterHint(keys: "⌥F", text: "text search")
            } else {
                FooterHint(keys: "type", text: "search actions")
                FooterHint(keys: "⌥P", text: "keypress search")
            }
            Spacer()
            FooterHint(keys: "⌥C", text: "clear")
            FooterHint(keys: "esc", text: "close")
            FooterHint(keys: "⌥/", text: "toggle")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(0.025))
        .overlay(alignment: .top) { Divider().opacity(0.5) }
    }

    private var resultTitle: String {
        if model.searchMode == .keys, model.capturedKey != nil { return "Key matches" }
        if model.searchMode == .text, !model.query.isEmpty { return "Search results" }
        return model.selectedCategory?.rawValue ?? "All shortcuts"
    }

    private var abbreviatedSourcePath: String {
        let home = NSHomeDirectory()
        return model.sourcePath.hasPrefix(home) ? "~" + model.sourcePath.dropFirst(home.count) : model.sourcePath
    }
}

struct SearchModeButton: View {
    let mode: ShortcutSearchMode
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: mode.symbol)
                Text(mode.rawValue)
            }
            .font(.system(size: 10, weight: selected ? .semibold : .medium))
            .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.accentColor.opacity(0.14) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CategoryButton: View {
    let title: String
    let symbol: String
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .frame(width: 17)
                Text(title)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(selected ? Color.accentColor.opacity(0.14) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ShortcutRow: View {
    let group: ShortcutGroup
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.system(size: 13, weight: selected ? .semibold : .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(group.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                KeySequenceGroup(sequences: group.keySequences, compact: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1.25)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ShortcutDetail: View {
    let group: ShortcutGroup

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Label(group.category.rawValue, systemImage: group.category.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))

                KeySequenceGroup(sequences: group.keySequences, compact: false)

                VStack(alignment: .leading, spacing: 6) {
                    Text(group.title)
                        .font(.system(size: 17, weight: .semibold))
                    Text(group.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().opacity(0.6)

                VStack(alignment: .leading, spacing: 7) {
                    Text("IMPLEMENTATION")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(.tertiary)
                    Text(group.implementationText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.04)))

                HStack(spacing: 5) {
                    Image(systemName: "doc.text")
                    Text(group.sourceLocation)
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }
}

struct KeySequenceGroup: View {
    let sequences: [[String]]
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            ForEach(Array(sequences.enumerated()), id: \.offset) { index, sequence in
                if index > 0 {
                    Text("/")
                        .font(.system(size: compact ? 9 : 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                KeycapGroup(parts: sequence, compact: compact)
            }
        }
    }
}

struct KeycapGroup: View {
    let parts: [String]
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 3 : 5) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                Keycap(text: part, compact: compact)
            }
        }
    }
}

struct Keycap: View {
    let text: String
    var compact = false

    var body: some View {
        Text(text)
            .font(.system(size: compact ? 10 : 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 3 : 5)
            .background(
                RoundedRectangle(cornerRadius: compact ? 5 : 6)
                    .fill(Color.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 5 : 6)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
    }
}

struct FooterHint: View {
    let keys: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Text(keys).font(.system(size: 10, weight: .semibold, design: .rounded))
            Text(text).font(.system(size: 10))
        }
        .foregroundStyle(.secondary)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 15
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private func abbreviate(path: String) -> String {
    let home = NSHomeDirectory()
    return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
}

private func runSelfTest() -> Int32 {
    let fixture = #"""
    # ============================================================
    # Window Management
    # ============================================================
    # -- Cycle windows --
    shift + alt - tab : yabai -m window --focus stack.prev
    alt + cmd - 0x21 : win=1; \
      yabai -m window --display prev
    # ============================================================
    # Space management
    # ============================================================
    # -- Projects: space shortcuts --
    alt + shift - 0x18 ; space_slot_mode
    ctrl + alt + cmd + shift - 0x33 : ~/.config/yabai/projects detach
    ctrl + alt + cmd - h [
      "Ghostty" ~
      * : yabai -m window --resize left:-100:0
    ]
    # ============================================================
    # App Focus
    # ============================================================
    # dotfiles-owner: terminal-window-types
    # -- Ghostty management (right Command) --
    rcmd - d [
      "Ghostty" : skhd -k "f16" # Duplicate current tmux window
      * ~
    ]
    # ============================================================
    # Screenshots
    # ============================================================
    fn - 2 : skhd -k "ctrl + cmd + shift - 3"
    """#
    let bindings = SKHDParser.parse(fixture)
    var failures: [String] = []
    func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { failures.append(message) }
    }

    expect(bindings.count == 7, "expected all seven fixture shortcuts")
    expect(bindings.contains { $0.displayKey == "⌥ ⇧ ⇥" }, "formats Shift+Option+Tab")
    expect(bindings.contains { $0.displayKey == "⌥ ⌘ [" && $0.command.contains("--display prev") }, "joins multiline commands")
    expect(bindings.contains { $0.title == "Assign a project-space shortcut" }, "parses modal activators")
    expect(bindings.contains { $0.displayKey == "Hyper ⇧ ⌫" && $0.category == .projects }, "formats Hyper and keycodes")
    expect(bindings.contains { $0.displayKey == "fn 2" && $0.category == .capture }, "parses Fn shortcuts")
    expect(bindings.contains {
        $0.displayKey == "Hyper H" && $0.command == "yabai -m window --resize left:-100:0"
    }, "retains the wildcard action from an application process map")
    expect(bindings.contains {
        $0.displayKey == "Hyper H" && $0.detail.contains("global action runs outside Ghostty")
    }, "describes application passthrough without exposing it as shell")
    expect(bindings.contains {
        $0.displayKey == "R⌘ D" && $0.command == #"skhd -k "f16""#
    }, "formats a right-Command application binding")
    expect(bindings.contains {
        $0.displayKey == "R⌘ D" && $0.owner == "terminal-window-types"
    }, "parses rendered module ownership markers")
    expect(bindings.first?.owner == "root", "defaults unmarked root bindings to root ownership")
    expect(bindings.contains {
        $0.title == "Duplicate current tmux window" && $0.category == .apps
    }, "retains the app-specific action and its inline description")
    expect(bindings.contains {
        $0.displayKey == "R⌘ D" && $0.detail.contains("Runs only in Ghostty")
    }, "describes wildcard passthrough for an app-specific action")
    expect(bindings.contains {
        $0.matches(query: "right command duplicate")
    }, "search expands the sided Command modifier")
    expect(KeyFormatter.display(for: "ralt - x") == "R⌥ X", "formats a reserved sided Option chord")
    expect(bindings.first?.matches(query: "option previous") == true, "search matches modifier aliases and actions")
    let groups = ShortcutGrouper.groups(from: bindings)
    expect(groups.contains { $0.matches(capturedKey: CapturedKey(parts: ["Hyper", "⇧", "⌫"])) }, "key-chord search matches grouped shortcuts")
    expect(groups.contains { $0.matches(capturedKey: CapturedKey(parts: ["2"])) }, "bare-key search matches shortcuts regardless of modifiers")
    expect(groups.contains {
        $0.matches(capturedKey: CapturedKey(parts: ["⌘", "D"])) &&
            $0.bindings.contains { $0.rawKey == "rcmd - d" }
    }, "generic AppKit Command capture finds sided Command bindings")

    if failures.isEmpty {
        print("whichkey self-test: 19 passed")
        return 0
    }
    failures.forEach { fputs("whichkey self-test: \($0)\n", stderr) }
    return 1
}

@main
enum WhichKeyMain {
    @MainActor
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.first == "--self-test" {
            exit(runSelfTest())
        }
        if arguments.first == "--dump-json" {
            let path = arguments.count > 1
                ? arguments[1]
                : (ProcessInfo.processInfo.environment["WHICHKEY_SKHDRC"] ?? NSHomeDirectory() + "/.skhdrc")
            do {
                let bindings = try SKHDParser.parseFile(at: path)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                FileHandle.standardOutput.write(try encoder.encode(bindings))
                FileHandle.standardOutput.write(Data("\n".utf8))
                exit(0)
            } catch {
                fputs("whichkey: could not parse \(abbreviate(path: path)): \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }

        let controller = ShortcutGuideController()
        exit(controller.run())
    }
}
