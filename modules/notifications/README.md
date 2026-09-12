# Notifications

This module owns the shared macOS desktop-notification utility. Its primary
entrypoint is `~/bin/desktop-notify TITLE MESSAGE`; the historical
`~/.config/skhd/notify.sh` path renders the same implementation so app-focus,
space-display, window-layout, shortcut-guide, and dormant project helpers keep
working without owning notification delivery themselves.

## Reliability fix

The previous loose helper used an invalid AppleScript expression in its
fallback. Any caller whose `PATH` did not expose Homebrew's
`terminal-notifier` therefore lost the notification. The module now discovers
the Homebrew command at its stable Apple Silicon and Intel paths and uses a
small, valid AppleScript fallback. Multiline bodies are normalized before the
fallback is invoked.

Use `dotfiles-settings set notifications.backend VALUE`,
`notifications.ignoreDnd`, and `notifications.sound` to manage delivery. The
rendered configuration lives at `~/.config/notifications/config.toml`.
`DESKTOP_NOTIFY_BACKEND`, `DESKTOP_NOTIFY_SOUND`, and
`DESKTOP_NOTIFY_IGNORE_DND` remain request-scoped overrides, while
`DESKTOP_NOTIFY_GROUP` changes replacement grouping.

## Boundary

The module owns the implementation, configuration adapter, settings fragment,
both installed command adapters, focused tests, and the shared agent context installed at
`~/.agents/docs/system/notifications.md`. Consumers own only the decision to
send a notice and its title/body. They must treat delivery as best-effort when
notification feedback is not their primary operation.

The manifest also contributes `Test desktop notification` to the shared
dotfiles-manager Utilities view. The action invokes the same
`~/bin/desktop-notify` entrypoint as every other consumer; the UI does not carry
a notification-specific implementation.

Disabling `modules.notifications.enabled` removes the commands, rendered
configuration, and shared context document. It does not alter Notification
Center authorization, Focus settings, or delivered-notification history.

Validate from the repository root:

```sh
modules/notifications/tests/test_module.sh
chezmoi -S "$PWD" cat ~/bin/desktop-notify
chezmoi -S "$PWD" cat ~/.agents/docs/system/notifications.md
```
