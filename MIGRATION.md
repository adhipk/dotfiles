# Migration Status

Single source of truth for splitting dotfiles prototypes into external projects
and finishing the nearly-headless product extraction.

**Workflow:** [EXTERNAL-PROJECTS.md](EXTERNAL-PROJECTS.md) describes how to
register and extract a tool. **Product checklists** live in
[home/dot_agents/profiles/nearly-headless/TASKS.md](home/dot_agents/profiles/nearly-headless/TASKS.md).
**Future ideas** unrelated to extraction stay in [plan.md](plan.md).

## Phase vocabulary

Two independent phase systems — do not mix them:

| System | Phases | Document |
| --- | --- | --- |
| **Product build** | 1 presentation → 2 app core → 3 extraction → 4 polish | `TASKS.md` |
| **External repo** | 1 track separately → 2 extract implementation | `EXTERNAL-PROJECTS.md` |

## Project inventory

| Project | Remote | Dotfiles today | Product phase | External phase |
| --- | --- | --- | --- | --- |
| **nearly-headless** | `git@github.com:adhipk/nearly-headless.git` | Shim, profile, templates, skills; server still in `home/dot_config/hyperspaces/` | Phase 2 partial | Phase 2 in progress |
| **agent-comms** | planned `adhipk/agent-comms` | Prototype at `extensions/gemma-gem/agent-comms/` (gitignored) | pre-Phase 1 | Not started |
| **gemma-gem** | `https://github.com/kessler/gemma-gem.git` (fork planned) | Chrome external; local fork work under `extensions/gemma-gem/` | N/A | Phase 1 only |
| **raycast-lucide-excalidraw** | `git@github.com:adhipk/raycast-lucide-excalidraw.git` | External + dev shim | N/A | Extracted |
| **default-apps** | dotfiles `scripts/default-apps.sh` | Symlink from `~/bin` | N/A | Optional extract |

Update this table when a project crosses a phase boundary.

## Dropped: tmux / sesh workspace manager

The **hyperspace tmux workspace manager** (`hyperspace` CLI, `sesh`, session
pickers, hyper-key bindings, tmux hooks) was removed. Terminal multiplexing
added maintenance cost without enough value.

Removed from dotfiles:

- `hyperspace` CLI, `hyperspace-window-launch`, `tmux-sessionizer*`, `tmux-session-picker`
- `sesh` Brew dependency and `~/.config/sesh/sesh.toml`
- skhd hyper-key hyperspace bindings and `skhd/modules/hyperspace/`
- `$hyperspace-status` skill and `tmux-session-manager.md`
- tmux hooks targeting `~/.config/hyperspaces/notify.sh`

**Kept:** basic `tmux` config and aliases for optional manual use; nearly-headless
serve/live-doc stack (compatibility names like `hyperspace-serve` remain shims
into nearly-headless, not the old tmux manager).

Do not reintroduce sesh-based session management without an explicit decision.

## Nearly-headless

Browser task workspace: provider sessions, progress streams, HTML artifacts,
live-doc canvas, settings.

| Milestone | Status |
| --- | --- |
| Agent profile, templates, skills | Done |
| `nearly-headless` shim → external repo | Done |
| Compatibility aliases (`hyperspace-serve`, `headless-artifacts`, …) | Done |
| Live-doc save → `codex exec` | Done |
| Repo discovery without tmux | Done |
| Settings page scaffold | Done |
| Provider-session backend + model selection | Not started |
| Task streaming, comments, approvals | Not started |
| Move server/runtime out of `home/dot_config/hyperspaces/` | Not started |

**Boundary docs:** [nearly-headless.md](home/dot_agents/docs/nearly-headless.md),
[headless-html-artifacts.md](home/dot_agents/docs/headless-html-artifacts.md),
[nearly-headless-product.md](home/dot_agents/docs/nearly-headless-product.md).

**Legacy rename map** (during extraction):

| Dotfiles legacy | External target |
| --- | --- |
| `hyperspace_server.mjs`, `hyperspace-serve` | `nearly-headless serve` |
| `~/.config/hyperspaces/` (server/runtime) | `~/.config/nearly-headless/` |
| `hyperspace-open-report` | `nearly-headless open` |

Keep old command names as thin shims for one release cycle.

## Agent-comms

Local Deno + SQLite event bus for browser extensions, coding agents, artifact
workers, and CLI tools. Shared protocol — not owned by any one consumer.

| Milestone | Status |
| --- | --- |
| HTTP/SSE server, client, store, tests | Prototype in `extensions/gemma-gem/agent-comms/` |
| GitHub repo + `.chezmoidata.toml` entry | Not started |
| `home/bin/` shim | Not started |
| Integration with gemma-gem / nearly-headless | Not started |

**Boundary doc:** [agent-comms.md](home/dot_agents/docs/agent-comms.md).

Prototype checkout (gitignored):

```text
extensions/gemma-gem/agent-comms/   # nested repo, no remote yet
```

Runtime defaults: `127.0.0.1:43717`, data at
`~/.local/share/agent-comms/agent-comms.sqlite3`.

## Gemma-gem

On-device browser assistant (Chrome extension). Declared as a Chrome external
since the chezmoi migration (`20b0e4b`).

| Milestone | Status |
| --- | --- |
| Chezmoi clone + build to `~/.local/share/chrome-extensions/gemma-gem` | Done |
| Fork upstream (`kessler/gemma-gem`) to own remote | Not started |
| Point `.chezmoidata.toml` at fork | Not started |
| Wire extension to agent-comms | Not started |

Local prototype (gitignored, tracks upstream + local commits):

```text
extensions/gemma-gem/                 # fork work; includes agent-comms/ subdirectory
```

Chezmoi-managed checkout is upstream-only until the fork URL replaces the
declaration in `home/.chezmoidata.toml`.

## Chezmoi layout migration

The repository layout migration (`try to migrate`, Jun 2026) is **complete**.
Source state lives under `home/` via `.chezmoiroot`. Ongoing work is nearly-headless
extraction and optional agent-comms/gemma-gem follow-through.

## Related docs

| Doc | Purpose |
| --- | --- |
| [EXTERNAL-PROJECTS.md](EXTERNAL-PROJECTS.md) | Register, shim, extract workflow |
| [TASKS.md](home/dot_agents/profiles/nearly-headless/TASKS.md) | Product implementation checklist |
| [plan.md](plan.md) | Future ergonomics not tied to extraction |
| [COMMANDS.md](COMMANDS.md) | Installed shims and compatibility aliases |
| [README.md](README.md) | Bootstrap and repository layout |
