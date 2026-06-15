# Agent Comms

Project name: `agent-comms` (planned `adhipk/agent-comms`).

Agent-comms is a local communication layer for independent tools and repos. It
gives nearly-headless, provider runtimes, and local artifact generators (for
example gemma-gem) one shared event log without forcing them into the same
process.

## Owns

- Stream/event protocol (`conversation`, `session`, `run`, `artifact`, `system`)
- Command queue addressed to active sessions
- Read-model projections (transcripts, session status)
- SQLite persistence and SSE subscription (`/v1/subscribe`)
- Generic HTTP API on `127.0.0.1:43717` by default

## Does Not Own

- Nearly-headless task UI or provider-session orchestration
- Gemma-gem model inference or browser DOM tools
- Product-specific adapters (those live in consumer repos)

## Role in the stack

Coding agents (Codex, Claude) are **workers** — they stream progress but do not
maintain HTML artifacts. **nearly-headless** is the manager: centralized session
UI plus an agent that watches worker events and updates `.hyperspace/` dashboards
on milestones. agent-comms carries events between those processes when they are
not colocated.

ACP standardizes editor↔agent wire protocols; agent-comms is the local mesh
layer. They solve different problems and can coexist (ACP as a provider adapter,
agent-comms as cross-process fan-out).

## Consumers (planned)

| Consumer | Typical streams |
| --- | --- |
| **nearly-headless** | `session`, `run`, `artifact` — dispatch, heartbeats, manager updates |
| **gemma-gem** | optional local artifact generator; may publish or consume summaries |
| **provider adapters** | worker session events ingested into the bus |

Product-specific adapters should live in the consuming project repos. This
project keeps only generic protocol, storage, client, server, and wiring
examples.

## Prototype location

Source is **not in dotfiles**. Prototype checkout (gitignored):

```text
extensions/gemma-gem/agent-comms/
```

Run locally:

```bash
cd extensions/gemma-gem/agent-comms
deno task dev
```

Data defaults to `~/.local/share/agent-comms/agent-comms.sqlite3`.

Override with:

```bash
AGENT_COMMS_PORT=43717 AGENT_COMMS_DB=/path/to/agent-comms.sqlite3 deno task dev
```

## Extraction boundary

When extracted, agent-comms needs only:

- Deno server, client, protocol types, and store
- `schema.sql` and tests
- Generic examples (`browser-transcript-adapter.ts`, `session-worker.ts`)

It should not vendor gemma-gem, nearly-headless, or hyperspace code.

## Migration status

See `MIGRATION.md` and `EXTERNAL-PROJECTS.md` in the dotfiles repository.

Current external phase: **not started** — no remote, no `.chezmoidata.toml`
entry, no `home/bin/` shim.
