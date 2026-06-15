# Nearly-Headless — Port t3 Patterns (Not t3 Code)

Strategy: extend the **nearly-headless** app server (`~/.local/share/nearly-headless`)
with **t3code-shaped orchestration**, keep the **HTML-first shell and `.hyperspace/`
artifacts**, skip forking t3 or agent-comms until a second process is actually needed.

Reference: [t3code architecture](https://github.com/pingdotgg/t3code/blob/main/docs/architecture/overview.md).

## What you already have

| Piece | Location | Status |
| --- | --- | --- |
| HTTP app server | `~/.local/share/nearly-headless/src/server/` | Extracted |
| HTML shell + artifact sidebar | `hyperspace_live.js` / `.css` | Works |
| `.hyperspace/` static serve | `GET /:route/*` | Works |
| Settings + provider instance scaffold | `/settings/`, `settings.json` | Scaffold |
| Provider session registry | `provider-sessions.json` | Read-only store |
| Event log reader | `GET /api/events` | Read-only; **no writer yet** |
| Live-doc save → worker | `hyperspace-run-live-doc` → `codex exec` | Works (worker path) |

Legacy tmux discovery remains behind `HEADLESS_ARTIFACTS_ENABLE_LEGACY_TMUX=1`.
Default path is **provider-sessions only**.

## What to port from t3 (concepts only)

| t3 concept | Nearly-headless name | Notes |
| --- | --- | --- |
| Project | Project | Already: config + cwd discovery |
| Thread | **Task** | User-facing unit of work on a project |
| Turn | **Run** | One user message → worker completion |
| Orchestration command | **Intent** | `task.create`, `task.run.start`, … |
| Domain event | **Event** | Append-only facts; source of truth |
| Projection / read model | **Snapshot** | Session list, task status for UI |
| ProviderAdapter | **Runner adapter** | `codex app-server` first |
| ProviderRuntimeIngestion | **Runtime ingest** | Native events → domain events |
| ServerPushBus | **SSE push** | Simpler than WebSocket for v1 |
| CheckpointReactor | **Later** | Git snapshots optional in v2 |
| React chat UI | **Skip** | HTML shell + artifacts instead |

## Target architecture (one process)

```text
Browser
  │  HTTP (pages) + SSE (/api/events/stream)
  ▼
hyperspace_server.mjs  ── app shell, settings, static .hyperspace/
  │
  ├── orchestration/     commands → events → snapshot (SQLite or JSON)
  ├── runners/           ProviderAdapter: codex, claude, mock
  ├── manager/           milestone → patch status.html (templates first)
  └── persistence/       events.jsonl + provider-sessions + snapshots
         │
         ▼
   codex app-server (stdio JSON-RPC)   worker — no HTML
```

**Manager rule:** workers stream tool/text events; manager updates artifacts on
milestones (`run.completed`, `run.needs_input`, `session.idle`). Workers never
write `.hyperspace/` except via explicit user live-doc save (legacy path).

## Module layout (extract to `nearly-headless` repo later)

Start as siblings under `home/dot_config/hyperspaces/`; move when external repo
is ready.

```text
hyperspaces/
├── hyperspace_server.mjs      # thin HTTP router (keep)
├── orchestration/
│   ├── types.ts               # Task, Run, Event, SessionStatus
│   ├── store.ts               # append event, load snapshot
│   └── projector.ts           # events → session list + task rows
├── runners/
│   ├── adapter.ts             # RunnerAdapter interface
│   ├── codex-app-server.ts    # spawn + JSON-RPC + event stream
│   └── registry.ts            # instanceId → adapter
├── manager/
│   ├── milestones.ts          # which events trigger artifact updates
│   └── status-dashboard.ts    # fill templates/status-dashboard.html
└── api/
    └── routes.ts              # /api/tasks, /api/sessions, SSE
```

Plain TypeScript when extracted; **v0 can stay `.mjs`** with the same shapes.

## RunnerAdapter (minimal interface)

Port the **shape** from t3's `ProviderAdapter`, not Effect-TS:

```typescript
interface RunnerAdapter {
  readonly driver: "codex" | "claude" | "mock";

  startSession(input: {
    threadId: string;
    cwd: string;
    model?: string;
  }): Promise<{ providerSessionId: string }>;

  sendTurn(input: {
    threadId: string;
    text: string;
    attachments?: string[];
  }): Promise<{ runId: string }>;

  interruptTurn(threadId: string): Promise<void>;

  respondToApproval(input: {
    threadId: string;
    requestId: string;
    decision: "approve" | "reject";
  }): Promise<void>;

  /** Async iterable of normalized runtime events */
  streamEvents(): AsyncIterable<RuntimeEvent>;
}

type RuntimeEvent =
  | { type: "message.delta"; role: "assistant"; text: string }
  | { type: "tool.started"; name: string }
  | { type: "tool.completed"; name: string }
  | { type: "approval.requested"; requestId: string; summary: string }
  | { type: "run.completed"; stopReason: string }
  | { type: "run.failed"; error: string };
```

`Runtime ingest` maps `RuntimeEvent` → orchestration events and appends them.

## HTTP API (v1 additions)

Keep existing routes. Add:

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/api/sessions` | Already exists — extend payload with tasks |
| GET | `/api/projects/:id/tasks` | Task list + status for project |
| POST | `/api/projects/:id/tasks` | Create task → start or queue run |
| POST | `/api/tasks/:id/runs` | Send user message / steering |
| POST | `/api/tasks/:id/approvals/:reqId` | Approve/reject |
| GET | `/api/events/stream` | SSE: append events after `?after=` cursor |
| POST | `/api/events` | Internal: runtime ingest append (or in-process only) |

UI continues to load HTML from `/:route/status.html` etc.; JSON API feeds the
shell and manager.

## Manager + HTML artifacts

1. **App shell** (existing live page): session list, pending badges, task picker —
   driven by snapshot JSON, not chat transcript.
2. **Project dashboard** — one `.hyperspace/status.html` per repo, updated on:
   - `run.completed`
   - `run.needs_input` / `approval.requested`
   - `task.created`
3. **Task surfaces** — optional per-task HTML; manager patches sections, full
   regen only on create.
4. **Templates** — `~/.agents/docs/templates/status-dashboard.html`; manager
   fills placeholders from snapshot (no LLM in v0).

LLM manager (gemma-gem or small `codex exec`) is **v2**, only for narrative
summaries templates cannot express.

## Phased build (order matters)

### Phase A — Event spine (no provider yet)

- [ ] `appendEvent()` writer to `events.jsonl`
- [ ] Event types: `task.created`, `run.started`, `run.completed`, `session.heartbeat`
- [ ] `projector` → in-memory snapshot for `/api/sessions`
- [ ] SSE `/api/events/stream`
- [ ] Mock runner that emits fake events for UI dev

**Done when:** browser shows task list and status changing from mock events.

### Phase B — Codex runner

- [ ] `codex app-server` spawn + JSON-RPC (consider vendoring t3's wire types, not the server)
- [ ] Runtime ingest: app-server notifications → normalized events
- [ ] `POST /api/tasks/:id/runs` dispatches to adapter
- [ ] Persist `providerSessionId` in `provider-sessions.json`

**Done when:** create task from UI → Codex runs → events stream → snapshot updates.

### Phase C — Manager + dashboard

- [ ] Milestone handler calls `renderStatusDashboard(snapshot)`
- [ ] Write `.hyperspace/status.html` on milestones only
- [ ] Shell links to dashboard; pending queue from snapshot

**Done when:** you can manage multiple Codex sessions without reading raw stream.

### Phase D — Claude + polish

- [ ] Claude adapter (same interface)
- [ ] Approval / needs-input round-trip from HTML controls
- [ ] Settings UI for model selection (Phase 2 TASKS item)

### Phase E — Extract repo

- [ ] Move modules to `git@github.com:adhipk/nearly-headless.git`
- [ ] Shim stays in dotfiles

## Explicit non-goals (v1)

- Forking or embedding t3 server
- agent-comms separate process
- WebSocket (SSE is enough)
- Git checkpoint reactor (t3 parity not required)
- Workers generating HTML inline
- Chat transcript as primary UI

## t3 packages worth reading (not importing wholesale)

| Package | Use |
| --- | --- |
| `effect-codex-app-server` | Codex JSON-RPC types and spawn patterns |
| `packages/contracts` | Thread/turn/event naming reference |
| `ProviderRuntimeIngestion` | Ingestion flow reference |

MIT license allows copy-adapt of small pieces into nearly-headless with attribution.

## Success criteria (maps to TASKS.md)

1. Multiple provider sessions visible with task + status in app shell
2. Progress understandable without reading Codex stream
3. Pending / needs-input surfaced in shell and `status.html`
4. User steers via shell or artifact controls → structured prompt to worker
5. Workers never maintain artifacts; manager does on milestones
