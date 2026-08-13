# Session handoff: Hermes fit for dotfiles and agentctl

Date: 2026-08-12  
Repository: `/Users/adhipkashyap/dotfiles`

## Question

Would the dotfiles environment be better served by a Hermes agent, given the
experimental provider-neutral agentctl design?

## Outcome

The recommended shape is Hermes as a candidate manager/orchestrator with Codex
remaining the preferred coding executor, not a blind replacement of Codex with
the `hermes` command.

The existing agentctl plan substantially overlaps Hermes' current durable
orchestration features. The experiment should therefore evaluate Hermes first
and preserve agentctl only for requirements or adapter behavior that Hermes
does not satisfy.

No assistant preference, Hermes configuration, Kanban database, service,
bootstrap path, or live home configuration was changed during this assessment.

## Evidence collected

### Current dotfiles behavior

- `dotfiles-settings get assistant` returned `codex`.
- `modules/settings/registry.yaml` accepts arbitrary commands for the assistant
  preference and suggests `codex`, `claude`, and `opencode`.
- `modules/terminal-window-types/bin/tmux-session-template` reads that
  preference for the stable internal `codex` window type. The visible process
  can change without changing keyboard/window metadata.
- The repository already treats `~/.agents/tasks` through the managed `todo`
  wrapper as canonical durable task state.

### Current Hermes installation

- `hermes` resolved to `/Users/adhipkashyap/.local/bin/hermes`.
- The installed version reported `Hermes Agent v0.19.0 (2026.7.20)`, installed
  from Git at `~/.hermes/hermes-agent` and one upstream commit behind at the
  time of inspection.
- The CLI exposed profiles, projects, Kanban, skills, plugins, sessions,
  gateway, cron, MCP, ACP, dashboard, and server surfaces.
- Local and upstream documentation described durable Kanban workers and the
  optional Codex app-server runtime.

### Hermes strengths for this environment

- Much of the proposed task graph, worker lifecycle, handoff, retry, dashboard,
  and human-intervention work already exists.
- Named profiles are a natural home for a specialized dotfiles-maintainer
  identity.
- Codex can remain the actual editing runtime, avoiding an unnecessary choice
  between Hermes orchestration and Codex coding behavior.
- `AGENTS.md` is a portable repository contract that Hermes can consume; the
  dotfiles repository can remain the source of truth for behavior.

### Risks and mismatches

- Hermes Kanban and the existing managed `todo` ledger would be competing
  sources of truth unless one is explicitly subordinate or migrated away.
- Hermes provider portability is not identical to controlling independent
  native Codex, Claude Code, and OpenCode sessions.
- Some Hermes agent-loop tools are unavailable inside the Codex app-server
  runtime, even though Kanban worker reporting has a dedicated callback path.
- Hermes' default host terminal operates with the user's access. Dotfiles work
  therefore needs repository/worktree isolation and a separate explicit live
  apply step.
- Hermes is evolving quickly; every implementation decision must refresh the
  capability matrix rather than rely on this snapshot.

## Suggested pilot

Create an isolated `dotfiles-maintainer` profile without changing the default
assistant. Evaluate it on five representative tasks:

1. read-only repository and runtime tracing;
2. a narrow edit while unrelated worktree changes exist;
3. a change that must update source, bootstrap, and focused tests together;
4. a task requiring a durable handoff or human decision;
5. a task run through Codex app-server with workspace isolation.

Measure instruction compliance, unauthorized or unrelated writes, diff quality,
focused validation, task/handoff accuracy, interruption behavior, and ability
to resume after process or context loss.

## Resume checklist

- Read `../decisions/0001-evaluate-hermes-before-building.md`.
- Refresh `hermes version` and official feature documentation.
- Inspect current repository status and preserve unrelated changes.
- Keep the managed `todo` ledger canonical during the pilot.
- Do not run `dotfiles-settings set assistant hermes` as part of the pilot.
- Do not apply to `$HOME`, start the gateway, or create production Kanban state
  without an explicit user request.
- Record results as a new session note and update the decision status rather
  than rewriting historical evidence.

## Bundle outcome

The session was consolidated into
`home/dot_agents/docs/experiments/agentctl/`. The pre-existing architecture
plan was moved into `plans/`; the bundle now also has a boundary README and a
proposed decision record. No agentctl implementation code existed to move.

The active `agent-comms`, Hyperspace, nearly-headless, tmux, `todo`, Hermes,
Codex, Claude Code, and OpenCode implementations remain outside the folder as
shared or external dependencies. The parent has no executable integration with
the experiment.

Validation performed:

- focused token and stale-path searches found no agentctl references outside
  the bundle;
- all internal relative document links resolved after copying the folder to a
  temporary location;
- `git diff --check` passed;
- `./tests/test_source_state.sh` passed 551 checks with zero failures;
- the same 551 checks passed while the entire bundle was temporarily absent,
  proving that deleting it does not break the active dotfiles source state.
