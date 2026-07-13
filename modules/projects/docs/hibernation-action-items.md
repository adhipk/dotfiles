# Project Hibernation Action Items

Date: 2026-06-18

## Goal

Build a project/session hibernation layer for the dormant Projects module.
The feature should save the current workspace graph, remove it from primary
navigation, and allow restoring it later without closing windows.

## Core Model

- Treat projects as boxes of spaces.
- Allow projects to be nested inside a parent hibernation box.
- Treat a hibernated work block as a parent project/session, for example:
  `work.2026-06-18-0930`.
- Give entities UUIDs where useful. User-facing names can still exist as
  aliases.
- Key assumption: individual windows do not need to be referenced outside a
  project. User-facing operations are group operations over a project/session.

## Session Naming

- If hibernating from 8am to 5pm, auto-name the parent box:
  `work-dd-mm-yyyy` or a timestamped variant if needed.
- If hibernating from 5pm to 10pm, auto-name it:
  `not-work-dd-mm-yyyy` or a timestamped variant if needed.
- Outside those windows, use a neutral timestamped session name or accept an
  explicit name from the command.

## Hibernate Behavior

- Add a command such as `projects hibernate [name]`.
- Save the existing projects object as a key/value object under the new parent
  hibernation box.
- If no project structure exists, create one project box that contains all
  current non-Home windows/spaces, then save that inside the parent box.
- Clear active project controls after saving:
  - `Hyper+1..5` project slots should no longer point at the hibernated work.
  - `last_project` or equivalent context should no longer route Alt controls to
    the hibernated work.
  - `Alt+Shift+1..9` should remain scoped only to the active project/network.
- Leave windows and apps alive.
- Do not close windows.
- Do not quit apps in v1.
- Optionally hide apps using macOS hide behavior as a lightweight layout
  suspension mechanism, but treat that as best effort.
- Focus a dedicated Home/about:blank space after hibernating.

## Home Space

- Keep one blank Home space as the landing page.
- Home is not part of hibernated work.
- If Home does not exist, create or label one.
- Hibernation should end by focusing Home.

## Restore Behavior

- Add a command such as `projects restore-session <session|latest>`.
- Restore the saved project graph from the hibernation box.
- Re-enable the restored project's normal controls.
- Best-effort unhide apps that were hidden during hibernation.
- Restore should replace the current active project tree, but first auto-save
  the current tree as a safety snapshot to avoid destructive loss.

## ProjectDeck UX

- Normal ProjectDeck and Alt controls should hide hibernated sessions from
  primary actions.
- Add a way to list and restore hibernated sessions.
- Defer the keybinding choice until after the behavior is implemented.

## Explicit Non-Goals For V1

- No per-window user interface.
- No per-window restore command.
- No exact reconstruction of closed windows.
- No generic quit/reopen hibernation.
- No requirement to preserve Mission Control indices.
- No need to expose individual spaces as primary user-facing objects.

## Later Options

- Add a mode to move hibernated spaces to high Mission Control indices.
- Add app-specific deep hibernation adapters for apps that can restore state
  reliably.
- Add a keyboard shortcut for hibernate/restore after the command behavior is
  stable.
