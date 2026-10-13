# Dotfiles native app

`1.0.0-dev.2` is a development prerelease of the macOS utility wrapper. It connects
executable utilities to settings, global shortcuts, and macOS-managed services.
Existing tools own their behavior: launchd runs persistent processes; yabai,
Ghostty, tmux, Tuxedo, and other utilities keep their existing responsibilities.

The app does not need this checkout, Chezmoi, a Brewfile, Python, or a shell setup
to run. The developer build currently targets the build machine's architecture
and macOS 13 or later. This deployment target is not yet a tested support matrix.
The existing personal installation remains available separately.

## Build and try

On a Mac with Xcode Command Line Tools (Swift 5.9 or newer) and Python 3:

```sh
make build-app
# Equivalent: ./bootstrap.sh --app
```

The build produces `dist/Dotfiles.app`, a versioned ZIP, SHA-256 checksum, and
`build.json`. It applies no personal dotfiles and starts no services. Open the
app from Finder; moving it to `/Applications` gives it a stable location before
enabling **Open at login**. Local builds are ad-hoc signed. They are not notarized
public downloads; do not disable Gatekeeper to distribute them.

In **Utilities**, choose **Add from included catalog → example.hello**, review
the package, enable it, and press **Run**. Save a name in Settings and optionally
record a shortcut. The app must remain running to receive global shortcuts;
closing its window leaves the menu bar item available. **Open at login** uses
macOS Login Items and may require approval in System Settings.

**Install a utility** imports a local package folder. New utilities start
disabled. Packages run as your user, with the same access as other executable
programs you install; this is not an extension sandbox. The importer checks
identity, paths, executable presence, schema compatibility, and package limits
without executing the utility. It does not establish publisher identity.

## Included utilities

| Package | Availability |
| --- | --- |
| Hello | Works using macOS `printf`; exercises settings and shortcuts |
| Markdown clipboard | Converter and checksum-pinned Pandoc included; one-shot action and optional clipboard watcher |
| App focus, scratchpads, notifications, timer status | Adapters for the consumer desktop profile |
| Default-apps, todo, TTS, unescape | Adapters for upstream commands installed by the consumer desktop profile |

**Check dependencies** resolves the package's declared command names and
arguments. It does not install dependencies or verify every transitive dependency,
macOS permission, or external configuration. The consumer desktop profile installs the existing desktop/terminal configuration
and pinned upstream utilities over HTTPS, with agents and work apps opt-in.
See [CONSUMER_SETUP.md](CONSUMER_SETUP.md). All 24 enabled desktop/terminal modules
and all ten included packages remain required for public 1.0 acceptance. The
three already disabled dormant integrations remain outside the consumer profile.
The native app by itself does not replace the desktop configuration.

## Settings, shortcuts, and services

Settings are validated from each package's schema and stored outside its code.
Saving settings restarts that utility's registered services. Commands receive
literal argument arrays, optional stdin, and a controlled environment. The host
does not assemble shell command strings. Noninteractive actions can have global
shortcuts; actions requiring text input or confirmation are run in the app.
Shortcut conflicts within the app are rejected, and macOS registration failures
are displayed. Existing skhd bindings are not automatically imported or removed.

**Start / Restart** creates an owned LaunchAgent and starts it. Registered
services continue when the app quits and run at subsequent logins. The bundled service runner
restarts a crashing foreground child up to three times, with 2/4/8-second backoff.
A clean exit stops recovery; an exhausted budget remains exited until an explicit
restart or the next login. launchd owns the runner even while the app is closed. **Status & Logs** reads
launchd state, the latest log tails, and an optional executable health probe.
**Stop**, disabling, or removing the utility stops its service and removes its
LaunchAgent. A failed stop preserves its registration and prevents removal.
Each output channel retains at most a 1 MiB active log and one 1 MiB backup
(4 MiB total per service), including while the app is closed. Unknown launchd
responses are errors; only explicit absence is reported as stopped.

Each action defaults to a 30-second timeout (package range: 0.1–3600 seconds).
Stdin is limited to 1 MiB; each output stream is checked against 1 MiB, with the
last 64 KiB shown. Limits are polled, so they are not hard disk quotas. Action logs
are deleted after completion. Cancellation terminates the directly owned process,
then kills it if needed. Utilities must stay in the foreground and manage any
children they create; the host does not promise arbitrary process-tree cleanup.

## Data and updates

The default store is `~/Library/Application Support/Dotfiles/Utilities`:

- `registry.json`: installed versions, enabled state, settings, shortcuts, and
  desired running services; mutations are locked and written atomically.
- `packages/<id>/<version>/`: installed package copies. Existing versions cannot
  be overwritten. Import a package with a new version to update it.
- `data/<id>/`: utility state and service logs. Removing a utility preserves this
  directory. Settings and shortcut registrations are removed with its registry entry.

The app and CLI share a cross-process lifecycle lease and durable activation
journal. Commands hold the same lease so update/remove cannot change their code
mid-run. Settings, shortcuts, services, enable/disable, update, rollback and remove
all use the same coordinator. Startup and `dotfiles-utility recover` restore an
interrupted uncommitted operation; a committed removal finishes cleanup. Recovery
failures retain the journal and block further mutations until recovery succeeds.
User-confirmed actions and shortcuts are revalidated after acquiring the lease.

The host stops owned services before an update, preserves compatible settings,
then restores desired services. Failed activation attempts restore the previous
package when available; recovery errors remain visible. **Restore previous
version** switches between retained versions. External side effects of a command
and utility-owned data migrations are not rolled back. There is no automatic
download/update feed yet.

LaunchAgents live in `~/Library/LaunchAgents/dev.dotfiles.utility.<hash>.plist`.
Only labels derived from the installed utility/service IDs are touched. Before
deleting the app, disable/remove its utilities and turn off **Open at login**;
deleting the `.app` alone does not remove registered services or saved data.

## Extension authors

See [EXTENSION_AUTHORING.md](EXTENSION_AUTHORING.md) for the executable contract,
Swift standard library, examples, validation, and package lifecycle.

## Validation and public release

```sh
make test-native          # XCTest host and extension contracts
make test                 # Every declared module suite + parent suites + XCTest
make release-check        # All suites, shortcut catalog, build, fresh-store bundle test
python3 tests/run_all_tests.py --list
python3 tests/run_all_tests.py --match markdown-clipboard
```

The runner streams output, enforces a per-suite timeout, and writes per-suite
logs, `results.json`, and `junit.xml` under `test-results/`. The checked-in CI workflow runs the native
build and existing integration contracts on macOS when published; a workflow file
alone does not establish a successful remote run. Shell fixtures, isolated
stores, and injected launchd responses do not establish real desktop acceptance.

The selected project license is Apache-2.0; [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
records separate dependency terms. Pandoc's complete corresponding-source review
remains an explicit acceptance requirement. The source assembly command
`python3 scripts/assemble-pandoc-source.py` supplies pinned source/build materials,
but the recorded upstream dependency closure is partial. Final release verification
rejects that known gap even if a human acceptance record is marked passed.

Public release gates are enforced by `make release-candidate-check` (clean,
Developer-ID-signed immutable candidate) and `make release-verify ACCEPTANCE=... SOURCE_MATERIALS=... ARM64_DIST=... INTEL_DIST=...`
(notarization, exact-commit remote CI, and recorded clean-device acceptance).
[release/ACCEPTANCE.md](release/ACCEPTANCE.md) describes the device protocol;
[release/support-matrix.json](release/support-matrix.json) inventories required
modules, packages, permissions, setup, update/rollback and uninstall evidence.
The signed-candidate workflow builds both architectures using protected secrets.
It does not publish a release.

Remaining external acceptance before a public stable release:

- Review third-party notices and full corresponding source for the bundled Pandoc binary.
- Publish the implementation on a clean commit, run both CI tiers, and require those checks on the release branch.
- Test all desktop and terminal utilities plus native UI, shortcuts, Login Items,
  real launchd recovery, denied permissions, consumer install/resume/update/rollback,
  and uninstall on clean Macs. Supply device records for each distributed architecture.
- Provide Developer ID and notarization credentials, sign the immutable candidate,
  and validate the downloaded notarized artifact before its tag and release publication.

Local fixtures and successful packaging do not satisfy these external gates.

Signing is available with `python3 scripts/build-app.py --sign 'Developer ID Application: …'`.
The explicit release script `scripts/notarize-app.sh` uses an existing Keychain
profile named by `DOTFILES_NOTARY_PROFILE`, staples the result, and regenerates
the archive/checksum. Credentials are never stored in the repository. Neither
notarization nor publication happens during `make build-app` or bootstrap.

[release/SIGNING.md](release/SIGNING.md) lists the protected signing secrets, local Keychain setup, and explicit candidate inputs; credentials can be provided after implementation review.
