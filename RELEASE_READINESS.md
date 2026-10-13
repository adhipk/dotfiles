# Public 1.0 release readiness audit

Date: 2026-10-08. Scope: installation and ongoing use by people other than the author.

**Verdict: not ready for a public stable 1.0 release.** The project has useful foundations: Chezmoi desired state, 27 validated module manifests, focused tests, dependency inventory and Git pins, module rollback, and backed-up uninstall/restore. The missing contract is a repeatable, supported installation and upgrade on a machine without the author's existing environment.

The original audit below examined `f281659` plus the uncommitted Hermes-removal changes. It is a historical baseline, not an immutable release candidate or a statement that subsequent remediation is absent.

Implementation update: `1.0.0-dev.2` adds the native executable-utility host,
Swift standard library, package/settings store, shortcut registration, launchd
service controls, independent app bundle build, manifest-discovered regression
runner, machine-readable reports, and macOS CI workflow. See [NATIVE_APP.md](NATIVE_APP.md)
for the current implementation and remaining release gates. The old test counts
and absence-of-CI findings below describe the audit snapshot. The October 13 remediation adds service crash recovery/log rotation, shared
app/CLI activation journals, the consumer desktop installation profile,
Apache-2.0 licensing, bundled clipboard dependency and strict signed-release gates.
The public scope includes every enabled desktop/terminal module. The native app
alone remains a host plus integration adapters; the consumer profile supplies the
broader environment. Remote CI/protection, clean-device acceptance, full bundled
GPL source review, signing/notarization and publication remain unaccepted external
gates. The historical requirements below describe the baseline gaps; current
implementation is documented in NATIVE_APP.md and CONSUMER_SETUP.md.

## Release blockers

### 1. Establish a public installation profile

The default Brewfile installs the full personal collection, including several agents, browsers, editors, and work applications. `bootstrap.sh:71-87` installs that entire file, then installs Browser Use and starts desktop services. `home/.chezmoiexternal.toml.tmpl:17` enumerates all external projects independently of module enablement. Several URLs in `home/.chezmoidata.toml:107-165` require GitHub SSH authentication. These are obstacles even if the repositories happen to be public. Global personal agent instructions and skills are also deployed under `home/dot_agents`.

**Required:** introduce a small public default profile and opt-in desktop, agents, browser-extension, and author-personal bundles. Derive package installation, external clones, hooks, and service starts from selected capabilities. Public prerequisites must be downloadable without the author's account; use HTTPS for public sources and make authenticated integrations explicit. Keep reusable utility implementations upstream.

**Acceptance:** a new macOS user with no GitHub SSH keys can install the default profile without author-specific paths, projects, credentials, work applications, or agent behavior. Declining optional features must prevent their downloads and service starts, not only remove their command links.

### 2. Define one effective configuration model

The module data advertises machine overrides in the user's Chezmoi config (`home/.chezmoidata/10-modules.yaml:4-5`), but `modules/module-lifecycle/bin/dotfiles-module:118-121` reads enablement from the checked-in YAML. Its mutations also edit that YAML. Settings detects a masked machine override and asks the user to edit it manually (`modules/settings/bin/dotfiles-settings:389-395`). These paths do not offer one consistent interface for per-machine customization.

Some runtime helpers default to `$HOME/dotfiles`, including the control panel and shortcut guide, while the README also discusses Chezmoi's default source directory. This makes checkout location part of an implicit runtime API.

**Required:** define precedence for release defaults, selected profile, machine-local preferences, and secrets. Have status, plan, apply, and the UI consume the same effective values. User customization should not dirty the tracked release checkout. Render or discover the actual source root rather than requiring a particular clone path.

**Acceptance:** install under another username and a checkout path containing spaces; change settings through the UI; update the release; verify local preferences persist and all status/plan/apply results agree. Exercise machine overrides explicitly.

### 3. Make bootstrap a resumable and diagnosable workflow

There are two divergent bootstrap executables: `bootstrap` and `bootstrap.sh`. The longer one prints approval instructions after mutation and does not provide a consolidated capability diagnosis. Service-start failures are warnings. Optional extension setup may skip missing prerequisites or continue after failures. `bootstrap.sh:95-98` still recommends the Hermes setup command removed by the current work. This is a concrete documentation/install-contract regression.

**Required:** keep one implementation and make the alternate name a delegating wrapper. Add a preflight/doctor command checking the supported OS/architecture, Command Line Tools, package executables, Accessibility/Input Monitoring, scripting-addition availability, and runtime health. Distinguish required failures, optional failures, and manual approval steps. Persist phase results and expose an explicit retry/resume path.

Support a useful baseline without the scripting addition; describe the additional space-management capabilities that require it. Do not equate unavailable macOS permissions with a successful desktop setup.

**Acceptance:** clean install, second install, interrupted install, denied approvals, missing optional tools, and offline recovery each produce a clear state and next action. A restart/reboot followed by doctor confirms the installed state. A denied optional capability leaves the baseline usable.

### 4. Turn the existing tests into an enforced release gate

`make test` already delegates to a 34-suite runner. Preserve useful behavioral coverage while selecting the standard test framework for the chosen implementation; rewriting every existing shell test first would not address the release gap. The runner hand-maintains its list, buffers each suite until it exits, has no per-suite timeout, and derives totals by parsing one particular output format (`tests/run_all_tests.sh:19-54,81-103`). Several suites report in other formats. Exit status is tracked separately, so inaccurate totals do not by themselves imply a false successful exit.

The manifest-declared Notifications and qutebrowser tests are omitted from this runner. The integration suite allows a stopped yabai/skhd to produce warnings rather than failures. Many checks assert source text, and installer tests use mocks or render with scripts/externals excluded; these are useful but not proof of full clean-device installation.

GitHub inspection found zero Actions workflows, no classic protection on `main`, and no repository rulesets. There are no release tags or GitHub releases.

**Required:** discover module tests from manifests or enforce a coverage registry; retain parent integration tests explicitly. Emit machine-readable pass/fail/skip results, stream logs, and enforce timeouts. Separate static/portable, isolated macOS integration, and opt-in live-desktop acceptance tiers. Require all selected-profile tests and shortcut-catalog checks in CI. Protect the release branch with those checks.

**Acceptance:** a fresh CI runner reproduces the suite without the author's caches, plugins, live services, or user config. Every module test is accounted for. Missing mandatory tools and required live checks cannot pass as skips. Failures attach per-suite logs. Test a new user/home, nonstandard checkout, install twice, enable/disable, interrupted apply, upgrade, rollback, and uninstall preservation.

### 5. Introduce a real release and dependency policy

The repository is public but has no project-root license, release history, versioned support promise, or release workflow. Individual modules saying `version: 1.0.0` does not version the overall installation. The existing dependency snapshot contains installed paths and versions observed on one machine; its README correctly describes Homebrew as rolling. Immutable Git pins and the UI dependency lock are valuable, but they do not make the full environment reproducible.

**Required:** choose a root license and review bundled third-party notices; publish a project version, changelog, support matrix, migration notes, and release checklist. Build releases from a clean tested commit and publish immutable tags. Pin Git/extension dependencies where practical; for rolling Homebrew components, record the tested versions, enforce necessary minimums/compatibility probes, and schedule drift testing rather than promising unavailable historical bottles. Make dependency updates reviewed changes.

**Acceptance:** an installer can select a named release, doctor reports the installed release and dependency state, and the published support matrix names only tested OS/architecture/profile combinations. Public installation and documentation do not assume GitHub SSH access. Signing/notarization becomes a requirement if prebuilt native applications are distributed; it need not block a source-only release.

### 6. Provide installation and upgrade recovery

Module operations have targeted rollback and the system-uninstall command has a backup ledger and restore path. In contrast, `install.sh:173-194` applies files before plugin installation, pin application, reloads, and native builds. A later failure can leave a partially changed installation. `chezmoi update` is documented as the update path, but it does not run the wrapper's post-apply phases. Uninstall restoration is not a demonstrated release downgrade.

**Required:** one documented update command that stages/validates the candidate, snapshots changed owned files and prior version state, executes ordered phases, checks health, and either completes or provides a tested recovery path. Record irreversible/external effects separately; avoid promising atomic rollback of Homebrew, permissions, or arbitrary external commands. Add explicit state/schema migrations when formats change.

**Acceptance:** upgrade a previous candidate with customized settings and running sessions, inject failure at each phase, and recover the previous working configuration without losing user data. Verify preserved profile/task data survives disable and uninstall. Prove the documented update command runs all required phases.

### 7. Enforce the module boundary before expanding it

`MODULE_PLATFORM.md` describes dependency resolution, collision detection, generated composition, a transactional reconciler, and a scaffolder. The current lifecycle validator checks manifest shape, target paths, hooks, and duplicate data keys; it is not that full compiler. Install still unconditionally installs tmux plugins and builds the shortcut guide (`install.sh:184-190`). The public profile cannot safely assume that disabling any module removes all of its installation side effects.

Both the native Swift control center and the Textual manager remain enabled in the default data. README setup directs users to the native control center, while the platform document calls Textual canonical. This duplicates testing and creates uncertainty about which interface is supported.

**Required:** choose one supported control center; keep the other experimental or a compatibility launcher. Validate enabled-module dependencies, exclusive destination collisions, shortcut conflicts, and service identities. Make install respect module enablement. Inventory stale managed targets after source removal. Share cold-home fixture construction across tests to stop every module reimplementing an incomplete copy of the parent repository.

**Acceptance:** disabling a feature removes its entry points and stops its services while preserving declared user state; unrelated features still render and work. Missing dependencies and conflicting owners fail during planning. The UI and CLI return the same plan. The remaining platform vision can be delivered incrementally after 1.0.

## Architecture decision: native macOS app with executable extensions

**Selected direction:** a custom macOS app owns installation, registration, settings, shortcuts, events and process lifecycle. Extensions are independently packaged executables. This is a bounded application integration problem using established process, packaging and protocol conventions. It does not require an embedded language runtime, an in-process plugin ABI, or adopting another consumer application as the extension host.

The [extension standard-library audit](EXTENSION_STDLIB_AUDIT.md) maps all 27 current modules and the additional integrations to common hooks, host services and adapters. It defines the proposed SDK scope and migration order using current implementation evidence.

The earlier comparison of Raycast, Hammerspoon, Nix and mise informed the alternatives; none is a prerequisite for this design. Homebrew and Chezmoi can remain implementation details of optional developer-workstation integrations. Installing an ordinary extension must not require cloning this repository, editing a Brewfile, or running a build.

### Host and extension responsibilities

| Concern | Native app owns | Executable extension owns |
| --- | --- | --- |
| Registration | Validate manifests, namespace IDs, resolve compatibility, reject conflicting registrations, persist enablement | Declare commands, supported host API, settings, and requested integrations |
| Invocation | Launch by absolute executable path and argument array, pass input, collect output, enforce timeout/cancellation | Perform the operation, return a documented result and exit status |
| Settings | Render supported schema fields, validate/persist values, retain user overrides across updates | Declare defaults and consume resolved configuration |
| Desktop wiring | Register shortcuts and supported event subscriptions; surface macOS approval state | Implement feature behavior using the agreed host interfaces or explicitly declared external tools |
| Lifecycle | Start/stop supervised workers, bound restart attempts, expose health and logs, remove registrations on disable | Exit cleanly, report readiness/failure, avoid hidden self-installed services |
| Installation | Verify/extract packages, stage a version, activate after validation, retain a previous version | Ship an executable plus resources and metadata for supported OS/architectures |
| User data | Supply a stable per-extension data directory; keep it separate from immutable installed versions | Document persistent data and any schema migration |

Existing CLIs can be registered with static argument mappings or small adapters. Upstream utility repositories continue to own their implementations and releases. Commands that fundamentally depend on tmux or another application declare that dependency; converting a launcher into a binary does not remove the underlying runtime requirement.

### Reuse standard mechanisms

- Build the app with SwiftUI/AppKit and Swift Package Manager. Use Foundation [Process](https://developer.apple.com/documentation/foundation/process) and pipes for child executables. Never require shell interpolation to invoke an extension.
- Use a versioned JSON manifest validated against JSON Schema. Identity, version, OS/architecture, entry point, commands, settings and dependencies are declarative. Support a documented subset of schema field types in the settings UI; arbitrary schema features need not imply arbitrary UI generation.
- Start with ordinary CLI arguments, stdin/stdout and exit codes for one-shot commands. For workers needing events, progress or callbacks, use [JSON-RPC 2.0](https://www.jsonrpc.org/specification) over stdio. Specify framing separately, for example one compact JSON message per line, with diagnostics on stderr. JSON-RPC defines message semantics, not stream framing, cancellation or our method names; those belong in a small versioned host contract.
- Keep the host running through an explicit login/background setting. Evaluate [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) for an app-owned login item or bundled helper against the selected minimum macOS version. The host supervises extension workers; third-party extensions do not each install their own LaunchAgent by default.
- Use [Sparkle](https://sparkle-project.org/) for app updates. Extension packages have a separate versioned catalog and verified download/install path; Sparkle does not automatically update arbitrary extension binaries. A static catalog and release assets suffice initially.

The reusable parts are execution, schemas, IPC and app lifecycle. Our registration rules and feature API are product-specific, but small enough to implement deliberately. A universal package-manager dependency solver or hosted marketplace is not required for the first release.

### Registration and installation flow

An extension package contains `extension.json`, `bin/<executable>` and optional resources. Prefer self-contained binaries; an extension written in an interpreted language must bundle its runtime or declare a supported dependency the app can resolve. Users should not discover a missing Python or Node installation after pressing a command.

The app stages a selected version under its Application Support directory, validates metadata and platform compatibility, checks package identity/integrity and executable paths, and computes all registrations before enabling anything. Entries are owned by extension ID: command IDs, shortcut assignments and event subscriptions can then be removed reliably without uninstall scripts. Conflicts produce a visible choice rather than silently replacing another extension's binding.

Keep installed artifacts immutable and settings/data outside version directories. For an update, validate and smoke-test the candidate, quiesce the old worker if needed, switch the active version, then check readiness. Retain the old version for recovery. Binary rollback does not reverse data migrations automatically; extensions with persistent state need a compatible migration or snapshot strategy. Uninstall removes owned registrations and code, with a separate explicit choice to remove user data.

For 1.0, provide a curated catalog and explicit local development installation. Ordinary binary extensions are trusted code running as the user; a capability list describes requested integrations and can gate host APIs, but is not an OS sandbox. Determine signing/notarization and macOS permission behavior using the actual distributed app and extension artifacts. Do not assume a child executable inherits every approval granted to the host. Keep Accessibility and other shared OS operations in the host where practical, and test any extension that needs direct access separately.

### Authoring and validation contract

Authors need a template, a manifest schema, a local development loader, and a conformance checker. The checker should verify package layout, supported protocol/version, command invocation, settings validation, clean termination and any declared worker handshake. The author can use any implementation language and its usual test tools; no mandatory heavy SDK is needed. An optional thin library can make JSON-RPC workers easier to write.

Keep one top-level CI entry point. Use Swift Testing/XCTest for the host, protocol fixtures and fake executables for subprocess behavior, and the existing behavioral fixtures for migrated features. Cover hung/crashing workers, output flooding, malformed responses, invalid manifests, duplicate shortcuts, failed upgrades and preservation of settings/data. Run separate macOS acceptance tests for permissions, login/reboot and multi-display behavior.

The first implementation milestone is one complete vertical slice: install clipboard-to-Markdown from a package, register its command/shortcut, configure it, execute it, update it, disable it and remove it. Preserve the existing clipboard format/code-block regression cases. Then port display/window movement to test OS integration and border accents to test persistent lifecycle. Each extension must live outside the app source and require no core changes to register. These are implementation milestones for the selected architecture, not a requirement to reopen the choice of host.

### Public 1.0 scope

Deliver an app/extension installation experience for an explicitly tested macOS/architecture range. Apple Silicon first is a proposed way to limit the matrix; exact OS versions and architecture support still need to be selected and tested. Preserve the personal dotfiles distribution as an optional profile or separate product layer. It should not be the prerequisite for installing a clipboard or window extension.

Keep one supported control interface and one supported terminal integration. Advanced space features need capability checks and documented approvals. Defer cmux migration and expanded agent orchestration unless implementing the selected architecture demonstrates that they are necessary. Extension scaffolding and an independently installable example are part of 1.0 acceptance; a custom general-purpose marketplace is not.

## Delivery sequence

1. Establish a green behavioral baseline and implement the native host/executable-extension contract. Finish/review the pending Hermes cleanup, resolve failing suites, refresh generated shortcuts, and make CI required. Prove the full clipboard-extension lifecycle before migrating more modules.
2. Extract personal configuration and migrate features into independent executable packages. Deliver a minimal public app installation, effective machine settings, an author template and conformance checker. Reuse existing implementations behind adapters where practical; follow the clipboard slice with window/display and persistent-service features.
3. Make installation, diagnosis, update, and recovery dependable through the chosen host/tooling. Add failure injection and a documented approval/resume flow. Port behavioral tests to the chosen language's standard runner as implementation moves; keep legacy integration checks during migration.
4. Publish a release candidate. Run the exact documented install on clean accounts/devices covering the supported matrix, retain the evidence, and exercise upgrade/uninstall/restore.
5. Tag 1.0 only after the acceptance checklist passes. Maintain release branches/tags and a small scheduled dependency-compatibility run.

## Release acceptance checklist

- [ ] Public profile installs without author credentials or personal checkout paths.
- [ ] Supported OS/architecture/profile matrix is explicit and tested.
- [ ] One setup implementation, one update workflow, and one supported control panel.
- [ ] Per-machine preferences persist across update without modifying release defaults.
- [ ] All required suites, generated artifacts, and cold-home checks pass in protected CI.
- [ ] Fresh install, repeat apply, reboot, denied approvals, and interrupted setup are validated.
- [ ] Upgrade, phase failure, recovery, disable, uninstall, and user-data preservation are validated.
- [ ] Every selected module's commands, dependencies, hooks, and health checks are accounted for.
- [ ] A consumer installs/configures/removes an extension without source edits or a development build.
- [ ] An independent author builds and tests an extension without modifying the core repository.
- [ ] Extension API compatibility, data ownership, update failure and execution trust are documented and tested.
- [ ] License/notices, changelog, release version, troubleshooting, and migrations are published.
- [ ] Clean immutable release candidate has independent clean-device acceptance evidence.

## Validation evidence

| Check | Observed result |
| --- | --- |
| `dotfiles-module validate --json` | 27 manifests validated. This does not prove complete lifecycle or conflict resolution. |
| `make test` | Failed in 118 seconds; runner reported 2,183 passed and 22 failed across six failing suites. Totals are subject to the runner's output-parser limitation. |
| Notifications module suite, separately | 40 passed, 0 failed; omitted from the top-level runner. |
| qutebrowser module suite, separately | 17 passed, 0 failed; omitted from the top-level runner. |
| `make shortcuts-check` | Failed: checked-in generated shortcut JSON and Markdown are stale. |
| GitHub/release inspection | Public repository; no project-root license detected, no tags/releases, zero Actions workflows, no classic main-branch protection or repository rulesets. |

The six failing suites were `test_configs.sh` (3), `test_window_layout.sh` (3), `test_tmux_workspace.sh` (5), `test_tmux_border_accent.sh` (4), `test_source_state.sh` (1), and `test_install.sh` (6). Failures include stale source-text expectations for display/window behavior and Hermes removal, parent-removal fixture rendering failures, and a bootstrap mock environment missing `uv` (`bootstrap.sh:46`). These are not evidence of 22 independent runtime defects, but they prevent treating the current suite as a green release gate.

Raw local output was captured at `/tmp/dotfiles-1.0-audit-tests.log`, `/tmp/dotfiles-1.0-notifications.log`, and `/tmp/dotfiles-1.0-qutebrowser.log`. These temporary logs are not durable release artifacts; a future CI run should publish them with the candidate commit.

Static findings and local tests do not establish a clean-device installation, live permission flow, or successful upgrade/downgrade. No bootstrap, package installation, service migration, repository protection change, or release publication was performed for this audit. The earlier Hermes changes remain separate uncommitted work.
