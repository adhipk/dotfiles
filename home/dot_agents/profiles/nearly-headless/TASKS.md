# Nearly Headless — Task List

Track implementation progress here. Update checkboxes as work lands in dotfiles.

## Phase 1 — Presentation layer (this PR)

- [x] `nearly-headless` agent profile (`profiles/nearly-headless/`)
- [x] HTML templates + shared CSS (`docs/templates/`)
- [x] `$html-artifact` skill
- [x] `$hyperspace-status` skill
- [x] `hyperclay-patterns.md` agent reference
- [x] `nearly-headless` CLI helper
- [x] `hyperspace-open-report` command

## Phase 2 — tmux runtime

- [ ] `sesh.toml` hyperspace session templates (`hs-<project>` windows)
- [ ] Extend `hyperspace` CLI: `agent start|focus|status`, `connect --switch`
- [ ] tmux hooks: `pane-died`, `alert-bell` → `notify.sh`
- [ ] `set -g exit-empty off` for agent sessions
- [ ] Enable experimental `hyperspace.skhdrc` bindings

## Phase 3 — Observability

- [ ] `hyperspace watch` — poll tmux, notify on state transitions
- [ ] Notification body includes `.hyperspace/<slug>.html` path
- [ ] `decision.html` + sidecar `decisions.json` for approval flow (optional)

## Phase 4 — Polish

- [ ] Raycast deeplink for hyperspace search
- [ ] `live-sync` on status dashboard (HyperClay SSE)
- [ ] Per-project `.hyperspace/` gitignore in chezmoi external template

## Done criteria

1. Agent in tmux writes `.hyperspace/status.html` using a template.
2. `hyperspace-open-report status` opens it in the browser.
3. Default `~/.agents/AGENTS.md` behavior is unchanged without profile activation.
