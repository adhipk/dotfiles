# Desktop notifications system context

The dotfiles notification contract is `desktop-notify TITLE MESSAGE`. Its
canonical implementation is `modules/notifications/bin/desktop-notify`; ChezMoi
installs it at `~/bin/desktop-notify` and at the compatibility path
`~/.config/skhd/notify.sh`.

## System effects and ownership

- The utility submits one local macOS Notification Center item. It does not
  make network requests, activate an application, or mutate Focus settings.
- `terminal-notifier` is preferred. The utility resolves it through `PATH`,
  `/opt/homebrew/bin`, or `/usr/local/bin`, so launch agents with a minimal
  environment still use the installed app bundle.
- The notification sender shown by macOS is Terminal Notifier with bundle ID
  `fr.julienxx.oss.terminal-notifier`. Notification authorization and alert
  style remain user-owned System Settings state.
- When Terminal Notifier is unavailable or fails, `/usr/bin/osascript` is the
  fallback. Its sender identity and permission entry are managed by macOS.
- Notifications are grouped by normalized title unless
  `DESKTOP_NOTIFY_GROUP` is set. A later item in the same group replaces the
  earlier item rather than growing an unbounded Notification Center history.
- `DESKTOP_NOTIFY_IGNORE_DND=1` is the default and asks Terminal Notifier to
  bypass Focus suppression. This is a delivery request, not a Focus-mode
  change. Set it to `0` for ordinary Focus behavior.
- The module owns no persistent or ephemeral state. Disabling it removes its
  two command paths, rendered configuration, and this document, without
  resetting notification permissions or removing already delivered items.

Managed defaults live under `modules.notifications` in the ChezMoi data and
are exposed as `notifications.backend`, `notifications.ignoreDnd`, and
`notifications.sound` through the module's `settings.yaml` contribution.
Request-scoped environment variables override the rendered TOML without
changing machine state.

## Consumers

App focus uses the compatibility adapter for presentation and zen-mode state
changes. Space bookmarks, floating-window preferences, and shortcut-guide
errors use the same adapter. Consumers may override their notification command
or suppress nonessential notices, but they do not implement a second macOS
backend.

## Diagnosis

Render and syntax-check the managed command:

```sh
chezmoi -S ~/dotfiles cat ~/bin/desktop-notify | bash -n
```

Exercise each backend explicitly:

```sh
DESKTOP_NOTIFY_BACKEND=terminal-notifier desktop-notify "Dotfiles" "Terminal Notifier path"
DESKTOP_NOTIFY_BACKEND=osascript desktop-notify "Dotfiles" "AppleScript fallback"
```

If Terminal Notifier accepts a request but no banner appears, inspect System
Settings under Notifications for Terminal Notifier and check active Focus
modes. `terminal-notifier -list ALL` confirms Notification Center receipt; a
successful list entry does not prove that a banner was visually presented.

## Change contract

Changes to delivery backends, sender identity, Focus bypass, sounds, grouping,
notification authorization, installed command paths, or notification-related
Homebrew packages are system-level notification changes. Update this document,
the module README, settings fragment, manifest dependencies, and focused tests
in the same change.
