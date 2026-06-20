// man-me: name=projectdeck
// man-me: category=Project Spaces
// man-me: usage=Hyper+p or projects pick
// man-me: description=Floating SwiftUI project picker built during install.
// man-me: tags=project projects projectdeck picker hyper hotkeys skhd yabai swiftui
import AppKit
import Combine
import SwiftUI

struct MenuPayload: Decodable {
    let header: String
    let items: [MenuItem]
}

struct MenuItem: Decodable, Identifiable {
    let line: String
    let label: String
    let section: String
    let active: Bool

    var id: String { line }
}

@MainActor
final class ProjectDeckController: NSObject, NSWindowDelegate {
    private let projectsBin: String
    private var panel: NSPanel?
    private var hostingView: NSHostingView<DeckView>?
    private var deckViewModel: DeckViewModel?
    private var keyMonitor: Any?
    private var didFinish = false

    init(projectsBin: String) {
        self.projectsBin = projectsBin
    }

    func run() -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        if ProcessInfo.processInfo.environment["PROJECTS_PICK_MENU"] == "create" {
            presentCreateOnly()
            app.run()
            return 0
        }

        guard let payload = loadMenu() else {
            fputs("projectdeck: failed to load menu\n", stderr)
            return 1
        }

        present(payload: payload)
        app.run()
        return 0
    }

    private func presentCreateOnly() {
        let payload = MenuPayload(header: "Create a project on the next Hyper slot", items: [])
        present(payload: payload, startInCreateForm: true)
    }

    private func present(payload: MenuPayload, startInCreateForm: Bool = false) {
        let model = DeckViewModel(payload: payload, showCreateForm: startInCreateForm) { [weak self] line in
            self?.handleSelection(line)
        } onCancel: { [weak self] in
            self?.close(returnCode: 0)
        } onCreate: { [weak self] name in
            _ = self?.runProjects(["new", name])
            self?.close(returnCode: 0)
        }

        deckViewModel = model

        let root = DeckView(model: model)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: panelHeight(for: model))

        let panel = NSPanel(
            contentRect: hosting.frame,
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
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
        self.hostingView = hosting
        installKeyMonitor(for: model)

        NSApp.activate(ignoringOtherApps: true)
    }

    private func panelHeight(for model: DeckViewModel) -> CGFloat {
        if model.showCreateForm {
            return 220
        }
        let rows = max(model.filteredItems.count, 1)
        return min(560, max(240, 120 + CGFloat(rows) * 44))
    }

    private func installKeyMonitor(for model: DeckViewModel) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isKeyWindow == true else { return event }

            switch event.keyCode {
            case 126: // up
                if model.showCreateForm { return event }
                model.moveSelection(-1)
                self.resizeToFit()
                return nil
            case 125: // down
                if model.showCreateForm { return event }
                model.moveSelection(1)
                self.resizeToFit()
                return nil
            case 36: // return
                if model.showCreateForm {
                    model.createProject()
                } else {
                    model.selectHighlighted()
                }
                return nil
            case 53: // escape
                if model.showCreateForm && !model.items.isEmpty {
                    model.showCreateForm = false
                    model.resetSelection()
                    self.resizeToFit()
                } else {
                    self.close(returnCode: 0)
                }
                return nil
            default:
                break
            }

            if model.showCreateForm { return event }

            if let chars = event.charactersIgnoringModifiers?.lowercased(), chars.count == 1 {
                if let digit = Int(chars), digit >= 1 && digit <= 9 {
                    if model.selectIndex(digit - 1) {
                        return nil
                    }
                }
            }

            return event
        }
    }

    private func loadMenu() -> MenuPayload? {
        let menu = ProcessInfo.processInfo.environment["PROJECTS_PICK_MENU"] ?? "main"
        var args = ["menu-json", "--menu", menu]
        if menu.hasPrefix("spaces:") {
            let projectId = String(menu.dropFirst("spaces:".count))
            args += ["--project", projectId]
        }
        guard let data = runProjectsData(args) else { return nil }
        return try? JSONDecoder().decode(MenuPayload.self, from: data)
    }

    private func handleSelection(_ line: String) {
        if line.hasPrefix("ACTION:new:") {
            deckViewModel?.showCreateForm = true
            deckViewModel?.query = ""
            resizeToFit()
            return
        }

        if line.hasPrefix("ACTION:adopt:") || line.hasPrefix("ACTION:spaces:") {
            let submenu = line
            panel?.orderOut(nil)
            _ = runProjects(["pick-sub", submenu])
            close(returnCode: 0)
            return
        }

        if line.hasPrefix("DELETE:") || line.hasPrefix("DETACH:") {
            guard confirmDestructive(line: line) else { return }
            _ = runProjects(["pick-exec", line], skipConfirm: true)
            close(returnCode: 0)
            return
        }

        _ = runProjects(["pick-exec", line])
        close(returnCode: 0)
    }

    private func confirmDestructive(line: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")

        if line.hasPrefix("DELETE:") {
            let name = pickLineLabel(line)
            alert.messageText = "Delete project?"
            alert.informativeText = "Delete \"\(name)\" and remove it from all Hyper slots. Space labels will be cleared."
            alert.addButton(withTitle: "Delete")
        } else if line.hasPrefix("DETACH:") {
            let name = pickLineLabel(line)
            alert.messageText = "Remove space?"
            alert.informativeText = name
            alert.addButton(withTitle: "Remove")
        } else {
            return true
        }

        return alert.runModal() == .alertSecondButtonReturn
    }

    private func pickLineLabel(_ line: String) -> String {
        let parts = line.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 4 else { return line }
        return parts.dropFirst(3).joined(separator: ":")
    }

    private func runProjects(_ args: [String], skipConfirm: Bool = false) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: projectsBin)
        task.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["PROJECTS_NOTIFY"] = "1"
        env["PROJECTS_NOTIFY_SUCCESS"] = "1"
        if skipConfirm {
            env["PROJECTS_CONFIRM"] = "0"
        }
        task.environment = env
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus
        } catch {
            return 1
        }
    }

    private func runProjectsData(_ args: [String]) -> Data? {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: projectsBin)
        task.arguments = args
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            return pipe.fileHandleForReading.readDataToEndOfFile()
        } catch {
            return nil
        }
    }

    private func resizeToFit() {
        guard let panel, let model = deckViewModel else { return }
        var frame = panel.frame
        frame.size.height = panelHeight(for: model)
        panel.setFrame(frame, display: true)
    }

    private func close(returnCode: Int32) {
        guard !didFinish else { return }
        didFinish = true
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        panel?.close()
        NSApp.terminate(nil)
    }

    func windowWillClose(_ notification: Notification) {
        close(returnCode: 0)
    }
}

final class DeckViewModel: ObservableObject {
    @Published var query = ""
    @Published var showCreateForm = false
    @Published var selectedIndex = 0
    let header: String
    let items: [MenuItem]
    private let onSelect: (String) -> Void
    private let onCancel: () -> Void
    private let onCreate: (String) -> Void

    init(
        payload: MenuPayload,
        showCreateForm: Bool = false,
        onSelect: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        onCreate: @escaping (String) -> Void
    ) {
        self.header = payload.header
        self.items = payload.items
        self.showCreateForm = showCreateForm
        self.onSelect = onSelect
        self.onCancel = onCancel
        self.onCreate = onCreate
        resetSelection()
    }

    var filteredItems: [MenuItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { $0.label.lowercased().contains(q) }
    }

    func resetSelection() {
        if items.isEmpty {
            selectedIndex = 0
            return
        }
        if let activeIndex = items.firstIndex(where: { $0.active }) {
            selectedIndex = activeIndex
        } else {
            selectedIndex = 0
        }
        clampSelection()
    }

    func moveSelection(_ delta: Int) {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + filteredItems.count) % filteredItems.count
    }

    @discardableResult
    func selectIndex(_ index: Int) -> Bool {
        guard index >= 0 && index < filteredItems.count else { return false }
        selectedIndex = index
        selectHighlighted()
        return true
    }

    func selectHighlighted() {
        guard !filteredItems.isEmpty else { return }
        clampSelection()
        select(filteredItems[selectedIndex])
    }

    func select(_ item: MenuItem) {
        onSelect(item.line)
    }

    func cancel() {
        onCancel()
    }

    func createProject() {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        onCreate(name)
    }

    private func clampSelection() {
        guard !filteredItems.isEmpty else {
            selectedIndex = 0
            return
        }
        selectedIndex = min(max(0, selectedIndex), filteredItems.count - 1)
    }
}

struct DeckView: View {
    @ObservedObject var model: DeckViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            VisualEffectBackground()
            VStack(alignment: .leading, spacing: 12) {
                header
                if model.showCreateForm {
                    createForm
                } else {
                    searchField
                    itemList
                    footer
                }
            }
            .padding(16)
        }
        .frame(minWidth: 480)
        .onAppear {
            searchFocused = true
            model.resetSelection()
        }
        .onChange(of: model.query) { _, _ in
            model.selectedIndex = 0
        }
        .onExitCommand { model.cancel() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Projects")
                .font(.system(size: 15, weight: .semibold))
            Text(model.header)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var searchField: some View {
        TextField("Search projects…", text: $model.query)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
            .focused($searchFocused)
            .onSubmit { model.selectHighlighted() }
    }

    private var createForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New project")
                .font(.system(size: 13, weight: .medium))
            TextField("Project name", text: $model.query)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
                .focused($searchFocused)
                .onSubmit { model.createProject() }
            HStack {
                Button("Cancel") {
                    model.showCreateForm = false
                    model.resetSelection()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create & adopt") { model.createProject() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            Text("↵ create · esc back")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        let hasDanger = model.items.contains { $0.section == "danger" }
        let text = hasDanger
            ? "↑↓ navigate · ↵ open · ✕ rows confirm · esc dismiss"
            : "↑↓ navigate · ↵ open · 1-9 quick pick · esc dismiss"
        return Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(model.filteredItems.enumerated()), id: \.element.id) { index, item in
                        itemRow(item: item, index: index, isSelected: index == model.selectedIndex)
                            .id(item.id)
                    }
                }
            }
            .frame(maxHeight: 360)
            .onChange(of: model.selectedIndex) { _, newIndex in
                guard newIndex >= 0 && newIndex < model.filteredItems.count else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(model.filteredItems[newIndex].id, anchor: .center)
                }
            }
        }
    }

    private func itemRow(item: MenuItem, index: Int, isSelected: Bool) -> some View {
        Button {
            model.selectedIndex = index
            model.select(item)
        } label: {
            HStack(spacing: 10) {
                Text(index < 9 ? "\(index + 1)" : " ")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 14, alignment: .trailing)
                Circle()
                    .fill(item.active ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 8, height: 8)
                Text(item.label)
                    .font(.system(size: 13, weight: isSelected || item.active ? .semibold : .regular))
                    .foregroundStyle(item.section == "danger" ? Color.red : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(rowBackground(isSelected: isSelected, isActive: item.active))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func rowBackground(isSelected: Bool, isActive: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.16)
        }
        if isActive {
            return Color.accentColor.opacity(0.08)
        }
        return Color.primary.opacity(0.04)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 14
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

@main
enum ProjectDeckMain {
    static func main() {
        let bin = ProcessInfo.processInfo.environment["PROJECTS_BIN"]
            ?? ("\(NSHomeDirectory())/.config/yabai/projects")
        let controller = ProjectDeckController(projectsBin: bin)
        exit(controller.run())
    }
}
