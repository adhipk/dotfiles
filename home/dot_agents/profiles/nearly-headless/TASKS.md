# Nearly-Headless — Task List

Track implementation progress here. Update checkboxes as work lands in dotfiles.

**Migration status:** `MIGRATION.md` in the dotfiles repository ·
**Extraction workflow:** `EXTERNAL-PROJECTS.md` in the dotfiles repository

Nearly-headless is the browser task workspace for provider-backed agents.
See `~/.agents/docs/nearly-headless.md`.

## Phase 1 — Presentation layer

- [x] `nearly-headless` agent profile (`profiles/nearly-headless/`)
- [x] HTML templates + shared CSS (`docs/templates/`)
- [x] `$html-artifact` skill
- [x] `$live-doc` skill
- [x] `hyperclay-patterns.md` agent reference
- [x] `nearly-headless` CLI shim
- [x] Compatibility aliases (`hyperspace-serve`, `hyperspace-open-report`, `headless-artifacts`)

## Phase 2 — Nearly-headless app core

Port **t3 patterns** into `hyperspace_server.mjs` — not the t3 repo. See
`~/.agents/docs/nearly-headless-port-plan.md`.

- [x] `nearly-headless serve` compatibility path through local artifact server
- [x] Live doc save → `hyperspace-run-live-doc` → `codex exec` (same file)
- [x] App can discover configured/current repos without tmux sessions
- [x] App-owned settings page scaffold

### Phase 2A — Event spine

- [x] `appendEvent()` writer (events.jsonl)
- [x] Task/run event types + projector → session snapshot
- [x] SSE `/api/events/stream`
- [x] Mock runner (`nearly-headless mock-run`, `POST /api/dev/mock-run`)
- [x] UI shows tasks in app shell sidebar

### Phase 2B — Codex runner

- [ ] `RunnerAdapter` + `codex app-server` (stdio JSON-RPC)
- [ ] Runtime ingest → orchestration events
- [ ] `POST /api/tasks/:id/runs` dispatch
- [ ] Provider session persistence

### Phase 2C — Manager + HTML dashboard

- [ ] Milestone → update `.hyperspace/status.html` from template (no worker HTML)
- [ ] Pending queue + multi-session view in app shell
- [ ] Provider-instance and model-selection settings

### Phase 2D — Interaction

- [ ] App-owned comments/actions outside agent-editable HTML
- [ ] Approval/user-input round-trip from shell or artifact controls
- [ ] Scoped agent writes for task/artifact surfaces (manager only)

## Phase 3 — Extraction to external repo

Per `EXTERNAL-PROJECTS.md` Phase 2 checklist:

- [x] Register `nearly-headless` in `home/.chezmoidata.toml`
- [x] Add `home/bin/executable_nearly-headless` shim
- [x] Move server/runtime from `home/dot_config/hyperspaces/` to external repo
- [x] Move HTML components and live-doc shell to external repo
- [x] Point config at `~/.config/nearly-headless/`
- [ ] Push remote and verify chezmoi clone on other machines

## Phase 4 — Polish

- [ ] Per-project `.hyperspace/` gitignore in chezmoi external template

## Dropped

- **Hyperspace tmux workspace manager** — removed; see `MIGRATION.md` § Dropped
- **`$hyperspace-status` skill** — removed with tmux manager

## Done criteria

1. User can create a nearly-headless task from the browser workspace.
2. Task dispatches to a provider session and streams progress.
3. Agent can request input by generating an interactive page surface.
4. `hyperspace-open-report status` opens a static artifact when needed.
5. Default `~/.agents/AGENTS.md` behavior is unchanged without profile activation.
