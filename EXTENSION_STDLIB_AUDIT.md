# Executable extension standard library audit

Implementation status: the development host now implements executable manifests,
settings, shortcuts, launchd registration, bounded action execution, and basic
Swift author hooks. [EXTENSION_AUTHORING.md](EXTENSION_AUTHORING.md) describes the
actual supported contract. The broader hook inventory below remains a design
audit; it does not imply those adapters have all been implemented.

Date: 2026-10-08. Architecture: native macOS host with independently packaged executable extensions. This is a source audit and proposed contract, not an implemented SDK.

## Findings

The current inventory justifies a shared library, but its implementation should have three parts: a small executable SDK, host-owned services, and optional integration adapters. Extension authors use one consistent interface; processes do not each reimplement global state, permissions, event watching or registration.

The repository declares **27 modules and 43 command entries**. Checked-in defaults enable 24 modules and disable `hermes-agent`, `hyperspace` and `projects`. These are source defaults, not proof of effective machine overrides or running services. The 43 commands are not a complete inventory: manifests also contain helper targets, and seven `home/bin` entries are absent from both command and target bridge declarations.

**25 of 27 setup/teardown pairs are validation boilerplate with no runtime operation.** Only agent-timer and markdown-clipboard perform substantive operations in those lifecycle files. Actual integration is elsewhere: templates, after-apply scripts, runtime commands and shared configs. Among manifest contributions, eight modules share `.skhdrc`, six share `.yabairc`, five share `.tmux.conf`, four share tmux's command catalog and two share Ghostty configuration. The primary abstraction needed is owned registration and reconciliation, not dozens of mandatory lifecycle callbacks.

Evidence: [module defaults](home/.chezmoidata/10-modules.yaml), `modules/*/module.yaml`, `modules/*/lifecycle/*`, [system behavior inventory](SYSTEM_BEHAVIORS.md). Counts were checked by parsing every manifest with `yq`; behavior findings below also inspect implementations and integration templates.

## Complete module mapping

“Host” means this facility belongs in the native app/runtime. “Adapter” means an optional integration with an external application or upstream utility. A row is not necessarily a future package: host infrastructure should not remain user-installed extensions merely because it is a module today.

| Current module | Default | Proposed home | Shared requirements and behavior to preserve |
| --- | --- | --- | --- |
| [agent-timer](modules/agent-timer/module.yaml) | On; automatic start off | Feature extension | Durable deadlines, scheduling, notification/sound, supervised bounded jobs, exact process/pane identity, report files, agent-event adapter. Preserve native-only expiry behavior and no automatic terminal input. |
| [app-focus](modules/app-focus/module.yaml) | On | Feature extension | App/window discovery, focus events, MRU state, launch-and-await-window, invocation focus snapshot, shortcut scopes. MRU/zen/presentation policy remains feature code. |
| [appearance-pip](modules/appearance-pip/module.yaml) | On | Feature extension + borders adapter | Window-created/title events, tmux client/session events, geometry, window rules and managed borders service. Preserve scratchpad exclusion and PiP policy. |
| [dependencies](modules/dependencies/module.yaml) | On | Host | Artifact/dependency inventory, versions, availability and drift; package-provider adapters. Distinguish external prerequisites from commands provided by the package itself. |
| [dotfiles-control-center](modules/dotfiles-control-center/module.yaml) | On | Native host foundation | Existing SwiftUI views and typed command client are reusable; runtime needs streaming, limits, cancellation and generic registry-driven UI. |
| [dotfiles-manager](modules/dotfiles-manager/module.yaml) | On | Retire UI after native parity | Migrate settings, module/dependency/shortcut browsing; retain compatibility launcher only if useful. Do not carry a second Textual UI and Python environment into the public default. |
| [gh-create-repo](modules/gh-create-repo/module.yaml) | On | Upstream executable adapter | Working directory, external authentication status, structured form or terminal/editor launch, cancellation and result reporting. Repository creation is an explicit action, never retried automatically. |
| [hermes-agent](modules/hermes-agent/module.yaml) | Off | Optional upstream launcher | Terminal execution, profile availability, scoped environment. Preserve externally owned credentials/profile data; do not add agent orchestration to the core library. |
| [hyperspace](modules/hyperspace/module.yaml) | Off | Deferred feature | Session slots, terminal opening, config/state, shortcut scopes. No new 1.0 API should be created solely for this dormant experiment. |
| [kit-tts](modules/kit-tts/module.yaml) | On | Upstream executable adapter | Input/file selection, watcher debounce, streamed progress, audio job cancellation, model/cache availability and dependency health. Keep synthesis/model policy upstream. |
| [macos-default-apps](modules/macos-default-apps/module.yaml) | On | Upstream executable adapter | Application identity/picker, inspect/set handler actions, explicit effects and errors. Disabling the extension must not blindly reverse subsequent user changes to handlers. |
| [markdown-clipboard](modules/markdown-clipboard/module.yaml) | On | Feature extension | Clipboard snapshots/types, change tracking, preservation of metadata, bounded conversion subprocess, conditional write, self-write suppression. Preserve sensitive/rich-content exclusions and existing code-block tests. |
| [module-lifecycle](modules/module-lifecycle/module.yaml) | On | Host | Registry validation, enabled state, dependency ordering, plans, activation journal, owned resource disposal and recovery. |
| [notifications](modules/notifications/module.yaml) | On | Host service + CLI facade | Notification grouping/replacement, sound, delivery availability and user preferences. Do not promise that a requested Focus override is guaranteed. |
| [projects](modules/projects/module.yaml) | Off | Deferred feature | Project-root selection, durable bookmarks, window/space associations and picker. Preserve saved projects; no need to restore ProjectDeck for 1.0. |
| [qutebrowser](modules/qutebrowser/module.yaml) | On | Configuration package/adapter | Owned config contribution, application availability, preservation of bookmarks/profiles and conflict detection. It has no executable command; do not require an idle process for a static package. |
| [scratchpads](modules/scratchpads/module.yaml) | On | Feature extension | Terminal launch, named windows, window rules, focus restoration, geometry, per-label serialization and session ownership. Avoid duplicate windows under repeated invocation. |
| [settings](modules/settings/module.yaml) | On | Host service | Schema/defaults, typed validation, app/sound/command value providers, effective settings, revisioned change delivery and grouped reload. |
| [shortcut-guide](modules/shortcut-guide/module.yaml) | On | Host UI/service | Show command registry, scoped shortcuts, help and rebind conflicts directly. Eliminate reverse-parsing generated skhd config as the public source of truth. |
| [space-display](modules/space-display/module.yaml) | On | Feature extension + window backend | Display topology, focused-space snapshots, move/create/close operations, availability checks, bookmark state. Keep scripting-addition setup/repair a separate explicit maintenance operation. |
| [system-uninstall](modules/system-uninstall/module.yaml) | On | Host | Resource ledger, backups, modification checks, restoration and data-preservation policy. Cleanup must work even when an extension executable is broken. |
| [terminal-window-types](modules/terminal-window-types/module.yaml) | On | Terminal adapter + feature | Typed sessions/windows, cwd/environment, exact IDs, per-session locks, session-created events, status labels, terminal key mappings. Preserve already running panes. |
| [tmux-sessions](modules/tmux-sessions/module.yaml) | On | Terminal adapter + features | Session inventory, picker, pane previews, explicit user input, close/move-client behavior, persistent workspace layouts, supervised background jobs. Keep layout and agent-status interpretation outside the generic runtime. |
| [tmux-yazi](modules/tmux-yazi/module.yaml) | On | Feature using terminal adapter | Current pane directory, ensure/toggle pane or window, per-session serialization, owned pane markers and restore descriptors. |
| [todo](modules/todo/module.yaml) | On | Upstream executable adapter | Structured commands and interactive terminal mode, explicit task-store context, serialized mutations, durable user data. Preserve `AGENT_TODO_DIR` when intentionally supplied; do not replace Tuxedo's own data/locking implementation. |
| [unescape-cli](modules/unescape-cli/module.yaml) | On | Upstream executable adapter | Plain stdin/stdout filter, encoding and exit status. Demonstrates an extension needing no event loop or persistent service. |
| [window-layout](modules/window-layout/module.yaml) | On | Feature extension | Window/geometry actions, focus context, per-window serialization, persistent float preferences, declarative rules. Snapping/tiling policy remains in the extension. |

## Integrations outside the module list

Seven home-bin entries lack manifest command/target bridge ownership:

| Helper | Proposed treatment |
| --- | --- |
| [browser-use-helium](home/bin/executable_browser-use-helium) | Optional browser adapter: detect the local debugging endpoint, declare the Browser Use dependency, pass scoped environment and report unavailable debugging. Do not expose browser sessions to all extensions. |
| [ghostty-startup-bench](home/bin/executable_ghostty-startup-bench) | Developer diagnostic using bounded subprocesses and owned temporary windows; exclude from consumer defaults. |
| [lucide-icons-excalidraw](home/bin/executable_lucide-icons-excalidraw.tmpl) | Existing Raycast development launcher; retain as optional developer tooling or package its useful action separately. Running `npm run dev` is not consumer installation. |
| [man-me](home/bin/executable_man-me) | Generate help/search from the command registry; keep compatibility discovery for unmanaged tools as a separate feature. |
| [reload-colors](home/bin/executable_reload-colors) | Replace broad service restarts with a settings transaction that reloads each affected adapter once. |
| [tmux-command-palette](home/bin/executable_tmux-command-palette) | Terminal adapter consumer of the same command registry; preserve invoking client/pane and popup semantics. |
| [watch-sync](home/bin/executable_watch-sync) | Developer-only watch/validate/reload workflow; not a background consumer installer. |

There are also app-owned plugin/configuration ecosystems: 29 VSCodium extension declarations, one Chrome extension declaration, six external project declarations, TPM/tmux plugins, Yazi packages, Neovim configuration and Karabiner rules. Counts come from [source data](home/.chezmoidata.toml); this audit does not enumerate every extension installed interactively on this Mac. Keep those ecosystems' native package formats. An adapter can inspect/install/configure them; they are not all executable extensions of our host.

The [Karabiner configuration](home/dot_config/private_karabiner/karabiner.json) includes sided modifiers, tap/hold and transient leader behavior. Model these as an optional remapping adapter with owned rules. A simple global-shortcut library cannot be assumed to reproduce this behavior. Likewise, qutebrowser and Yazi require managed configuration without an extension process.

## What already exists to reuse

[The shared shell library](home/dot_local/lib/dotfiles) already separates `core.sh` (diagnostics/dependencies), `state.sh` (namespaced paths and atomic replacement), `locks.sh` (stale-safe locks), `prefs.sh` (settings), `tmux.sh` (commands/locks), `yabai.sh` (queries/focus context) and `ghostty.sh` (identify/await a newly created window). [Its tests](tests/test_dotfiles_lib.sh) supply useful contracts. Port those contracts to the new runtime instead of embedding shell sourcing into every new binary.

There is still duplication: scratchpads and terminal opening have their own locking; configuration helpers recur in notifications/app-focus/scratchpads; timer code implements worker supervision, deadlines and cleanup; the clipboard launcher compiles code and writes a LaunchAgent. The native [CommandClient](modules/dotfiles-control-center/Sources/DotfilesControlCenter/CommandClient.swift) already accepts an injected process runner and decodes structured results, but its live runner waits for exit and captures whole output files without explicit bounds or cancellation handling. It is a foundation, not yet the extension runtime.

## Proposed standard-library surface

The names below describe proposed API responsibilities, not functions that already exist.

| Surface | Common API | Execution owner and required semantics |
| --- | --- | --- |
| `runtime` | register handlers, dispatch commands/events, cancellation, structured result/error/progress | SDK inside the extension; version handshake, stdout protocol isolation, bounded messages, sensible defaults for unused hooks. |
| `context` | extension identity, invocation ID, cwd, explicit environment, focused app/window/display/space, terminal target | Host captures context when invoked. Opening the app UI must not change the operation's intended target. Revalidate targets before mutation. |
| `settings` | typed snapshot, schema validation, value providers, change notification | Host persists revisions; SDK decodes. Distinguish desired vs successfully applied configuration; report restart-required or rejected updates. |
| `state` | data/cache/temp paths, atomic writes, scoped locks, schema migration | Host assigns roots and resource ownership; SDK supplies local helpers. Durable user data survives disable; cache is disposable. Locks must remain effective when CLI and worker processes overlap. |
| `process` | execute argv, stream output, deadline/cancel, supervised job | Host/runtime tracks process lifetime and child cleanup, drains both streams, caps output and bounds restart attempts. SDK does not make extensions install their own service. |
| `events` | subscribe/filter/dispose, snapshot/resync, source identity | Host owns subscription IDs; adapters translate native and external events. Generation tokens reject late events after disable/update. Use bounded queues and declared coalescing, not an unbounded global bus. |
| `schedule` / `files` | recurring/deadline jobs; watch/debounce/change snapshot | Host owns timers/watchers. Define missed-deadline behavior on sleep/restart and serialize callbacks. File watching handles atomic replacement, truncation and self-writes. |
| `notifications` / `ui` | notify, progress, form, picker, confirm, open URL/file/terminal | Host displays a limited set of native surfaces. Workers request a user interaction without blocking all dispatch. Domain UI such as a session dashboard can remain in its existing terminal app initially. |
| `clipboard` | snapshot representations, observe changes, write-if-current | Host broker retains raw types/metadata and checks the revision immediately before write. Keep content out of logs and avoid sending it to unrelated subscribers. Conversion policy belongs in the formatter. |
| `desktop` | app/window/display inventory, focus/launch, geometry, rule registrations | Host capability service with a first yabai/macOS implementation. Expose feature availability; do not assume replacing yabai is required for the first app release. |
| `terminal` | sessions/windows/panes, open/ensure/select, cwd, scoped hooks, explicit send/close | Optional tmux/Ghostty adapter. Use stable IDs and cwd from invocation; preserving terminal workloads differs from stopping a supervised extension worker. |
| `integration` | owned configuration contributions, dependency status, reload request | Host plans changes, detects conflicts, applies with a ledger and checks for user edits before restore. Provider-specific merges for tmux, Ghostty, Karabiner and other apps; no universal arbitrary-text patch hook. |

App-wide secrets should not be passed in the default process environment. Initially let upstream tools such as `gh` own authentication and report availability. Add a scoped Keychain service when a concrete extension needs host-managed credentials; do not build an OAuth platform speculatively.

## Lifecycle hooks and defaults

Registration comes from the manifest and must be inspectable without running extension code. Host installation, enablement and removal are durable state transitions. Process startup is a separate lifecycle: enabling one command-only extension should not leave an idle worker running.

| Hook | When used | Default and failure behavior |
| --- | --- | --- |
| `initialize(context)` | RPC worker startup | Negotiate API/capabilities, receive settings/paths and return readiness within a deadline. A failed handshake leaves the worker unavailable. Plain CLI commands use an adapter instead. |
| `execute(command, input, context)` | Explicit action or declared trigger | Return a typed result/error; support cancellation. Plain filters can remain normal argv/stdin/stdout programs. Never automatically retry external mutations such as repository creation. |
| `handleEvent(event)` | Only for declared subscriptions | Serialized delivery by default; explicit concurrency where needed. Include resource identity, revision and origin. Resnapshot on detected gaps; do not promise exactly-once delivery across crashes. |
| `settingsChanged(previous, next, revision)` | Live settings update | Apply/acknowledge, reject with a reason, or request a controlled restart. Command-only extensions receive the latest snapshot on their next invocation. |
| `health()` | Doctor/UI or bounded recovery check | Read-only, cheap, timed. Host supplies process/dependency health; custom checks add feature readiness. Missing optional capabilities mean degraded status, not necessarily total failure. |
| `migrateState(from, to)` | Only when a declared data schema changes | Quiesce concurrent writers and snapshot before mutation. Track the completed version so retries are safe; define compatibility before offering downgrade. No hook for stateless extensions. |
| `shutdown(reason, deadline)` | Worker disable/update/app exit | Stop new work, cancel handlers and release resources. Host cleans registrations and terminates remaining owned processes even if this callback crashes. |

Avoid mandatory `onInstall`, `onUninstall`, `onShortcut`, and `onWake` boilerplate. Installation/removal use declarative resources; shortcuts invoke commands; wake is a subscribed event. If an exceptional feature needs custom setup, require an explicit planned action with bounded execution and documented recovery rather than a free-form installer that bypasses ownership.

Enable flow: validate package/dependencies → plan registrations → prepare state → start/handshake a worker if needed → commit registrations and mark ready. Failure withdraws the generation's registrations and records a recoverable state. Disable first stops event delivery, then drains/stops the worker and releases registrations. This protects shared resources, but does not make arbitrary external effects atomic.

## Event and resource details exposed by this inventory

- **Clipboard:** the current worker polls `changeCount` every 200 ms, ignores content present at startup and guards against a newer copy arriving during conversion. Centralize observation; do not replace those semantics with an assumed native clipboard-change callback. Multiple transformers need explicit ordering/conflict policy and self-write suppression. The host's revision check is best-effort protection against other applications, not an OS-level atomic compare-and-swap. See [current implementation](modules/markdown-clipboard/src/main.swift) and Apple's [changeCount](https://developer.apple.com/documentation/appkit/nspasteboard/changecount).
- **Window/focus events:** MRU updates on focus; PiP reacts to creation/title change; scratchpads and float preferences install rules; Spaces setup reacts to Dock restart. Provide query/resync as well as events. Preserve the initiating focus/space snapshot through window creation and reject stale IDs. Evidence: `modules/app-focus/targets/yabai-signals.sh.tmpl`, `modules/appearance-pip/targets/yabairc-signals.tmpl`, `modules/space-display/targets/yabairc-scripting-addition.tmpl`.
- **Terminal events:** border accents use attach/detach/focus/session-change/rename hooks; typed windows use after-new-session. Allocate hook ownership centrally instead of hardcoding indexes such as `[50]` and `[60]`. Closing the host or disabling a Yazi integration must not kill unrelated user sessions.
- **Timer events:** agent-timer contains persisted state, deadlines, locks, PID/start-time checks, bounded report subprocesses and cleanup. Extract these mechanics, retaining recurring checkpoint and report policy inside the extension. No automatic terminal input follows from adding an event API.
- **File/model jobs:** kit-watch debounces file events and handles truncation; Kit downloads/caches models and streams audio. Generic watchers, progress and cancellation help. Model selection and speech synthesis remain upstream. These findings include a limited read of the current `~/projects/kittentts-cli` entrypoints, not a full upstream audit.
- **Configuration ownership:** current qutebrowser configuration is an exclusive target; Karabiner is a full personal profile. A public installer must detect existing user configuration and offer a reviewable import/merge or conflict instead of treating those files as disposable. Cleanup uses the installed ownership ledger, not a callback that must still be executable.

## Packaging the library

Use **one protocol and a small Swift SDK first**, delivered through Swift Package Manager, with a CLI compatibility adapter for the existing Bash/Python/Node utilities. The host service implementation is a separate Swift target from extension-side code. This avoids linking registration databases, UI or global watchers into every extension. Additional language bindings can share protocol fixtures when an actual new extension needs them; do not launch several SDKs at once.

For subprocess execution, evaluate the Swift project's [swift-subprocess](https://github.com/swiftlang/swift-subprocess) against the selected toolchain instead of rebuilding stream/cancellation machinery. The existing native package declares Swift tools 5.9; adopting a newer dependency may require a deliberate toolchain upgrade. Pin and test the selected package version. JSON-RPC supplies message semantics; our [stdio framing, lifecycle methods and compatibility contract](https://www.jsonrpc.org/specification) remain explicit project decisions.

Proposed package boundaries: `ExtensionProtocol` (messages/schema/fixtures), `ExtensionSDK` (author helpers), `HostRuntime` (processes/registry/state/events), and optional adapter targets. A `dev` loader and `check` tool exercise the same runtime used by the app. Authors ship an executable plus manifest/resources; self-contained artifacts or declared/bundled runtimes avoid end-user build dependencies.

Trusted native executables retain user-level OS access. The SDK can gate requests to host services and improve cleanup, but it is not an OS sandbox. Registration ownership is a correctness contract, not a claim that arbitrary third-party code cannot write elsewhere.

## Implementation order and acceptance

1. Build the manifest/protocol, CLI adapter and conformance runner with tiny fixture executables. Prove invocation, incompatibility errors, settings/context delivery, cancellation, output limits and disable cleanup. Use unescape as the simplest real CLI adapter.
2. Add settings/state/notifications and the clipboard broker. Move clipboard conversion into an independently packaged extension while retaining the format, code-block, sensitive-content and newer-copy regression cases. Prove install/update/recovery end to end.
3. Add desktop events/context and owned shortcut/rule adapters. Migrate app-focus, window-layout, space-display and scratchpads against the existing backend. Test simultaneous launches, display rearrangement, focused-space creation and unavailable permissions/scripting addition.
4. Add terminal adapter and supervised jobs/scheduling/watchers. Migrate typed windows, sessions/Yazi, border accents and agent-timer, followed by kit-watch. Preserve user sessions and task stores under disable/restart.
5. Add optional configuration/plugin-provider adapters and migrate the remaining upstream utilities. Derive shortcut/help UI from registration. Retire redundant managers and build-on-launch setup only after equivalent flows are validated.

Conformance tests must exercise malformed/hung/crashing executables, large output on both streams, late events after update, reentrant focus/clipboard events, conflicting shortcuts, missing tools, failed settings application, sleep/restart deadlines, failed migration and uninstall after user edits. A plain CLI extension should need no lifecycle code. A worker should need only its handlers. Static configuration packages should need no process at all.

## Audit boundaries

Reviewed all 27 manifests and their lifecycle files, module enablement defaults, shared libraries, representative runtime implementations, integration templates, extra home-bin commands, and external dependency inventories. Read selected local entrypoints for the five upstream utility projects to clarify adapter needs; their entire implementations/releases were not audited. No clipboard contents, credentials or task payloads were used for this design. No services, installations or runtime configurations changed, and no SDK was built. Documentation coverage was checked against the manifest inventory; existing runtime tests were not rerun for these documentation-only changes.
