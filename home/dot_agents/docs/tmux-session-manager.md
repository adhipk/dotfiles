# Hyperspace

Project name in this dotfiles repo: `hyperspace`.

Hyperspace is a tmux workspace manager for keeping the moving parts of a project
in one place: agent sessions, terminals, project editors, long-running panes,
and pinned keyboard navigation. It is a different product idea from
nearly-headless.

## Owns

- Project-to-tmux-session mapping: `project` -> `hs-<project>`
- Window lifecycle: start, focus, stop, status
- Pinned session slots for keyboard shortcuts
- Optional provider launch commands for Codex, Claude, shell, or other CLIs
- Runtime state for tmux sessions under `~/.local/state/hyperspaces/`
- Local workspace ergonomics: terminals/editors/agents grouped by project

## Does Not Own

- Nearly-headless task orchestration
- Browser interaction surfaces
- Provider-session backend ownership
- Comments, approvals, progress streams, or agent-generated UI widgets

## Commands

```bash
hyperspace                       # start/focus default project and window
hyperspace dotfiles codex-main
hyperspace open dotfiles          # create/open the tmux session only
hyperspace start dotfiles codex-main
hyperspace focus dotfiles codex-main
hyperspace stop dotfiles codex-main
hyperspace agent status dotfiles
hyperspace pin 1
hyperspace connect 1
hyperspace search
hyperspace status
hyperspace end dotfiles
```

## Nearly-Headless Boundary

This utility does not start, route, or configure nearly-headless. Nearly-headless
uses provider sessions, task state, progress streams, comments/actions, and
app-owned settings. Any future bridge should live outside both cores.

## Extraction Boundary

If this becomes its own repo, it needs only:

- the `hyperspace` CLI
- the tmux hooks and notify script
- optional skhd/Raycast bindings
- config/state schemas for projects, windows, pins, and events

It should not vendor the artifact server, live-doc components, HTML templates,
or agent profile.
