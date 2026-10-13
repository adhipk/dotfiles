import Foundation
import AppKit
import Carbon
import ExtensionKit

@MainActor final class UtilityModel: ObservableObject {
    @Published var utilities: [InstalledUtility] = []
    @Published var selection: String?
    @Published var message = ""
    @Published var output = ""
    @Published var input = ""
    @Published var busy = false
    @Published var serviceStates: [String: String] = [:]
    let store = UtilityStore()
    let services = UtilityServices()
    lazy var lifecycle = UtilityLifecycle(store: store, services: services)
    private var refreshTask: Task<Void, Never>?
    private var actionTask: Task<Void, Never>?
    private var hotkeys: [EventHotKeyRef] = []
    private var nextHotkeyID: UInt32 = 1
    private var actions: [UInt32: (String, String, KeyBinding)] = [:]
    private var eventHandler: EventHandlerRef?
    var selected: InstalledUtility? { utilities.first { $0.id == selection } }

    init() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var identifier = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            let model = Unmanaged<UtilityModel>.fromOpaque(userData).takeUnretainedValue()
            let number = identifier.id
            Task { @MainActor in model.invokeHotkey(number) }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        reload()
        perform { try await self.lifecycle.recover() }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self else { return }
                if !self.busy { self.reload() }
            }
        }
    }
    func reload() {
        do {
            utilities = try store.list()
            if !utilities.contains(where: { $0.id == selection }) { selection = utilities.first?.id }
            hotkeys.forEach { UnregisterEventHotKey($0) }; hotkeys = []; actions = [:]
            for utility in utilities where utility.enabled {
                for (command, shortcut) in utility.shortcuts.sorted(by: { $0.key < $1.key }) {
                    guard let action = utility.manifest.commands.first(where: { $0.id == command }), action.input != true, action.confirmation == nil else { continue }
                    guard nextHotkeyID < UInt32.max else { message = "Restart the app to refresh shortcut registrations."; continue }
                    let number = nextHotkeyID; nextHotkeyID += 1
                    var reference: EventHotKeyRef?
                    let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
                        EventHotKeyID(signature: 0x44465554, id: number), GetApplicationEventTarget(), 0, &reference)
                    if result == noErr, let reference { hotkeys.append(reference); actions[number] = (utility.id, command, shortcut) }
                    else { message = "Shortcut unavailable for \(action.title). Choose another combination." }
                }
            }
        } catch { message = error.localizedDescription }
    }
    func perform(_ body: @escaping () async throws -> Void) {
        guard !busy else { return }; busy = true; message = ""
        Task {
            defer { busy = false; reload() }
            do { try await body() } catch { message = error.localizedDescription }
        }
    }
    func install(_ path: URL) {
        perform {
            let updated = try await self.lifecycle.install(from: path)
            self.selection = updated.id
            self.message = "Installed \(updated.manifest.name) \(updated.activeVersion)"
        }
    }
    func enable(_ utility: InstalledUtility, _ enabled: Bool) {
        perform { try await self.lifecycle.enable(utility.id, enabled) }
    }
    func remove(_ utility: InstalledUtility) {
        perform {
            try await self.lifecycle.remove(utility.id)
            self.message = "Removed utility. Saved data was preserved."
        }
    }
    func rollback(_ utility: InstalledUtility) {
        perform { try await self.lifecycle.rollback(utility.id) }
    }
    func configure(_ utility: InstalledUtility, key: String, value: String) {
        perform { try await self.lifecycle.configure(utility.id, key: key, value: value) }
    }
    func shortcut(_ utility: InstalledUtility, command: String, binding: KeyBinding?) {
        perform { try await self.lifecycle.shortcut(utility.id, command: command, binding: binding) }
    }
    func invokeHotkey(_ number: UInt32) {
        guard let (id, command, binding) = actions[number],
              let utility = try? store.list().first(where: { $0.id == id }), utility.enabled,
              utility.shortcuts[command] == binding,
              let action = utility.manifest.commands.first(where: { $0.id == command }),
              action.input != true, action.confirmation == nil else { reload(); return }
        run(utility, action: action, hotkey: binding)
    }
    func run(_ selectedUtility: InstalledUtility, action selectedAction: UtilityAction, hotkey: KeyBinding? = nil) {
        guard let utility = try? store.list().first(where: { $0.id == selectedUtility.id }),
              let action = utility.manifest.commands.first(where: { $0.id == selectedAction.id }) else { reload(); return }
        guard utility == selectedUtility, action == selectedAction else {
            message = "Utility changed. Review the updated action before running it."; reload(); return
        }
        guard utility.enabled, !busy else { return }
        if let confirmation = action.confirmation {
            let alert = NSAlert(); alert.messageText = action.title; alert.informativeText = confirmation
            alert.addButton(withTitle: "Run"); alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        busy = true; message = "Running \(action.title)…"; output = ""
        actionTask = Task {
            defer { busy = false; actionTask = nil }
            do {
                let result = try await lifecycle.run(utility.id, command: action.id, input: input, confirmed: true, reviewed: utility, hotkey: hotkey)
                output = result.output + (result.error.isEmpty ? "" : "\n" + result.error)
                message = result.status == 0 ? "Completed \(action.title)" : "\(action.title) exited with status \(result.status)"
            } catch { message = error is CancellationError ? "Cancelled" : error.localizedDescription }
        }
    }
    func cancel() { actionTask?.cancel() }
    func service(_ utility: InstalledUtility, service: UtilityService, start: Bool) {
        perform {
            let context = ExecutionContext(utility: utility, store: self.store)
            try await self.lifecycle.service(utility.id, serviceID: service.id, start: start)
            self.serviceStates["\(utility.id)/\(service.id)"] = try await self.services.status(service, context: context)
        }
    }
    func inspect(_ utility: InstalledUtility, service: UtilityService) {
        perform {
            let (state, logs, health) = try await self.lifecycle.inspect(utility.id, serviceID: service.id)
            self.serviceStates["\(utility.id)/\(service.id)"] = state
            self.output = logs
            if let result = health {
                self.message = result.status == 0 ? "Health check passed" : "Health check failed: \(result.error)"
            }
        }
    }
    func doctor(_ utility: InstalledUtility) {
        perform {
            let context = ExecutionContext(utility: utility, store: self.store)
            _ = try UtilityManifest.load(from: self.store.package(utility))
            for invocation in utility.manifest.allInvocations { _ = try context.resolve(invocation) }
            self.message = "Package and required executables are available."
        }
    }
}
