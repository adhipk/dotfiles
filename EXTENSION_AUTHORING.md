# Author an executable utility

A utility is a directory, conventionally `<id>.dotutility`, containing
`extension.json` and optional executables/assets. Any language can implement it.
The host owns registration and UI; your executable owns the useful behavior.
No daemon or SDK dependency is required for a simple command.

## Start with an existing executable

Build the app, then scaffold and validate a package:

```sh
dist/Dotfiles.app/Contents/MacOS/dotfiles-utility new example.greeting /tmp/greeting.dotutility
dist/Dotfiles.app/Contents/MacOS/dotfiles-utility check /tmp/greeting.dotutility
```

The schema is documented by [extension.schema.json](schemas/extension.schema.json).
`check` is authoritative for filesystem-dependent checks. It never runs commands.

```json
{
  "schemaVersion": 1,
  "id": "example.greeting",
  "name": "Greeting",
  "version": "0.1.0",
  "summary": "A small utility with a user-editable greeting.",
  "settings": [
    {"key": "name", "title": "Name", "kind": "string", "defaultValue": "world"}
  ],
  "commands": [
    {
      "id": "hello",
      "title": "Say hello",
      "invocation": {"tool": "printf", "arguments": ["%s\n", "Hello, {setting:name}!"]}
    }
  ]
}
```

Use `"executable": "bin/greeting"` instead of `tool` to ship your own binary.
Exactly one is required. Executables must be executable regular files inside the
package. Symlinks, special files, absolute paths, and `..` traversal are rejected.
Packages are limited to 512 MiB and manifests to 256 KiB. Match the consumer's
CPU architecture and deployment target; the host does not translate binaries.

External `tool` names are resolved in Homebrew's standard prefixes, `~/bin`, and
system directories. Shell startup files are not sourced. Bundle your implementation
or document its independent installer; do not silently install packages from an
action. The included legacy adapters intentionally keep upstream ownership.

## Command contract

| Field | Meaning |
| --- | --- |
| `commands[].id`, `title` | Stable action identity and user-facing label |
| `invocation.arguments` | Literal argv entries, optional placeholders |
| `invocation.workingDirectory` | Absolute directory or supported placeholder; defaults to the user's home |
| `invocation.environment` | Explicit nonreserved environment overrides |
| `invocation.timeoutSeconds` | Action/health timeout, 30 seconds by default |
| `input: true` | Supply the app's Input field, or CLI stdin |
| `confirmation` | Text the app must display before running an explicit action |

Stdout is the action result; stderr is diagnostic output; nonzero exit status is
failure. The host applies no retries. Input/confirmed actions have no global
shortcut in this version. Action output is displayed after completion; continuous
progress streaming and interactive terminal actions are not yet part of the API.

Placeholders: `{setting:key}`, `{tool:name}`, `{package}`, `{data}`, `{home}`.
Substitution occurs once; settings containing placeholder-looking text remain
literal. Arguments are never interpreted by a shell. Do not pass untrusted text
into `sh -c` inside your own implementation and assume the host protects it.

The host supplies `DOTFILES_UTILITY_ID`, `DOTFILES_UTILITY_DATA`, and
`DOTFILES_UTILITY_SETTINGS` (a JSON object of string values), plus HOME, PATH,
LANG, and TMPDIR. An intentionally supplied `AGENT_TODO_DIR` is preserved.
Arbitrary parent credentials are not automatically forwarded. Settings support
`string`, `boolean`, `integer`, `choice`, and `directory`; defaults and saved
values are strings. Store credentials in the appropriate system/upstream store,
not ordinary settings.

## Persistent services

Add a `services` array with unique `id`, `title`, and `invocation` values.
An optional `health` invocation exits zero for success. Example:

```json
{
  "id": "watch",
  "title": "Watch for changes",
  "invocation": {"executable": "bin/worker", "arguments": ["watch"]},
  "health": {"executable": "bin/worker", "arguments": ["health"], "timeoutSeconds": 5}
}
```

The app writes an owned LaunchAgent; launchd owns the process. Stay in the
foreground, handle SIGTERM, close resources, and clean up your own children.
Invocation timeouts apply to commands/health probes, not persistent services.
Settings are loaded at process start; saving them restarts registered services.
Start occurs only on explicit user action (and future logins while registered).
The registration uses `KeepAlive: false` for the bundled service supervisor.
The supervisor drains and rotates logs while the app is closed and retries child
crashes at most three times (2/4/8-second backoff). Clean exits stop; exhausted
retries require an explicit restart or next login. Each stdout/stderr channel has
a 1 MiB active file and one 1 MiB backup. Filesystem, clipboard, and external application events
remain the utility's responsibility.

There are no arbitrary install/uninstall scripts. Importing validates and copies
files. Enabling registers available actions. Disable/remove stops owned services
and removes host registrations without executing an extension cleanup script.
Preserve user documents and externally owned service/configuration data.

## Swift standard library

The SwiftPM `ExtensionKit` library in `modules/dotfiles-control-center` provides:

- `UtilityContext`: typed settings dictionary, data directory, stderr logging,
  and atomic Codable state read/write.
- `ServiceHooks(onShutdown:)`: a once-only SIGTERM/SIGINT callback. Retain the
  hooks for your worker's lifetime and exit after your cleanup completes.
- Host-side manifest validation, package store, argument resolution, bounded
  command execution, and launchd registration shared by the app and CLI.

[examples/hello-utility](examples/hello-utility) is a separate Swift package that
imports the SDK. To package that example:

```sh
swift build --package-path examples/hello-utility -c release
mkdir -p /tmp/hello-sdk.dotutility/bin
cp examples/hello-utility/extension.json /tmp/hello-sdk.dotutility/extension.json
cp examples/hello-utility/.build/release/HelloUtility /tmp/hello-sdk.dotutility/bin/hello
dist/Dotfiles.app/Contents/MacOS/dotfiles-utility check /tmp/hello-sdk.dotutility
```

The SDK currently uses a repository path dependency in this example. A versioned
public SDK distribution awaits the first licensed/tagged release. The larger
[standard-library audit](EXTENSION_STDLIB_AUDIT.md) describes possible future hooks;
window events, terminal hooks, clipboard helpers, capability negotiation, and
resource reconciliation are not implemented APIs yet.

## Local test loop

Use a disposable registry to avoid touching your regular app inventory:

```sh
dist/Dotfiles.app/Contents/MacOS/dotfiles-utility --root /tmp/utility-dev install /tmp/greeting.dotutility
dist/Dotfiles.app/Contents/MacOS/dotfiles-utility --root /tmp/utility-dev enable example.greeting
dist/Dotfiles.app/Contents/MacOS/dotfiles-utility --root /tmp/utility-dev run example.greeting hello
dist/Dotfiles.app/Contents/MacOS/dotfiles-utility --root /tmp/utility-dev doctor
```

`--root` isolates package/settings storage, not the executable's effects or
macOS LaunchAgents. Use command-only fixtures or inject the service runner in
XCTest; do not treat it as a process sandbox. App and CLI mutations share a
cross-process lease and recovery journal, including service stop/resume during
updates and settings changes. Use `rollback ID`, `recover`, or
`service ID SERVICE start|stop|status|logs` from the CLI. The app refreshes external
registry changes, and rechecks each reviewed action and shortcut under the lease
before execution. Use `UtilityLifecycle` for host-side operations; direct low-level
`UtilityStore` methods do not coordinate service ownership.

Bump the package version for each new build. Test first install disabled,
dependency failure, exit errors, timeout/cancel, compatible settings on update,
rollback, service shutdown, and removal preserving data. The host tests live in
`modules/dotfiles-control-center/Tests/ExtensionKitTests`.
