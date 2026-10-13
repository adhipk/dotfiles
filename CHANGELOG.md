# Changelog

## 1.0.0-dev.2 — unreleased

- Add launchd-owned finite crash recovery and bounded rotating service logs.
- Share app/CLI lifecycle leases and durable recovery journals; protect action approvals and shortcuts from concurrent changes.
- Add the consumer desktop profile with public HTTPS pins, explicit optional agent/work-app selection, dependency guidance and resumable setup.
- Bundle checksum-pinned Pandoc for Markdown Clipboard with upstream notices.
- Select Apache-2.0 for original project code; enforce third-party source/license review before release.
- Add clean signed candidate, notarization and exact-commit CI/clean-device acceptance gates covering all enabled desktop and terminal modules.


## 1.0.0-dev.1 — unreleased

- Add a standalone native macOS app for importing executable utility packages,
  enabling actions, editing typed settings, assigning shortcuts, and managing
  owned launchd services.
- Add an executable manifest, versioned package store, previous-version rollback,
  command runner with timeout/cancellation, author CLI, and Swift standard library.
- Include ten example/integration packages; most integrations still require
  existing tools and personal configuration. Bundle the Markdown clipboard worker.
- Build the app independently of personal bootstrap, with version/checksum/build
  metadata and explicit Developer ID signing/notarization commands.
- Discover regression suites from module manifests, preserve parent integration
  checks, stream logs, enforce timeouts, and emit JSON/JUnit results. Add macOS CI.

This is a development candidate, not a supported public release. See
[NATIVE_APP.md](NATIVE_APP.md) for behavior, migration limits, and remaining gates.
No automatic conversion or removal of an existing personal installation occurs.
