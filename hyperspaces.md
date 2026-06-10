## Nearly-headless profile (implemented)

Presentation layer: `home/dot_agents/profiles/nearly-headless/` (HTML + HyperClay + skills).

Runtime layer (phase 2): `hyperspace` CLI in `home/bin/`, `~/.config/sesh/sesh.toml`,
`~/.config/hyperspaces/agents.json`, tmux hooks in `dot_tmux.conf`, skhd bindings in
`dot_skhdrc`. Phase 3 (`hyperspace watch`) — see `TASKS.md`.

---

Short answer: t3-code solves this by not treating windows/spaces as the primitive. It treats each assistant as a provider-backed session/thread with:

stable provider identity
command routing
lifecycle operations
canonical runtime events
persisted session bindings
projected read state
terminal/PTTY sessions as secondary runtime objects
For your hyperspaces idea, the reusable parts are mostly architecture patterns, not direct code.

How t3-code backend works
Backend flow is roughly:

UI / WebSocket request
  -> orchestration command
  -> ProviderCommandReactor
  -> ProviderService
  -> provider adapter
  -> provider-native runtime
  -> canonical ProviderRuntimeEvent
  -> ProviderRuntimeIngestion
  -> orchestration event
  -> projected read model
  -> WebSocket push to UI
Important pieces:

1. Provider instance registry
t3-code separates:

provider driver kind = codex / claude / opencode / cursor-ish protocol
provider instance id = user-configured routing key
That means it can support multiple instances of the same provider.

Relevant file:

packages/contracts/src/providerInstance.ts
apps/server/src/provider/Layers/ProviderInstanceRegistryLive.ts
For hyperspaces, this maps nicely to:

agent provider kind = codex / claude / cursor-agent / opencode
agent instance id = codex-main / claude-review / codex-cloud / claude-local
This is absolutely worth copying conceptually.

2. Provider adapter interface
t3-code has a normalized adapter API:

startSession()
sendTurn()
interruptTurn()
respondToRequest()
stopSession()
listSessions()
hasSession()
streamEvents()
Relevant file:

apps/server/src/provider/Services/ProviderAdapter.ts
This is one of the best pieces to reuse conceptually.

For hyperspaces, I’d simplify it to:

start
attach
sendInput
interrupt
stop
status
streamEvents
But instead of assuming chat turns, your adapter should assume CLI/runtime sessions.

Example:

CodexAdapter
ClaudeAdapter
CursorAgentAdapter
OpenCodeAdapter
ShellCommandAdapter
Each adapter knows how to launch and observe that tool inside tmux/Ghostty.

3. ProviderService as router
t3-code has ProviderService, which does not know Codex/Claude protocol details. It resolves the provider instance and routes calls to the right adapter.

Relevant file:

apps/server/src/provider/Layers/ProviderService.ts
For hyperspaces, the equivalent would be:

AgentService
It should answer:

hyperspace agent start dotfiles codex-main
hyperspace agent focus dotfiles codex-main
hyperspace agent stop dotfiles claude-review
Internally:

project id + agent id -> adapter -> tmux/window/process state
This is very reusable as a design.

4. Session directory
t3-code persists which provider owns a thread/session.

Relevant file:

apps/server/src/provider/Services/ProviderSessionDirectory.ts
It stores bindings like:

threadId
provider
providerInstanceId
status
resumeCursor
runtimePayload
For hyperspaces, you want the same idea, but mapped to projects and terminal/agent sessions:

{
  "projectId": "dotfiles",
  "agentId": "codex-main",
  "provider": "codex",
  "tmuxSession": "hs-dotfiles",
  "tmuxWindow": "codex-main",
  "ghosttyTitle": "hs:dotfiles:codex-main",
  "status": "running",
  "lastSeenAt": "..."
}
This may be the most directly useful backend concept.

5. Canonical runtime events
t3-code normalizes provider-specific events into a common vocabulary:

session.started
session.state.changed
session.exited
turn.started
turn.completed
content.delta
request.opened
request.resolved
task.started
task.completed
runtime.error
Relevant file:

packages/contracts/src/providerRuntime.ts
For hyperspaces, you do not need all of this. But you should copy the idea.

Your event vocabulary could be:

hyperspace.created
hyperspace.opened
agent.started
agent.output
agent.state.changed
agent.needs-input
agent.completed
agent.failed
terminal.opened
window.focused
daemon.started
daemon.exited
This is how coding CLI windows become first-class: they emit typed events instead of being anonymous terminals.

6. Orchestration engine
t3-code has a real command/event system:

command -> validate/decide -> append events -> project read model -> publish
Relevant files:

apps/server/src/orchestration/Layers/OrchestrationEngine.ts
apps/server/src/orchestration/decider.ts
apps/server/src/orchestration/projector.ts
This is powerful, but probably too much for your first implementation.

For hyperspaces, I’d start with:

JSON config + JSONL event log + status command
Not full event sourcing.

But the pattern is right:

intent command
  -> durable event
  -> current status projection
7. Terminal manager
This is the closest practical match to your “coding CLI windows as first-class citizens” idea.

t3-code models terminal sessions with:

threadId
terminalId
cwd
status
pid
history
output stream
exit code
activity label
subprocess detection
Relevant files:

packages/contracts/src/terminal.ts
apps/server/src/terminal/Services/Manager.ts
apps/server/src/terminal/Layers/Manager.ts
This part is very relevant.

But t3-code uses PTYs inside its app server. Your setup probably wants tmux/Ghostty/yabai instead.

So reuse the shape, not necessarily node-pty.

For you:

terminalId -> tmux window or Ghostty window
history -> tmux capture-pane / log file
status -> tmux pane process / child command
activity label -> codex / claude / npm / idle
What I would reuse
Reuse conceptually
Strong yes:

Provider kind vs provider instance id

codex is not enough.
You want codex-main, codex-review, claude-debug, etc.
Adapter interface

Each assistant gets a driver/adapter.
Hyperspace core should not know provider-specific launch details.
Session directory

Persist the mapping from project/agent to tmux/window/process.
Canonical events

Normalize Codex/Claude/Cursor/OpenCode into common local states.
Terminal session model

id, cwd, pid, status, history, activity, updatedAt.
Read model / status projection

hyperspace status should not scrape everything from scratch forever.
It can project from state/events and verify live runtime.
Maybe reuse practically
If you build this as a TypeScript local daemon, you could borrow ideas/code from:

packages/contracts/src/terminal.ts
apps/server/src/terminal/Services/Manager.ts
apps/server/src/provider/Services/ProviderAdapter.ts
packages/contracts/src/providerRuntime.ts
The repo is MIT licensed, so reuse is legally possible with attribution.

But practically, direct reuse is awkward because t3-code is tied to:

Effect
its contracts package
its web/mobile UI model
SQL/event persistence
provider SDKs
WebSocket transport
app-server assumptions
So I would not vendor big chunks unless you intentionally choose TypeScript + Effect.

What I would not reuse
I would avoid copying:

the full WebSocket server
the React/chat interaction model
the full orchestration engine
the SQL persistence stack
the entire provider runtime event schema
provider adapters as-is
thread/turn/message-centric assumptions
Because your project is not a chat app. Your core object is:

project-scoped local agent runtime
not:

chat thread
The adapted version for hyperspaces
I’d steal the shape and rename the concepts:

t3-code                     hyperspaces
------------------------------------------------
ProviderDriver              AgentDriver
ProviderInstance            AgentInstance
ProviderService             AgentService
ProviderSessionDirectory    AgentSessionDirectory
ProviderRuntimeEvent        AgentRuntimeEvent
Thread                      Hyperspace / Project
TerminalManager             Tmux/GhosttySessionManager
OrchestrationEngine         lightweight event log + projector

Possible backend modules:

HyperspaceRegistry
AgentInstanceRegistry
AgentSessionDirectory
AgentService
AgentAdapter
RuntimeEventLog
StatusProjector
TmuxAdapter
GhosttyAdapter
YabaiAdapter
SkhdEntrypoints
My recommendation
Use t3-code as proof that the right abstraction is not windows and not chat UI.

The reusable insight is:

assistants need stable instance identity, lifecycle APIs, event streams, and session bindings.

For your dotfiles, implement a smaller backend around tmux/Ghostty/yabai:

hyperspace agent start dotfiles codex-main
hyperspace agent focus dotfiles codex-main
hyperspace agent status dotfiles
hyperspace status
Under the hood:

project id
  -> agent instance id
  -> tmux session/window
  -> Ghostty/yabai presentation
  -> event/status state
That gives you the t3-code backend benefits without inheriting its chat-app complexity.

