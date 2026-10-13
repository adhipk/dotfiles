import SwiftUI
import AppKit
import ServiceManagement
import ExtensionKit

struct UtilitiesView: View {
    @ObservedObject var model: UtilityModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Utilities").font(.title2.bold())
                    Spacer()
                    Button { importPackage() } label: { Image(systemName: "plus") }.help("Install utility package")
                }
                List(selection: $model.selection) {
                    ForEach(model.utilities) { utility in
                        VStack(alignment: .leading) {
                            Text(utility.manifest.name)
                            Text(utility.enabled ? "Enabled" : "Disabled").font(.caption).foregroundStyle(.secondary)
                        }.tag(utility.id)
                    }
                }
                Menu("Add from included catalog") {
                    ForEach(catalog(), id: \.path) { path in
                        Button(path.deletingPathExtension().lastPathComponent) { confirmInstall(path) }
                    }
                }
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { value in
                        do {
                            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch { model.message = error.localizedDescription; launchAtLogin = SMAppService.mainApp.status == .enabled }
                    }
                Text("Services are managed by macOS and can continue after this app closes.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Refresh") { model.reload() }
            }.padding().frame(minWidth: 230, idealWidth: 260, maxWidth: 320)
            VStack(alignment: .leading, spacing: 12) {
                if let utility = model.selected {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(utility.manifest.name).font(.largeTitle.bold())
                                    Text(utility.manifest.summary).foregroundStyle(.secondary)
                                    Text("Version \(utility.activeVersion)").font(.caption)
                                }
                                Spacer()
                                Toggle("Enabled", isOn: Binding(get: { utility.enabled }, set: { model.enable(utility, $0) }))
                                    .toggleStyle(.switch).fixedSize()
                            }
                            HStack {
                                Button("Check dependencies") { model.doctor(utility) }
                                Button("Restore previous version") { model.rollback(utility) }.disabled(utility.previousVersion == nil)
                                Button("Remove…", role: .destructive) {
                                    if confirm("Remove \(utility.manifest.name)?", "Its services and shortcuts will be removed. Saved utility data will be kept.") { model.remove(utility) }
                                }
                            }
                            DependencySetupView(utility: utility, store: model.store)
                            if !(utility.manifest.settings ?? []).isEmpty {
                                Text("Settings").font(.headline)
                                ForEach(utility.manifest.settings ?? []) { setting in
                                    SettingRow(setting: setting, value: utility.settings[setting.key] ?? setting.defaultValue) { value in
                                        model.configure(utility, key: setting.key, value: value)
                                    }.id("\(utility.id)/\(setting.key)/\(utility.settings[setting.key] ?? "")")
                                }
                                Text("Saving settings restarts this utility’s enabled services.").font(.caption).foregroundStyle(.secondary)
                            }
                            if !utility.manifest.commands.isEmpty {
                                Text("Actions").font(.headline)
                                ForEach(utility.manifest.commands) { command in
                                    HStack {
                                        Text(command.title)
                                        Spacer()
                                        if command.input != true && command.confirmation == nil {
                                            ShortcutRecorder(binding: utility.shortcuts[command.id]) { binding in
                                                model.shortcut(utility, command: command.id, binding: binding)
                                            }
                                        }
                                        Button("Run") { model.run(utility, action: command) }.disabled(!utility.enabled)
                                    }
                                }
                                if utility.manifest.commands.contains(where: { $0.input == true }) {
                                    Text("Input").font(.subheadline)
                                    TextEditor(text: $model.input).font(.system(.body, design: .monospaced)).frame(height: 100).border(.quaternary)
                                }
                            }
                            if !(utility.manifest.services ?? []).isEmpty {
                                Text("Services").font(.headline)
                                ForEach(utility.manifest.services ?? []) { service in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(service.title)
                                            Text(model.serviceStates["\(utility.id)/\(service.id)"] ?? (utility.runningServices.contains(service.id) ? "Enabled at login — check status" : "Not enabled"))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button("Start / Restart") { model.service(utility, service: service, start: true) }.disabled(!utility.enabled)
                                        Button("Stop") { model.service(utility, service: service, start: false) }
                                        Button("Status & Logs") { model.inspect(utility, service: service) }
                                    }
                                }
                            }
                        }.padding()
                    }.disabled(model.busy)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Connect your utilities").font(.largeTitle.bold())
                        Text("Choose an included utility or install a package. Markdown Clipboard works with its included converter. Desktop and terminal integrations use the consumer desktop profile, with required tools shown before you enable them.")
                        Button("Install a utility…") { importPackage() }
                    }.padding(30)
                    Spacer()
                }
                Divider()
                HStack {
                    if model.busy { ProgressView().controlSize(.small); Button("Cancel action") { model.cancel() } }
                    Text(model.message.isEmpty ? "Ready" : model.message).textSelection(.enabled)
                    Spacer()
                }.padding(.horizontal)
                ScrollView {
                    Text(model.output.isEmpty ? "Action results and service logs appear here." : model.output)
                        .font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding()
                }.frame(height: 150)
            }.frame(minWidth: 650)
        }
    }
    private func catalog() -> [URL] {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("Utilities") else { return [] }
        return ((try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "dotutility" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    private func importPackage() {
        let panel = NSOpenPanel(); panel.title = "Install a utility package"
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let path = panel.url { confirmInstall(path) }
    }
    private func confirmInstall(_ path: URL) {
        do {
            let manifest = try UtilityManifest.load(from: path)
            if confirm("Install \(manifest.name) \(manifest.version)?", "\(manifest.summary)\n\n\(DependencySetup.guidance(for: manifest.id))\n\nUtilities run as your user. Install packages from authors you trust. New utilities start disabled.") { model.install(path) }
        } catch { model.message = error.localizedDescription }
    }
    private func confirm(_ title: String, _ detail: String) -> Bool {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = detail
        alert.addButton(withTitle: "Continue"); alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

private struct DependencySetupView: View {
    let utility: InstalledUtility
    let store: UtilityStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Setup & permissions").font(.headline)
            Text(DependencySetup.guidance(for: utility.id)).font(.callout)
            ForEach(DependencySetup.dependencies(utility, store: store)) { dependency in
                HStack(alignment: .top) {
                    Image(systemName: dependency.available ? "checkmark.circle" : "exclamationmark.circle")
                        .foregroundStyle(dependency.available ? Color.green : Color.orange)
                    Text(dependency.name).font(.system(.callout, design: .monospaced))
                    Text(dependency.path ?? "Required — install the desktop profile").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            if utility.id != "example.hello" && utility.id != "dotfiles.markdown-clipboard" {
                Text("From the downloaded source, review ./bootstrap --consumer. Install with ./bootstrap --consumer --apply. This configures your shell, shortcuts and desktop; agent and work applications are optional.")
                    .font(.caption).textSelection(.enabled)
            }
        }
    }
}

private struct SettingRow: View {
    let setting: UtilitySetting
    @State var value: String
    let save: (String) -> Void
    var body: some View {
        HStack {
            Text(setting.title).frame(width: 180, alignment: .leading)
            if setting.kind == "boolean" {
                Toggle("", isOn: Binding(get: { value == "true" }, set: { value = $0 ? "true" : "false" })).labelsHidden()
            } else if setting.kind == "choice" {
                Picker("", selection: $value) { ForEach(setting.choices ?? [], id: \.self) { Text($0).tag($0) } }.labelsHidden()
            } else { TextField(setting.title, text: $value).textFieldStyle(.roundedBorder) }
            Button("Save") { save(value) }
        }
    }
}

private struct ShortcutRecorder: View {
    let binding: KeyBinding?
    let save: (KeyBinding?) -> Void
    @State private var monitor: Any?
    @State private var recording = false
    private var label: String {
        guard let binding else { return "Set shortcut" }
        let keyNames: [UInt32: String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",37:"L",38:"J",40:"K",43:",",44:"/",45:"N",46:"M",47:".",49:"Space",50:"`",123:"←",124:"→",125:"↓",126:"↑"]
        return (binding.modifiers & 4096 != 0 ? "⌃" : "") + (binding.modifiers & 2048 != 0 ? "⌥" : "") + (binding.modifiers & 512 != 0 ? "⇧" : "") + (binding.modifiers & 256 != 0 ? "⌘" : "") + (keyNames[binding.keyCode] ?? "Key \(binding.keyCode)")
    }
    var body: some View {
        HStack {
            Button(recording ? "Press shortcut (Esc cancels)" : label) {
                finish(); recording = true
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.keyCode == 53 { finish(); return nil }
                    let flags = event.modifierFlags
                    var modifiers: UInt32 = 0
                    if flags.contains(.command) { modifiers |= 256 }
                    if flags.contains(.shift) { modifiers |= 512 }
                    if flags.contains(.option) { modifiers |= 2048 }
                    if flags.contains(.control) { modifiers |= 4096 }
                    guard modifiers & (256 | 2048 | 4096) != 0 else { return nil }
                    save(KeyBinding(keyCode: UInt32(event.keyCode), modifiers: modifiers)); finish(); return nil
                }
            }
            if binding != nil { Button { save(nil) } label: { Image(systemName: "xmark.circle") }.help("Clear shortcut") }
        }.onDisappear { finish() }
    }
    private func finish() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil; recording = false }
}
