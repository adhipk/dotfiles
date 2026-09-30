import AppKit

func looksLikeMarkdown(_ text: String) -> Bool {
    let patterns = [#"(?m)^ {0,3}(#{1,6}\s+|[-*+]\s+|\d+[.)]\s+|>\s+|`{3,}|~{3,})"#,
                    #"\*\*\S[^\n]*?\*\*|__\S[^\n]*?__|`[^`\n]+`|\[[^\]\n]+\]\([^\s)]+\)"#,
                    #"(?m)^\s*\|?\s*:?-{3,}:?\s*\|"#]
    return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
}

func render(_ text: String, pandoc: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: pandoc)
    process.arguments = ["--sandbox", "--from=markdown-raw_html-raw_tex-native_divs-native_spans", "--to=html5", "--wrap=none"]
    let input = Pipe(), output = Pipe()
    process.standardInput = input
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return nil }
    // Concurrent input/output prevents pipe-buffer deadlock for larger copies.
    DispatchQueue.global().async {
        try? input.fileHandleForWriting.write(contentsOf: Data(text.utf8))
        try? input.fileHandleForWriting.close()
    }
    let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: watchdog)
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    watchdog.cancel()
    guard process.terminationStatus == 0, !data.isEmpty else { return nil }
    return String(data: data, encoding: .utf8)
}

// Chromium/Electron packs web MIME metadata into a length-prefixed Pickle map.
// https://chromium.googlesource.com/chromium/src/+/main/ui/base/clipboard/custom_data_helper.cc
func chromiumMetadata(_ data: Data) -> [String: String]? {
    guard data.count >= 8, data.count <= 262144 else { return nil }
    var offset = 0
    func integer() -> Int? {
        guard offset + 4 <= data.count else { return nil }
        let value = (0..<4).reduce(UInt32(0)) { $0 | UInt32(data[offset + $1]) << ($1 * 8) }
        offset += 4
        return Int(value)
    }
    func string() -> String? {
        guard let length = integer(), length <= (data.count - offset) / 2 else { return nil }
        let end = offset + length * 2
        let value = String(data: data.subdata(in: offset..<end), encoding: .utf16LittleEndian)
        offset = (end + 3) & ~3
        guard offset <= data.count else { return nil }
        return value
    }
    guard integer() == data.count - 4, let count = integer(), count <= 128 else { return nil }
    var result: [String: String] = [:]
    for _ in 0..<count {
        guard let key = string(), let value = string(), result[key] == nil else { return nil }
        result[key] = value
    }
    return offset == data.count ? result : nil
}

func isMarkdownEditorCopy(_ item: NSPasteboardItem) -> Bool {
    let packed = item.data(forType: .init("org.chromium.web-custom-data"))
        .flatMap(chromiumMetadata)?["vscode-editor-data"]
    guard let value = packed, let data = value.data(using: .utf8),
          let metadata = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    else { return false }
    return metadata["mode"] as? String == "markdown"
}

@discardableResult
func enrich(_ board: NSPasteboard, pandoc: String,
            converter: ((String) -> String?)? = nil) -> Bool {
    let count = board.changeCount
    guard let items = board.pasteboardItems, items.count == 1 else { return false }
    let original = items[0]
    // Markdown-mode editor copies carry highlighted source HTML, not rendered
    // Markdown. Permit that specific rich copy while retaining its editor metadata.
    // Unknown, sensitive, file and image types still exclude the entire item.
    var allowed: Set<String> = ["public.utf8-plain-text", "public.utf16-plain-text",
                               "public.plain-text", "NSStringPboardType",
                               "com.apple.traditional-mac-plain-text",
                               "public.text-encoding"]
    if isMarkdownEditorCopy(original) {
        allowed.formUnion(["public.html", "org.chromium.web-custom-data",
                           "org.chromium.source-url", "org.chromium.internal.source-rfh-token"])
    }
    guard original.types.allSatisfy({ allowed.contains($0.rawValue) }),
          let text = original.string(forType: .string),
          text.utf8.count <= 262144, looksLikeMarkdown(text) else { return false }
    let item = NSPasteboardItem()
    for type in original.types {
        if let data = original.data(forType: type) { item.setData(data, forType: type) }
    }
    guard let html = (converter ?? { render($0, pandoc: pandoc) })(text),
          board.changeCount == count, html != original.string(forType: .html) else { return false }
    item.setString(text, forType: .string)
    item.setString(html, forType: .html)
    board.clearContents()
    return board.writeObjects([item])
}

let args = CommandLine.arguments
let pandoc = args.last ?? "/opt/homebrew/bin/pandoc"
if args.contains("--self-test") {
    let board = NSPasteboard(name: .init("markdown-clipboard-test-" + UUID().uuidString))
    defer { board.releaseGlobally() }
    func put(_ text: String, extra: NSPasteboard.PasteboardType? = nil) {
        board.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        if let extra = extra { item.setString("existing", forType: extra) }
        assert(board.writeObjects([item]))
    }
    for text in ["# Heading", "**bold**", "- list", "```swift\nlet a = 1\n```", "[link](https://example.com)", "| A | B |\n| --- | --- |\n| 1 | 2 |"] {
        put(text)
        assert(enrich(board, pandoc: pandoc))
        assert(board.string(forType: .string) == text)
        assert(board.string(forType: .html) != nil)
        let count = board.changeCount
        assert(!enrich(board, pandoc: pandoc) && count == board.changeCount)
    }
    for extra in [NSPasteboard.PasteboardType.html, .rtf, .fileURL, .png, .init("org.nspasteboard.ConcealedType")] {
        put("**secret**", extra: extra)
        let count = board.changeCount
        assert(!enrich(board, pandoc: pandoc) && count == board.changeCount)
    }
    let table = "| Harness | Passed | Failed | Total |\n| --- | ---: | ---: | ---: |\n| Evals | 66 | 25 | 91 |\n| Simulations | 27 | 16 | 43 |"
    let editorJSON = #"{"version":1,"isFromEmptySelection":false,"multicursorText":null,"mode":"markdown"}"#
    let highlighted = "<meta charset='utf-8'><div style=\"white-space: pre;\"><span>| Harness | Passed | Failed | Total |</span></div>"
    func pickle(_ pairs: [(String, String)]) -> Data {
        var payload = Data()
        func integer(_ value: Int) {
            var n = UInt32(value).littleEndian
            withUnsafeBytes(of: &n) { payload.append(contentsOf: $0) }
        }
        integer(pairs.count)
        for (key, value) in pairs {
            for text in [key, value] {
                integer(text.utf16.count)
                payload.append(text.data(using: .utf16LittleEndian)!)
                while payload.count % 4 != 0 { payload.append(0) }
            }
        }
        let body = payload
        payload = Data()
        integer(body.count)
        payload.append(body)
        return payload
    }
    let packed = pickle([("application/vnd.code.copymetadata", #"{"id":"test"}"#),
                         ("vscode-editor-data", editorJSON)])
    func putEditor(mode: String = "markdown", extra: NSPasteboard.PasteboardType? = nil) {
        board.clearContents()
        let item = NSPasteboardItem()
        item.setString(table, forType: .string)
        item.setString(highlighted, forType: .html)
        let metadata = mode == "markdown" ? packed : pickle([("vscode-editor-data", editorJSON.replacingOccurrences(of: "markdown", with: mode))])
        item.setData(metadata, forType: .init("org.chromium.web-custom-data"))
        item.setString("vscode-file://vscode-app", forType: .init("org.chromium.source-url"))
        item.setData(Data(repeating: 0, count: 24), forType: .init("org.chromium.internal.source-rfh-token"))
        if let extra = extra { item.setString("existing", forType: extra) }
        assert(board.writeObjects([item]))
    }
    do {
        putEditor()
        assert(enrich(board, pandoc: pandoc))
        let html = board.string(forType: .html)!
        assert(html.contains("<table>") && html.contains("<thead>") && html.contains("<tbody>"))
        assert(html.contains("Evals") && html.contains("Simulations"))
        assert(board.string(forType: .string) == table)
        assert(board.data(forType: .init("org.chromium.web-custom-data")) == packed)
        let count = board.changeCount
        assert(!enrich(board, pandoc: pandoc) && board.changeCount == count)
    }
    putEditor(mode: "plaintext")
    assert(!enrich(board, pandoc: pandoc))
    for type in [NSPasteboard.PasteboardType.png, .fileURL, .init("org.nspasteboard.ConcealedType"), .init("com.example.unknown-format")] {
        putEditor(extra: type)
        let count = board.changeCount
        assert(!enrich(board, pandoc: pandoc) && board.changeCount == count)
    }
    for length in 0..<packed.count { assert(chromiumMetadata(Data(packed.prefix(length))) == nil) }
    assert(chromiumMetadata(pickle([])) == [:])
    var malformed = packed
    malformed.replaceSubrange(4..<8, with: [255, 255, 255, 255])
    assert(chromiumMetadata(malformed) == nil)
    print("PASS: VS Code table HTML, Chromium metadata preservation, repeated-copy guard, other modes and malformed metadata")
    put("hello world")
    assert(!enrich(board, pandoc: pandoc))
    put("**bold**")
    assert(!enrich(board, pandoc: pandoc, converter: { _ in nil }))
    assert(board.string(forType: .string) == "**bold**")
    assert(!enrich(board, pandoc: pandoc, converter: { _ in put("newer copy"); return "<b>old</b>" }))
    assert(board.string(forType: .string) == "newer copy")
    put(String(repeating: "**large**", count: 40000))
    assert(!enrich(board, pandoc: pandoc))
    let html = render("**bold** <script>alert(1)</script>", pandoc: pandoc)!
    assert(html.contains("<strong>bold</strong>") && !html.contains("<script>"))
    print("PASS: Markdown conversion, original text, rich/sensitive copies, self-write, size limit, conversion failure and newer-copy protection")
} else if args.contains("--once") {
    print(enrich(.general, pandoc: pandoc) ? "Converted Markdown clipboard to HTML" : "Clipboard unchanged")
} else {
    let board = NSPasteboard.general
    var lastChange = board.changeCount // Do not modify the clipboard at startup.
    while true {
        autoreleasepool {
            let observed = board.changeCount
            if observed != lastChange {
                if enrich(board, pandoc: pandoc) { lastChange = board.changeCount }
                else { lastChange = observed }
            }
        }
        Thread.sleep(forTimeInterval: 0.2)
    }
}
