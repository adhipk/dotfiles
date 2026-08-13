# agentctl experiment bundle

Status: experimental; no installed command or runtime implementation

`agentctl` is the placeholder name for an experiment in provider-neutral,
durable agent orchestration. This folder is the complete source boundary for
the experiment. It collects its plans, decisions, session notes, and any future
implementation so the work can be reviewed, copied, archived, or removed as a
unit.

## Contents

- `plans/provider-agnostic-dynamic-workflows.md` — the original architecture
  and phased implementation plan.
- `decisions/0001-evaluate-hermes-before-building.md` — the current proposed
  direction after comparing the plan with Hermes Agent v0.19.
- `session-notes/2026-08-12-hermes-fit-assessment.md` — reusable evidence and
  handoff from the session that produced the Hermes recommendation.

There is no agentctl source code, package manifest, test suite, generated data,
or installed command yet. When implementation begins, its source, schemas,
fixtures, tests, and local documentation belong inside this folder unless an
explicit parent adapter is required.

## Boundary

| Class | Material | Ownership rule |
| --- | --- | --- |
| Owned | Plans, agentctl decisions, experiment notes, and future implementation | Keep inside this folder. |
| Shared | `todo`, tmux hub, Hyperspace, nearly-headless, and the live agent documentation library | Reference through documented interfaces; do not copy their implementations here. |
| External | Hermes Agent, Codex, Claude Code, OpenCode, MCP, and provider APIs | Treat as versioned runtime dependencies or adapter targets. |
| Parent integration | None currently | Add only a narrow, removable registration or command bridge after the experiment is promoted. |

The dotfiles parent does not import, execute, install, or bootstrap anything
from this folder. Deleting it therefore removes only the experimental design
record and does not affect the active environment.

## Experiment rules

1. Keep `agentctl` a placeholder name until a naming decision is recorded.
2. Do not add bootstrap, login, daemon, tmux, or default-assistant wiring during
   a contract spike.
3. Do not create a second authoritative task ledger. Any use of Hermes Kanban
   alongside the managed `todo` wrapper requires an explicit ownership and
   migration decision first.
4. Prefer provider-native execution beneath portable task and capability
   contracts. Record any behavior lost through an adapter.
5. Begin with read-only, inspectable workflows. Require a separate decision
   before allowing concurrent repository writes.
6. Keep secrets, credentials, provider state, transcripts, task databases, and
   generated workspaces outside this bundle.
7. Re-check current provider and Hermes capabilities before implementation;
   the research snapshot in this bundle can become stale.

## Resume here

1. Read the current decision record.
2. Refresh `hermes version` and the Hermes Kanban and Codex app-server
   capability documentation.
3. Turn the original architecture plan into a gap matrix: Hermes provides,
   Hermes can be extended, or agentctl still needs to own.
4. Run an isolated, read-only Hermes pilot against representative dotfiles
   tasks without changing the default assistant or canonical task store.
5. Decide whether to integrate Hermes, build a smaller adapter, or continue the
   standalone runtime before writing implementation code.

