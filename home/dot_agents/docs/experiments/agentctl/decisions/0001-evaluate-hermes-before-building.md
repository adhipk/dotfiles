# Decision 0001: Evaluate Hermes before building agentctl

Status: proposed  
Date: 2026-08-12

## Context

The original agentctl plan proposes a local, provider-neutral workflow layer
for durable objectives, dependency-aware workers, provider adapters, queued
suggestions, human gates, artifacts, decisions, and inspectable run state.

Hermes Agent v0.19.0 is already installed on this machine. Current Hermes
capabilities overlap much of that proposal:

- durable SQLite-backed Kanban boards with dependencies, comments, attempts,
  handoffs, named profiles, workspaces, and human intervention;
- dispatch of isolated workers and worktree-based engineering pipelines;
- per-profile and per-task model selection;
- gateway, CLI, dashboard, session, skill, memory, and event surfaces;
- an opt-in Codex app-server runtime that keeps Codex shell, patching,
  sandboxing, plugins, and subscription authentication beneath a Hermes shell.

The overlap makes a new orchestration runtime premature. Important gaps and
conflicts remain:

- Hermes is one agent harness with multiple model providers; it does not
  automatically preserve every native Claude Code, Codex, and OpenCode session
  contract envisioned by the plan.
- The managed `todo` wrapper is currently the canonical machine-wide task
  store, while Hermes Kanban has its own database and lifecycle.
- The Codex app-server integration is opt-in and still documents runtime-tool
  limitations.
- Hermes' security policy treats OS-level isolation as the meaningful security
  boundary. A dotfiles maintainer can otherwise reach sensitive home-state.

## Proposed decision

Use Hermes as the reference implementation and first pilot for the manager and
orchestration role. Keep Codex as the preferred coding executor through its
native app-server runtime when that path is appropriate.

Do not yet:

- change the configured default assistant from Codex to Hermes;
- initialize Hermes Kanban as a second production task source;
- install a new gateway service through dotfiles;
- retire the managed `todo` wrapper;
- begin a standalone agentctl runtime before completing a capability gap
  analysis and representative pilot.

Reframe agentctl's next phase from “build the proposed system” to “identify the
smallest missing layer after exercising Hermes.”

## Consequences

- The existing architecture plan remains valuable as a requirements and
  acceptance-contract document, not an approved implementation blueprint.
- A Hermes pilot can validate orchestration and user-experience assumptions
  without committing the dotfiles bootstrap to another service.
- Any durable adoption must choose one authoritative task ledger. A
  bidirectional `todo`/Kanban synchronization layer is explicitly rejected.
- Repository rules and reusable skills remain checked-in source. Hermes memory
  may supplement them but must not silently replace them.
- Write-capable workers should use repository/worktree isolation and explicit
  approval boundaries; applying dotfiles to the live home directory remains a
  separate action.

## Decision gates

Promote this proposal to accepted only after all of the following are answered:

1. Can a dedicated Hermes dotfiles-maintainer profile complete representative
   read-only, narrow-edit, dirty-worktree, test, and handoff tasks reliably?
2. Does the Codex app-server path preserve the editing, sandbox, plugin, and
   instruction behavior required by this repository?
3. Which system owns objectives, dependencies, attempts, completion, and
   handoffs: managed `todo`, Hermes Kanban, or a deliberately migrated facade?
4. Is native cross-harness execution still a real requirement after the pilot,
   or is model-provider portability inside Hermes sufficient?
5. Can Hermes configuration and profiles be managed without checking in
   credentials, runtime databases, memories, or transcripts?

## Sources

- `../plans/provider-agnostic-dynamic-workflows.md`
- <https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/kanban.md>
- <https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/codex-app-server-runtime.md>
- <https://github.com/NousResearch/hermes-agent/security>

