# Nearly-Headless — Task List

Track implementation progress here. Update checkboxes as work lands in dotfiles.

Nearly-headless is the browser task workspace for provider-backed agents.
Hyperspace is the separate tmux workspace manager. See
`~/.agents/docs/nearly-headless.md` and `~/.agents/docs/tmux-session-manager.md`.

## Phase 1 — Presentation layer (this PR)

- [x] `nearly-headless` agent profile (`profiles/nearly-headless/`)
- [x] HTML templates + shared CSS (`docs/templates/`)
- [x] `$html-artifact` skill
- [x] `$live-doc` skill
- [x] `hyperclay-patterns.md` agent reference
- [x] `nearly-headless` CLI helper
- [x] `hyperspace-open-report` command

## Phase 2 — Nearly-headless app core

- [x] `nearly-headless serve` compatibility path through local artifact server
- [x] Live doc save → `hyperspace-run-live-doc` → `codex exec` (same file)
- [x] App can discover configured/current repos without tmux sessions
- [x] App-owned settings page scaffold
- [ ] Provider-instance and model-selection settings
- [ ] Provider-session task backend based on T3 Code concepts
- [ ] Task creation, progress stream, and event log
- [ ] App-owned comments/actions outside agent-editable HTML
- [ ] Scoped agent writes for task/artifact surfaces
- [ ] Approval/user-input flow with interactive generated UI

## Hyperspace — tmux workspace manager

- [x] `sesh.toml` hyperspace session templates (`hs-<project>` windows)
- [x] Extend `hyperspace` CLI: `agent start|focus|status`, `connect --switch`
- [x] tmux hooks: `pane-died`, `alert-bell` → `notify.sh`
- [x] `set -g exit-empty off` for agent sessions
- [x] Enable hyperspace bindings in `home/dot_skhdrc`
- [x] Split tmux manager default path from HTML artifact server startup
- [ ] `hyperspace watch` — poll tmux, notify on state transitions
- [ ] Notification body includes project/window/status path

## Phase 4 — Polish

- [ ] Raycast deeplink for hyperspace search
- [ ] `live-sync` on status dashboard (HyperClay SSE)
- [ ] Per-project `.hyperspace/` gitignore in chezmoi external template

## Done criteria

1. User can create a nearly-headless task from the browser workspace.
2. Task dispatches to a provider session and streams progress.
3. Agent can request input by generating an interactive page surface.
4. `hyperspace-open-report status` opens a static artifact when needed.
3. Default `~/.agents/AGENTS.md` behavior is unchanged without profile activation.
