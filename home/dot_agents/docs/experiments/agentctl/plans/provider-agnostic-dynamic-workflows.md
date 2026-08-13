# Provider-Agnostic Dynamic Agent Workflows

Status: proposed architecture and implementation plan  
Date: 2026-08-11  
Audience: the user, coding agents, and implementers of the local agent stack  
Working CLI name: `agentctl` (placeholder, not a naming decision)

Bundle note: this is the original requirements and architecture plan. It is not
an approved implementation blueprint. Read
`../decisions/0001-evaluate-hermes-before-building.md` before starting work; the
current proposal is to evaluate Hermes as the reference orchestrator and build
only the remaining gaps.

## Executive summary

The current local agent environment already has several useful pieces:

- Codex, Claude Code, and OpenCode manage their own conversations, permissions,
  context windows, and child agents.
- The machine-wide `todo` wrapper provides durable tasks and handoffs.
- tmux and the session-manager dashboard expose active terminal work.
- Hyperspace and nearly-headless define a durable artifact and manager-agent
  experience.
- `agent-comms` is planned as a local event log and command queue between
  otherwise independent processes.

What is missing is a provider-neutral layer that can turn one objective into a
dynamic, inspectable workflow of specialized agents without making any one
provider the permanent owner of the workflow.

Claude Code's dynamic workflows demonstrate the desired interaction: an agent
writes a workflow script for the current task, a restricted runtime executes
that script, the script creates specialized workers as results become
available, and the main conversation remains responsive. The useful idea is not
Claude-specific JavaScript or Claude-specific subagent configuration. The
useful idea is that an agent can create an executable orchestration plan at
runtime.

This plan proposes a local, terminal-first workflow runtime with:

- a provider-neutral workflow API;
- capability-based, dynamically generated worker specifications;
- adapters for Codex, Claude Code, and later OpenCode;
- provider-native execution and session continuity underneath the adapters;
- durable task, event, suggestion, decision, and artifact references;
- stage checkpoints at which queued user suggestions can be incorporated;
- explicit human gates and a quiet, consolidated attention queue;
- a terminal CLI and tmux/Neovim read model as the primary interface.

The system should augment provider-native session management, not replace it.
Providers continue to own model invocation, context, tools, permissions,
transcripts, and low-level session resumption. The new runtime owns only the
portable workflow, cross-provider routing, durable project state, and human
attention contract.

## Why this is needed

### Provider sessions are necessary but insufficient

Codex and Claude already manage sessions and subagents. Reimplementing those
facilities would create a fragile compatibility layer and lose native features
such as provider-specific context management, permission handling, tool
integration, and transcript resumption.

However, provider sessions answer a narrower question:

> What is this agent conversation doing?

They do not provide a durable, provider-neutral answer to:

> What outcome are we pursuing, what decisions have been made, which work is
> ready, and where is human input genuinely required?

A provider session can disappear, be compacted, be replaced by a different
provider, or contain several unrelated turns. A project task and its decisions
must survive all of those changes.

### The current todo layer is carrying too many future responsibilities

The machine-wide todo implementation is currently the canonical task source of
truth. It is useful for stable IDs, repository targeting, statuses, dependencies,
and durable handoffs. It should remain supported during the migration.

It should not gradually become responsible for:

- launching and supervising provider sessions;
- storing provider transcripts;
- interpreting streaming events;
- generating dynamic agent configurations;
- maintaining specifications and decisions;
- deciding notification urgency;
- implementing a workflow-language runtime.

Those responsibilities require different data and lifecycle contracts. Keeping
them behind explicit interfaces prevents the task store from becoming an
accidental orchestration engine.

### Chat history is not durable project knowledge

Important decisions currently emerge in conversation but may remain only in a
provider transcript or final response. This creates several failure modes:

- a later agent cannot reliably discover why an approach was chosen;
- a compacted conversation can preserve the conclusion but lose its evidence;
- implementation can drift from a previously accepted constraint;
- task status and documentation can disagree;
- changing providers means manually reconstructing context;
- the user must repeatedly explain the same decision.

The system needs a controlled promotion path from conversational input to
durable artifacts. The transcript remains evidence, but it is not the project
record.

### The user's conversational style needs an asynchronous inbox

The user naturally adds requirements, constraints, and ideas while an agent is
working. An ordinary chat interface treats each new message as immediate
steering. That can restart reasoning, interrupt a coherent implementation
unit, or cause the agent to respond before it has finished higher-value work.

The desired behavior is closer to a human collaborator:

1. acknowledge receipt without stopping;
2. attach the suggestion to the active objective;
3. continue the current coherent unit of work;
4. review accumulated input at the next safe checkpoint;
5. integrate, defer, split, reject, or escalate each item;
6. update the durable task and decision record;
7. interrupt the user only when progress truly depends on a decision.

This requires a mailbox distinct from the active provider prompt.

### Cross-provider workflows need a common contract

Claude, Codex, and OpenCode expose different:

- agent-definition formats;
- model names and effort controls;
- permission and sandbox models;
- tool names;
- background execution behavior;
- session and child-agent identifiers;
- event and transcript formats;
- steering and resumption capabilities.

A portable workflow cannot embed those details directly. It must describe the
worker's objective and required capabilities, then let a provider adapter
compile that description into the strongest supported native form.

## Product vision

From any terminal, the user should be able to start an objective with any
supported coordinator:

```text
agentctl start "Replace the authentication layer without changing API behavior"
```

The coordinator may dynamically propose and run a workflow such as:

```text
discover current behavior
  -> parallel architecture and security analysis
  -> synthesize implementation plan
  -> checkpoint and consume queued suggestions
  -> parallel isolated implementation tasks
  -> test and adversarial review
  -> update decisions and final artifact
```

The user should be able to continue adding ideas without derailing it:

```text
agentctl suggest "Account for offline development environments"
agentctl suggest "Prefer existing utilities over another daemon"
```

The primary status view should emphasize attention rather than transcript
volume:

```text
WORK  auth-migration     3 workers      2 queued suggestions
WAIT  release-check      needs decision: migration window
DONE  flaky-test-audit   report ready
ERR   docs-verifier      retry available
```

At completion, another agent should be able to understand the work without
reading every conversation:

- the objective and accepted scope;
- the resolved workflow and agent roles;
- the task graph and handoffs;
- the suggestions received and their dispositions;
- decisions with rationale and evidence;
- artifacts produced;
- validation performed;
- unresolved risks and next work.

## Goals

### Primary goals

1. **Dynamic orchestration**: allow a coordinator to create a task-specific
   workflow and specialized worker configurations at runtime.
2. **Provider neutrality**: allow coordinators and workers to use different
   providers without changing the workflow's semantic contract.
3. **Native execution**: retain each provider's session, permission, tool, and
   context-management strengths.
4. **Durable project state**: keep objectives, tasks, dependencies, gates,
   suggestions, decisions, and artifacts outside provider transcripts.
5. **Non-interrupting input**: queue ordinary user additions and consume them at
   declared safe checkpoints.
6. **Focused attention**: notify the user only for decisions, approvals,
   failures, or requested reviews that actually need attention.
7. **Terminal-first operation**: make every important workflow available from
   a scriptable CLI with stable JSON output.
8. **Inspectability**: retain the generated workflow, resolved worker specs,
   provider mapping, events, results, and artifact provenance for every run.
9. **Incremental adoption**: work with the existing todo wrapper, tmux hub,
   Hyperspace artifacts, and provider CLIs before replacing any component.

### Secondary goals

- Allow reusable successful workflows to be promoted from one-off generated
  scripts into reviewed project or user templates.
- Route cheap, bounded work to faster models without hard-coding model names in
  workflow definitions.
- Support cross-repository objectives and isolated worktrees.
- Make the workflow state understandable to both humans and future agents.
- Expose enough structured data for a richer nearly-headless UI without making
  that UI necessary for operation.

## Non-goals

The first implementation will not:

- replace Codex, Claude, or OpenCode session management;
- create a universal transcript format containing every provider detail;
- guarantee identical behavior across providers;
- build another terminal multiplexer;
- replace tmux's role as the terminal process surface;
- require a hosted SaaS control plane;
- require agents to maintain UI HTML while performing coding work;
- let model-generated workflow code access the filesystem, shell, or network
  directly;
- automatically accept changes to project scope merely because the user
  mentioned them;
- make every piece of conversational text a permanent artifact;
- replace the canonical todo backend before an alternative has been proven
  against real workflows;
- solve billing or organization-wide quota management in the first release.

## Design principles

### Providers execute; the workflow layer coordinates

Provider adapters should launch or address native provider sessions. They must
not emulate model context, tool execution, or provider permission prompts.

### Describe capabilities, not provider tools

Workflows request `repository.read`, `repository.write`, `tests.run`, or
`web.search`. They do not request Claude's `Read` tool or a particular Codex
sandbox flag. Adapters translate capabilities into provider-specific settings.

### Parent authority is an upper bound

A child worker may receive fewer capabilities than its coordinator, but it may
never gain capabilities the parent run did not possess. Generated workflow code
cannot widen permissions.

### Durable state is explicit

Task state, decisions, artifacts, gates, and suggestion dispositions are
written deliberately. A manager may derive status views from events, but a UI
projection is not the only copy of project knowledge.

### Ordinary additions do not interrupt

New user input defaults to queued suggestion semantics. Immediate steering must
be explicit, for example through `agentctl now` or `agentctl interrupt`.

### Checkpoints are semantic boundaries

Input should be consumed after a coherent stage, before an expensive or
irreversible stage, or when the workflow can no longer make meaningful
progress. A timer alone is not a useful checkpoint.

### Generated orchestration is code under policy

The workflow is inspectable, hashable, replayable, and constrained. It is not a
privileged escape hatch for arbitrary generated code.

### Terminal output is an API

Every read operation should support stable JSON. Human-friendly terminal views
are projections over the same data, not separate scraping-only interfaces.

## Relationship to the existing architecture

### Provider runtimes

Codex, Claude Code, and OpenCode remain worker runtimes. They own:

- authentication and model access;
- native conversations and context windows;
- provider tools and MCP clients;
- permission prompts and sandbox implementation;
- provider-native subagents, forks, and transcripts;
- native session continuation and termination.

### `agent-comms`

`agent-comms` remains the generic cross-process communication layer. It owns:

- the append-only local event protocol;
- the command queue addressed to active sessions;
- session and run projections;
- SQLite persistence;
- SSE subscriptions for live consumers.

It does not decide which worker to spawn next or interpret project policy. The
workflow runtime publishes events to it and consumes commands from it.

### Nearly-headless and Hyperspace

Nearly-headless remains the manager surface. It owns:

- provider and session selection;
- centralized operational views;
- the manager agent;
- project and task artifact presentation;
- structured user comments and generated input surfaces;
- routing a user's response to the relevant gate or workflow.

Hyperspace HTML is the rich output and interaction plane. Markdown or structured
records remain appropriate for specifications, decisions, handoffs, and other
knowledge that agents must diff and load directly. HTML can render those records
without becoming their only canonical representation.

### Machine-wide todo wrapper

The existing `todo` command remains the initial task backend. The workflow
runtime talks to it through a `TaskStore` interface rather than parsing
`todo.txt` or invoking Tuxedo directly.

This preserves the current source of truth while allowing a future evaluation
of Beads or another dependency-aware store. A backend migration must preserve
stable task identity, repository scope, dependency edges, statuses, handoffs,
and auditability.

### Dotfiles

The reusable implementation should live in an independently owned project under
`~/projects`, consistent with external utility ownership. This dotfiles
repository should eventually own only:

- the pinned project manifest;
- conditional `~/bin` links;
- shared agent instructions;
- provider configuration bridges;
- tmux/Neovim integration;
- bootstrap and lifecycle integration tests.

The architecture plan lives here because it defines machine-level agent
behavior. The future runtime implementation should not be copied into dotfiles.

## Proposed architecture

```text
                                  durable knowledge
                             +--------------------------+
                             | specs / decisions / ADRs |
                             | task handoffs / reports  |
                             +------------^-------------+
                                          |
                                          | publish/update
                                          |
+-------------+    portable tools    +----+------------------+
| coordinator |--------------------->| dynamic workflow       |
| Claude      |  MCP or agentctl     | runtime                |
| Codex       |<---------------------|                        |
| OpenCode    |    status/results    | workflow + gate policy |
+-------------+                      +----+---------+---------+
                                            |         |
                                  TaskStore |         | events/commands
                                            v         v
                                    +-------+--+  +---+---------+
                                    | todo now |  | agent-comms |
                                    | Beads?   |  | local bus   |
                                    +----------+  +---+---------+
                                                        |
                                                        v
                                              +---------+---------+
                                              | tmux / Neovim /   |
                                              | nearly-headless   |
                                              | attention views   |
                                              +-------------------+

                 provider adapters
          +--------------------------------+
          | capability and lifecycle ports |
          +-------+-------------+----------+
                  |             |
                  v             v
             +----+----+   +----+-----+       +----------+
             | Codex   |   | Claude   | later | OpenCode |
             | native  |   | native   |       | native   |
             +---------+   +----------+       +----------+
```

## Core domain model

### Objective

A durable statement of the outcome the user wants. It is broader than a
provider turn and narrower than an indefinitely maintained project.

Required fields:

```yaml
id: obj-uuid
title: Replace authentication implementation
repo_roots:
  - /absolute/path/to/repo
status: active
created_at: 2026-08-11T12:00:00-07:00
task_backend_ref: todo:uuid
artifact_refs: []
```

### Workflow definition

The inspectable orchestration generated for an objective. It contains metadata,
policy declarations, and a restricted script body.

```javascript
export const meta = {
  name: "auth-migration",
  description: "Understand, change, and verify the auth implementation",
  version: 1,
};

export default workflow(async ({ agent, parallel, checkpoint, artifact }) => {
  const evidence = await parallel([
    agent({ role: "explorer", objective: "Trace current auth behavior" }),
    agent({ role: "reviewer", objective: "Identify security invariants" }),
  ]);

  const plan = await agent({
    role: "planner",
    inputs: evidence,
    objective: "Create a minimal migration plan",
  });

  await checkpoint("plan-ready", { inputs: [plan], consumeSuggestions: true });

  const implementation = await agent({
    role: "implementer",
    inputs: [plan],
    capabilities: ["repository.read", "repository.write", "tests.run"],
    isolation: "worktree",
  });

  return artifact("implementation-report", implementation);
});
```

The syntax above is illustrative. The first spike must validate whether a
restricted JavaScript authoring surface or a structured workflow IR is safer
and easier to operate. Regardless of syntax, the runtime semantics below are
the contract.

### Agent specification

Every `agent()` call resolves to an immutable `AgentSpec` stored with the run:

```yaml
id: agent-uuid
workflow_run_id: run-uuid
role: security-reviewer
objective: Review the proposed authentication change for regressions
provider: auto
model_class: deep
reasoning_class: high
capabilities:
  - repository.read
  - tests.run
workspace:
  roots:
    - /absolute/path/to/repo
  isolation: read-only
inputs:
  - artifact: plan-uuid
output:
  schema: security-findings/v1
budget:
  wall_time_seconds: 900
  max_attempts: 2
dependencies:
  - agent-plan-uuid
```

The resolved record additionally contains:

- selected provider and model;
- provider session and child-agent identifiers;
- actual granted capabilities;
- adapter version;
- start and end timestamps;
- result and transcript references;
- exit reason and validation state.

### Capability profile

Capabilities form a small provider-neutral vocabulary:

```text
repository.read
repository.write
shell.readonly
shell.execute
tests.run
web.search
browser.control
network.fetch
task.read
task.write
artifact.read
artifact.write
workflow.spawn
human.request
```

Capabilities should be coarse enough to translate reliably and narrow enough
to enforce meaningful policy. Provider-specific tools may be exposed through an
extension namespace, but portable workflows must not require extensions unless
they explicitly declare the provider constraint.

### Model class

Portable workflows request behavior rather than exact provider model IDs:

```text
fast       narrow, cheap, high-volume work
balanced   routine implementation and analysis
deep       ambiguous or high-risk reasoning
inherit    coordinator's default policy
```

The local provider policy maps those classes to currently available models.
Exact model IDs remain valid as an explicit provider-specific override, but
such a workflow is no longer fully portable and must say so.

### Workflow run

A workflow definition may have many runs. The run owns:

- the exact script or IR and its digest;
- input arguments and objective revision;
- resolved policy and budgets;
- dynamic agent graph;
- checkpoint snapshots;
- queued suggestion cursor;
- provider session references;
- events and result artifacts;
- completion or failure reason.

### Suggestion

A suggestion is durable user input that has not yet changed accepted scope:

```yaml
id: suggestion-uuid
objective_id: obj-uuid
workflow_run_id: run-uuid
text: Prefer the existing credential helper
created_at: 2026-08-11T12:10:00-07:00
urgency: normal
status: queued
disposition: null
```

Allowed dispositions:

```text
integrated       changed the current workflow or artifact
deferred         valid but intentionally postponed
split            became a distinct task
decision-needed  requires user choice
rejected         conflicts with accepted constraints, with rationale
duplicate        already represented elsewhere
superseded       replaced by later input
```

Every disposition records the responsible agent, timestamp, explanation, and
links to resulting tasks, decisions, or workflow revisions.

### Human gate

A gate represents work that cannot proceed without a person:

```yaml
id: gate-uuid
workflow_run_id: run-uuid
blocks:
  - agent-deploy-uuid
kind: decision
question: Which migration window should be used?
context_artifact: decision-brief-uuid
status: open
notification_state: delivered
```

Gates are distinct from ordinary suggestions and provider permission prompts.
They are durable project dependencies, not merely UI notifications.

### Artifact and decision

Artifacts use stable IDs and explicit provenance:

```yaml
id: artifact-uuid
kind: decision
path: docs/decisions/0007-auth-token-storage.md
objective_id: obj-uuid
producer_run_id: run-uuid
source_refs:
  - suggestion-uuid
  - agent-security-review-uuid
supersedes: null
status: accepted
```

Initial durable formats should be:

- Markdown for plans, ADRs, specifications, handoffs, and reports;
- JSON for machine contracts and state snapshots;
- HTML for Hyperspace dashboards, review tools, and interactive artifacts.

## Workflow execution model

### 1. Capture the objective

The runtime creates or reuses one canonical task, records the objective, and
associates the initiating provider session without making that session the
source of truth.

### 2. Generate a workflow proposal

The coordinator receives:

- the objective;
- project instructions;
- current task and artifact references;
- provider capability inventory;
- workflow policy and budgets;
- untriaged user suggestions relevant to initial planning.

It produces a workflow definition and a concise phase summary.

### 3. Validate before execution

The runtime rejects a generated workflow that:

- requests unavailable capabilities without a declared fallback;
- widens parent permissions;
- contains direct filesystem, network, process, or module access;
- exceeds concurrency, total-agent, retry, or time limits;
- contains dependency cycles;
- references undeclared repository roots;
- lacks output schemas for fan-in steps;
- attempts destructive actions without a declared human gate;
- cannot be serialized and hashed for provenance.

### 4. Approve according to risk

Initial policy:

- read-only workflows may run after showing a compact plan;
- write workflows require one approval of the exact script digest;
- reusable reviewed workflows may be allowlisted per repository;
- a changed script digest requires renewed approval;
- destructive or externally visible actions always retain their own native or
  workflow-level approval.

### 5. Resolve providers and models

For each worker, the scheduler evaluates:

- required capabilities;
- requested provider or provider exclusion;
- current provider availability;
- configured model-class mapping;
- repository and worktree support;
- concurrency and quota policy;
- need for context inheritance versus a fresh worker;
- whether cross-provider review is requested.

The selected mapping is persisted before launch.

### 6. Create durable child tasks

Every material worker receives a stable child task or task attempt reference.
Very small internal synthesis calls may remain run-local, but the policy must be
explicit and observable. Dependencies in the workflow become task-store edges
or recorded run-local dependencies.

### 7. Execute through provider adapters

The adapter creates a native session or native subagent, supplies the resolved
instructions and inputs, and streams normalized events while retaining the raw
provider reference.

### 8. Checkpoint and consume suggestions

At a declared checkpoint, the manager:

1. snapshots completed stage results;
2. reads suggestions after the run's previous suggestion cursor;
3. asks the coordinator to disposition them;
4. updates tasks and durable artifacts;
5. revises only the unexecuted portion of the workflow;
6. validates and records the new workflow revision;
7. opens a human gate if a required decision cannot be inferred safely;
8. continues without demanding a conversational acknowledgement.

### 9. Fan in and verify

The runtime does not concatenate arbitrary worker transcripts. It supplies
structured worker outputs to a synthesis or verification worker. The final
result distinguishes:

- verified findings;
- conflicting findings;
- unverified claims;
- failed or missing worker results;
- implementation changes and validation evidence.

### 10. Publish and close

Completion requires:

- required child tasks completed or explicitly waived;
- output artifact written and validated;
- accepted decisions updated;
- every suggestion dispositioned;
- validation evidence recorded;
- unresolved follow-up tasks created;
- provider sessions left in a known state;
- objective task completed only after the exit contract is satisfied.

## Provider adapter contract

Each adapter implements a common port:

```typescript
interface ProviderAdapter {
  name(): string;
  capabilities(): Promise<ProviderCapabilities>;
  spawn(spec: ResolvedAgentSpec): Promise<ProviderSessionRef>;
  events(session: ProviderSessionRef): AsyncIterable<NormalizedEvent>;
  send(session: ProviderSessionRef, message: ProviderMessage): Promise<void>;
  stop(session: ProviderSessionRef): Promise<StopResult>;
  resume(session: ProviderSessionRef): Promise<ProviderSessionRef>;
  inspect(session: ProviderSessionRef): Promise<ProviderSessionState>;
}
```

Not every provider will support every method equally. Capability discovery must
be explicit:

```yaml
features:
  native_subagents: true
  custom_agent_definition: true
  background_execution: true
  per_child_model: true
  per_child_permissions: partial
  steer_running_child: true
  resume_child: true
  worktree_isolation: true
```

The scheduler must never infer support from the provider name alone.

### Codex adapter

The first Codex adapter should prefer official local execution surfaces rather
than scraping the TUI. Current Codex supports subagent workflows and custom
agents with instructions, model and reasoning settings, sandbox configuration,
MCP servers, and skills. The adapter should preserve native agent threads and
approval behavior while publishing normalized lifecycle events.

Implementation research should compare:

- Codex App Server for session control and event streaming;
- Codex SDK for programmatic invocation;
- non-interactive `codex exec` as a bounded fallback;
- native subagent delegation when a Codex coordinator owns the workflow stage.

### Claude adapter

Claude supports dynamically supplied subagent definitions, background
subagents, hooks, teams, forks, and its own dynamic workflow runtime. The
adapter should use official programmatic or CLI surfaces and hooks, not parse
terminal rendering.

The portable runtime should not attempt to execute `.claude/workflows/` as its
canonical format. A Claude workflow may be imported as inspiration or compiled
into the portable contract, but Claude-specific globals and permission behavior
remain provider extensions.

### OpenCode adapter

OpenCode should be added only after Codex and Claude prove the contract. The
third adapter is important because it tests whether the abstraction is truly
portable rather than merely the intersection of two implementations.

## Workflow runtime and sandbox

The generated workflow runs in a restricted environment with only orchestration
primitives:

```text
agent(spec)
parallel(specs)
pipeline(items, factory, options)
checkpoint(name, state)
gate(spec)
artifact(kind, value)
task(spec)
emit(event)
```

It has no direct access to:

- filesystem APIs;
- shell execution;
- environment variables;
- sockets or HTTP;
- module imports;
- provider credentials;
- the task database;
- artifact storage internals.

Workers perform real actions through their granted provider tools. The
workflow script only coordinates them.

Required guards:

- concurrency limit;
- total spawned-agent limit;
- maximum fan-out per operation;
- wall-clock budget;
- retry budget with exponential backoff;
- maximum workflow revisions;
- maximum queued suggestions consumed per checkpoint;
- output-size limits;
- cancellation propagation;
- cycle and recursive-spawn protection;
- idempotency keys for all durable mutations.

For the first implementation, prefer the smallest runtime that can be audited.
Do not embed a general Node or Bun environment and attempt to remove dangerous
APIs afterward. Candidate approaches must be evaluated with adversarial tests
before model-generated scripts are executed.

## Suggestion inbox and steering semantics

### Input classes

The terminal interface should distinguish three forms:

```text
agentctl suggest "Consider offline mode"
agentctl now "Use the existing parser before continuing"
agentctl interrupt "Stop; this must not write production data"
```

`suggest` is the default for ordinary additions:

- store immediately;
- attach to the active objective or named task;
- do not inject into a running provider turn;
- make the pending count visible;
- process at the next relevant checkpoint.

`now` requests steering at the next provider-safe message boundary:

- preserve completed work;
- send through the provider's supported steering mechanism;
- record that the workflow was revised mid-stage;
- do not imply immediate process termination.

`interrupt` requests cancellation or pause:

- stop or pause affected workers using native APIs;
- record the reason and partial results;
- require explicit resume or replacement when appropriate.

### Triage policy

The coordinator must evaluate each suggestion against:

- the accepted objective and exit contract;
- architectural fit;
- user-facing coherence;
- dependency and validation implications;
- risk and reversibility;
- current stage and completed work;
- duplication with existing tasks or decisions.

The coordinator must not silently broaden scope. Suggestions that produce a
distinct deliverable become separate tasks. Suggestions that conflict with an
accepted decision are surfaced with concrete evidence and an explicit choice.

### Checkpoint selection

Default safe checkpoints include:

- after discovery, before planning;
- after a plan, before writes;
- after a coherent implementation unit;
- before a destructive or externally visible action;
- before fan-in synthesis when new input changes evaluation criteria;
- when a worker becomes genuinely blocked;
- before final artifact publication.

Queued suggestions should not wait indefinitely. A workflow with no natural
checkpoint for a long period should emit a nonblocking intake checkpoint after
a configured amount of meaningful work, not merely on a fixed timer.

## Durable decisions and artifacts

### Promotion pipeline

```text
conversation or suggestion
        -> candidate constraint or decision
        -> evidence and conflict check
        -> accepted / rejected / deferred
        -> durable Markdown or structured record
        -> artifact and task links
        -> Hyperspace projection
```

### Decision record shape

```markdown
# Decision: Use provider-native sessions beneath portable workflows

Status: accepted
Date: 2026-08-11
Objective: obj-uuid

## Context

Why the decision was required.

## Decision

The behavior being committed to.

## Rationale

Evidence and tradeoffs.

## Consequences

What becomes easier, harder, or intentionally unsupported.

## Sources

Provider docs, agent results, tasks, suggestions, and superseded decisions.
```

### Maintenance rules

- Accepted decisions are updated only through an explicit new decision or
  supersession, never silently rewritten to match later code.
- Specifications describe current accepted behavior and may be reconciled as
  implementation changes.
- Run reports are immutable evidence snapshots.
- Task handoffs may link to decisions but do not duplicate entire documents.
- HTML dashboards render current state and link to canonical records.
- Every generated artifact records producer, source inputs, and validation.
- Agents check relevant accepted decisions before planning or implementing.

OpenSpec is a strong candidate for the specification/change folder convention,
but adopting it is a separate decision. The runtime should depend on a small
`ArtifactStore` contract rather than importing OpenSpec semantics into its core.

## Attention and notification model

The system should optimize for "what needs me" rather than "what changed."

### Notify immediately

- a human gate blocks all useful progress;
- a dangerous or externally visible action needs approval;
- a workflow fails with no safe retry path;
- a user-requested review artifact is ready;
- a configured cost, time, or agent-count threshold is exceeded.

### Show in the hub without interrupting

- ordinary progress events;
- child-agent starts and completions;
- queued suggestions;
- automatic retries;
- successful validation;
- completed intermediate artifacts;
- work that remains independently runnable.

### Notification behavior

- deduplicate notifications by gate or failure identity;
- group multiple blocked workers under the decision that blocks them;
- allow snooze without changing task state;
- clear a notification when its underlying gate resolves;
- preserve a durable record even after the UI notification is dismissed;
- use native macOS notifications only for the immediate category;
- expose counts in tmux without requiring the dashboard to be open.

## Terminal interface

All examples use the placeholder `agentctl` name.

### Objectives and workflows

```text
agentctl start "objective" --repo "$PWD" --coordinator auto
agentctl plan OBJECTIVE_ID
agentctl run WORKFLOW_ID
agentctl pause RUN_ID
agentctl resume RUN_ID
agentctl stop RUN_ID
agentctl status [RUN_ID] [--json]
agentctl inspect RUN_ID
```

### Suggestions and gates

```text
agentctl suggest "message" [--objective ID] [--task ID]
agentctl suggestions [--queued] [--json]
agentctl now "message" --run ID
agentctl interrupt "reason" --run ID
agentctl gates [--open] [--json]
agentctl gate answer GATE_ID --value VALUE
```

### Agents

```text
agentctl agents [--run ID] [--json]
agentctl agent inspect AGENT_ID
agentctl agent message AGENT_ID "message"
agentctl agent stop AGENT_ID
agentctl capabilities [--provider codex|claude|opencode]
```

### Artifacts and decisions

```text
agentctl artifacts [--objective ID]
agentctl artifact show ARTIFACT_ID
agentctl decisions [--repo PATH]
agentctl decision show DECISION_ID
```

The CLI must have bounded execution time for status reads and must not require a
write lock to render persistent dashboards.

## MCP interface

The same runtime should expose a small MCP server so any supported coordinator
can use the workflow layer without shell-specific prompt construction:

```text
workflow.create
workflow.validate
workflow.run
workflow.status
workflow.checkpoint
agent.spawn
agent.list
agent.message
agent.stop
suggestion.list
suggestion.disposition
gate.create
gate.resolve
artifact.publish
artifact.get
```

MCP tools must enforce the same authorization and validation as the CLI. MCP is
an interface to the runtime, not a privileged bypass.

## Persistence and event model

### Source-of-truth separation

| State | Initial owner |
| --- | --- |
| Objectives and task completion | `TaskStore` backed by managed `todo` |
| Workflow definitions and runs | workflow runtime store |
| Provider transcripts | provider-native storage |
| Cross-process lifecycle events | `agent-comms` |
| Specifications and decisions | repository Markdown / `ArtifactStore` |
| Rich dashboards and forms | Hyperspace HTML |
| Terminal process state | tmux and provider processes |

### Normalized event envelope

```json
{
  "version": 1,
  "event_id": "uuid",
  "timestamp": "2026-08-11T19:00:00Z",
  "kind": "agent.waiting_for_input",
  "objective_id": "obj-uuid",
  "workflow_run_id": "run-uuid",
  "agent_id": "agent-uuid",
  "provider": "codex",
  "provider_session_ref": "opaque-provider-value",
  "payload": {},
  "dedupe_key": "gate:gate-uuid"
}
```

Normalized events describe portable state. Raw provider events may be retained
as adapter diagnostics, but consumers should not need to understand them.

### Minimum event vocabulary

```text
objective.created
objective.completed
workflow.proposed
workflow.approved
workflow.started
workflow.revised
workflow.paused
workflow.completed
workflow.failed
agent.resolved
agent.started
agent.progress
agent.waiting_for_input
agent.completed
agent.failed
suggestion.queued
suggestion.dispositioned
gate.opened
gate.resolved
artifact.published
decision.accepted
decision.superseded
```

## Scheduling policy

The scheduler operates on ready workflow nodes, provider capacity, and task
dependencies.

### Default rules

- Prefer a fresh worker for bounded research, tests, or review.
- Prefer context inheritance only when reconstructing context would dominate
  the task or lose important conversational nuance.
- Prefer parallel execution for independent read-heavy work.
- Serialize overlapping write scopes unless they use isolated worktrees.
- Use cross-provider review when independence materially improves confidence,
  not as a ceremonial second opinion.
- Do not spawn a worker whose expected contribution is smaller than the cost of
  reconstructing its context.
- Stop expanding a workflow when new rounds cease producing novel information.
- Respect configured agent, time, and retry budgets.
- Keep one accountable coordinator even when many workers run.

### Provider selection

Provider selection should be policy-driven and explainable:

```yaml
selection:
  required_capabilities:
    - repository.read
  preferred_provider: auto
  exclude_provider: null
  independence_from: agent-implementer-uuid
  model_class: balanced
  reason: Cross-check implementation using an independent provider
```

The resolved decision becomes part of the run record.

## Failure and recovery semantics

### Provider failure

- Preserve the provider reference and last normalized event.
- Retry only when the failure is classified as transient and the operation is
  idempotent.
- Allow policy-approved fallback to another provider using the same AgentSpec.
- Record that the provider changed and do not imply transcript continuity.

### Worker failure

- Preserve partial artifacts and validation.
- Mark dependent nodes blocked while unrelated branches continue.
- Allow a replacement worker to consume the failed worker's durable inputs and
  partial result.
- Do not mark the child task complete merely because the workflow continues.

### Runtime restart

- Reload workflow state from the last committed checkpoint.
- Reattach to provider sessions when supported.
- Classify sessions that cannot be reattached as unknown rather than failed.
- Ask the adapter to inspect before launching replacements.
- Ensure durable mutations are idempotent.

### User interruption

- Propagate cancellation to affected active workers.
- Preserve completed child results.
- Record whether each worker stopped, completed during cancellation, or became
  unreachable.
- Require a new validated workflow revision before materially different work
  resumes.

## Security model

### Trust boundaries

1. User and checked-in policy define maximum authority.
2. The coordinator proposes workflow code and worker specs.
3. The runtime validates and constrains the proposal.
4. Provider adapters translate only approved capabilities.
5. Provider sandboxes and permission prompts remain the final enforcement
   boundary for worker actions.

### Required controls

- schema validation for every generated spec;
- explicit repository-root allowlists;
- immutable approved workflow digests;
- denial of direct workflow filesystem, process, and network access;
- child capability intersection with parent authority;
- no plaintext credentials in workflow or event records;
- redaction policy before artifact publication;
- separate read-only and write-capable worker profiles;
- worktree isolation for parallel writers;
- native approval preservation for destructive actions;
- audit log of user, coordinator, runtime, and provider decisions;
- bounded concurrency, retries, and resource use;
- adversarial tests for prompt attempts to widen permissions.

## Implementation plan

### Phase 0: contract spike

Purpose: validate that the portable boundary is real before building a daemon or
UI.

Deliverables:

- written `AgentSpec`, `WorkflowRun`, `Suggestion`, `Gate`, `ArtifactRef`, and
  normalized event schemas;
- capability vocabulary and parent/child authority rules;
- provider capability matrices for current Codex and Claude versions;
- one hand-authored portable workflow represented in both providers;
- a decision between restricted JavaScript, structured IR, or a hybrid;
- explicit ownership decision: standalone runtime project versus a component of
  nearly-headless;
- threat model for generated workflow execution.

Acceptance criteria:

- the same semantic two-worker read-only workflow runs through both adapters;
- output is returned through one normalized result schema;
- no provider-specific field appears in the portable AgentSpec;
- every provider-specific compromise is documented in the capability matrix;
- no long-running daemon is required for the spike.

### Phase 1: read-only runner and adapters

Purpose: establish reliable execution without risking concurrent writes.

Deliverables:

- standalone `agentctl` prototype in its own repository;
- Codex adapter using an official programmatic execution surface;
- Claude adapter using an official programmatic execution surface;
- `agentctl capabilities`, `run`, `status`, and `inspect`;
- immutable run directory with generated workflow, resolved specs, and results;
- normalized start, progress, completion, and failure events;
- optional publication into `agent-comms`;
- JSON output contracts and fixtures.

Acceptance criteria:

- a coordinator can generate a workflow that launches both a Codex and Claude
  read-only worker;
- the run remains inspectable after the initiating terminal exits;
- status does not scrape tmux panes or TUI rendering;
- provider authentication errors are classified and surfaced without corrupting
  run state;
- stopping a run leaves a complete audit record.

### Phase 2: task store, suggestions, and checkpoints

Purpose: connect dynamic execution to durable project work and the user's input
style.

Deliverables:

- `TaskStore` interface backed by the managed `todo` wrapper;
- objective-to-task and worker-to-child-task mappings;
- suggestion queue with `suggest`, `now`, and `interrupt` semantics;
- checkpoint snapshots and suggestion cursors;
- disposition workflow and resulting task links;
- human gate records;
- terminal views for queued suggestions and open gates.

Acceptance criteria:

- adding an ordinary suggestion does not send a provider message or interrupt a
  worker;
- the suggestion is consumed exactly once at a relevant checkpoint;
- each suggestion has a durable disposition;
- a distinct deliverable becomes a separate canonical task;
- a blocking decision produces one deduplicated gate;
- task mutations use stable IDs and the managed wrapper only.

### Phase 3: dynamic orchestration runtime

Purpose: let coordinators generate and execute data-dependent workflows safely.

Deliverables:

- restricted orchestration SDK or interpreted IR;
- `agent`, `parallel`, `pipeline`, `checkpoint`, `gate`, and `artifact`
  primitives;
- dynamic fan-out based on prior structured results;
- concurrency, retry, time, and total-agent budgets;
- approval by workflow digest;
- resumable committed checkpoints;
- fan-in synthesis and verification patterns;
- workflow template promotion and versioning.

Acceptance criteria:

- workflow code cannot access shell, filesystem, network, or environment
  directly;
- a discovered list can produce bounded dynamic fan-out;
- a changed generated script invalidates prior approval;
- interruption and restart preserve completed stage results;
- cycles, recursive runaway spawning, and excessive fan-out are rejected;
- one reusable workflow can be saved and rerun with different arguments.

### Phase 4: write-capable isolated workers

Purpose: support implementation work without allowing agents to collide in one
checkout.

Deliverables:

- write-scope declaration;
- worktree creation, ownership, and cleanup contract;
- conflict detection before parallel launch;
- serialized merge or integration stage;
- validation requirements per child task;
- rollback and partial-result handling;
- provider-native permission preservation.

Acceptance criteria:

- parallel writers never modify the same working tree;
- overlapping write scopes are rejected or serialized;
- unrelated dirty-worktree changes are preserved;
- each worker reports exact files and validation;
- integration happens in one accountable stage;
- failed integration does not erase worker branches or artifacts.

### Phase 5: durable artifact maintenance

Purpose: turn accepted decisions and outcomes into project knowledge
automatically.

Deliverables:

- `ArtifactStore` interface;
- plan, decision, specification, handoff, and run-report templates;
- conversation/suggestion-to-decision promotion workflow;
- supersession and provenance rules;
- optional OpenSpec adapter or compatible project layout;
- Hyperspace projections generated by the manager agent;
- checks for stale or contradictory accepted artifacts.

Acceptance criteria:

- a completed material workflow leaves a useful artifact without relying on its
  transcript;
- accepted decisions include rationale and evidence links;
- changing a decision creates a visible supersession trail;
- implementation can be checked against accepted specifications;
- HTML projections can be regenerated from durable sources;
- provider workers do not spend their main implementation turns maintaining UI
  HTML.

### Phase 6: attention hub and notifications

Purpose: make the system operable when several workflows run at once.

Deliverables:

- tmux/Neovim status projection over normalized events;
- `WORK`, `WAIT`, `DONE`, and `ERR` classification;
- grouped human-gate and review queue;
- macOS notification policy and deduplication;
- drilldown into workflow, worker, task, suggestion, and artifact references;
- explicit reply action routed to a gate or selected session;
- no automatic input injection into working sessions.

Acceptance criteria:

- the user can identify all genuinely blocked work in one terminal view;
- ordinary progress produces no native notification;
- resolving one gate clears every derived waiting notification;
- the dashboard remains usable while task mutations are locked;
- no worker is classified from pane text alone when a structured event exists;
- selected explicit replies reach the intended target and are auditable.

### Phase 7: third-provider validation and hardening

Purpose: prove provider neutrality and prepare for everyday use.

Deliverables:

- OpenCode adapter;
- adapter contract tests shared across all providers;
- mixed-provider workflows and cross-provider review;
- crash, restart, lost-session, unavailable-provider, and quota test suite;
- performance and cost telemetry;
- install, update, disable, and uninstall lifecycle;
- dotfiles module containing only integration assets and tests;
- migration guide from direct todo-driven agent delegation.

Acceptance criteria:

- adding OpenCode requires an adapter, not changes to core workflow semantics;
- a workflow can substitute a provider after a classified transient failure;
- capability negotiation prevents unsupported work before launch;
- disabling the dotfiles module removes managed links while preserving the
  external project checkout and durable run data;
- bootstrap can reproduce the integration on a clean machine.

## Testing strategy

### Contract tests

- validate every schema with valid, missing, malformed, and future-version
  fixtures;
- run the same adapter lifecycle suite against Codex and Claude;
- verify stable JSON output and error envelopes;
- prove task and artifact mutations are idempotent;
- prove capability reduction cannot be bypassed by generated fields.

### Workflow tests

- linear sequence;
- parallel read-only fan-out;
- dynamic fan-out from discovered inputs;
- fan-in with one failed worker;
- retry then success;
- retry exhaustion;
- checkpoint suggestion ingestion;
- workflow revision after checkpoint;
- human gate pause and resume;
- user interrupt with partial completion;
- provider fallback without false transcript continuity;
- runaway expansion rejection.

### Integration tests

- Codex coordinator with Claude worker;
- Claude coordinator with Codex worker;
- mixed provider review using an independence constraint;
- task-store lock contention while status views remain responsive;
- agent-comms unavailable while local run persistence remains correct;
- manager unavailable while workers continue and events catch up later;
- tmux dashboard reconnect after runtime restart;
- worktree isolation with a dirty primary checkout.

### Artifact tests

- artifact exists and parses;
- provenance points to real tasks, suggestions, and runs;
- accepted decision supersession is explicit;
- no secret fixture reaches published artifacts;
- HTML projection can be regenerated from canonical inputs;
- a new agent can answer the objective's key decisions using artifacts without
  reading the original transcript.

### Adversarial tests

- workflow asks for direct shell access;
- worker spec attempts to widen capabilities;
- prompt injects provider credentials into artifacts;
- generated script attempts import, filesystem, network, or unbounded recursion;
- malicious worker output attempts to alter downstream instructions;
- suggestion text attempts to bypass checkpoint policy;
- forged provider event attempts to resolve a gate;
- stale approval digest is reused after script modification.

## Migration from the current system

### Keep working paths operational

The first phases do not remove or rewrite:

- the managed `todo` command;
- existing todo and handoff files;
- tmux sessions or scratchpads;
- provider-native session storage;
- current nearly-headless/Hyperspace artifacts;
- existing `@todo` skill behavior.

### Introduce adapters at boundaries

1. Add a `TaskStore` adapter that uses existing stable-ID todo commands.
2. Publish normalized run events without changing the current tmux hub.
3. Add an optional hub section driven by those events.
4. Add suggestion commands before automatic workflow revision.
5. Run read-only cross-provider workflows before any write support.
6. Introduce artifact promotion after task and run identity is stable.
7. Evaluate the task backend only after observed usage reveals concrete limits.

### Avoid dual sources of truth

During migration:

- task status remains canonical in the configured TaskStore;
- workflow status remains canonical in the runtime store;
- provider status remains evidence from the provider adapter;
- the hub combines them but does not invent a fourth status database;
- artifacts link to task and run IDs rather than copying mutable status text.

## Success criteria

The system is successful when:

- the user can start, inspect, and control workflows entirely from the terminal;
- a coordinator can dynamically create specialized workers without choosing a
  provider-specific configuration format;
- at least three provider adapters implement the same core contract;
- ordinary mid-work suggestions are never lost and do not automatically derail
  running work;
- every suggestion receives a durable disposition;
- all work requiring the user is visible in one consolidated attention view;
- native notifications correspond to genuine attention requests rather than
  routine progress;
- another agent can understand a completed objective from tasks, decisions,
  artifacts, and validation without replaying transcripts;
- providers can be changed without migrating the project-management record;
- disabling or replacing the orchestration runtime does not destroy provider
  sessions, tasks, or repository artifacts.

Candidate operational metrics:

- median time from human gate creation to user awareness;
- percentage of notifications that required meaningful user action;
- percentage of suggestions dispositioned by the next relevant checkpoint;
- number of workflows completed after provider substitution;
- task/artifact records with complete provenance;
- manual context-reconstruction requests per objective;
- duplicate or contradictory decision rate;
- provider-adapter contract pass rate;
- workflow retries, agent count, wall time, and token/cost estimates.

## Risks and tradeoffs

### Lowest-common-denominator abstraction

Risk: portability may hide the features that make each provider useful.

Mitigation: keep a small portable core plus explicit, capability-negotiated
extensions. A workflow using an extension declares reduced portability.

### Generated workflow safety

Risk: model-generated code becomes another execution surface.

Mitigation: use a purpose-built restricted runtime, immutable digests,
validation, budgets, and no direct I/O. Begin with read-only workflows.

### Excessive agent spawning

Risk: dynamic fan-out increases latency, cost, and noisy results.

Mitigation: explicit budgets, novelty-based stopping, bounded pipelines, and a
policy that rejects workers whose context reconstruction cost exceeds their
expected contribution.

### Split brain between task, workflow, and provider state

Risk: one layer reports completion while another reports failure or activity.

Mitigation: define ownership per state type, retain opaque cross-references, and
derive user-facing status from explicit reconciliation rules.

### Artifact churn

Risk: agents rewrite documents on every minor event and bury meaningful
decisions in generated noise.

Mitigation: update durable artifacts only at semantic checkpoints, distinguish
immutable run reports from maintained specifications, and require explicit
decision promotion.

### Suggestion starvation

Risk: an agent continues too long without reaching a checkpoint.

Mitigation: require checkpoint declarations for long stages, show pending counts,
and allow explicit `now` or `interrupt` escalation.

### Adapter drift

Risk: provider CLIs and APIs evolve independently.

Mitigation: capability discovery, versioned adapter contracts, focused live
smoke tests, and no TUI scraping as a primary integration.

### Too many overlapping products

Risk: todo, agent-comms, the workflow runtime, nearly-headless, and Hyperspace
develop overlapping stores and responsibilities.

Mitigation: preserve the ownership table in this document as an architecture
test. Reject features that place the same canonical state in two components.

## Decisions made by this plan

1. Provider-native session management remains authoritative for provider
   sessions.
2. Dynamic workflows are portable orchestration above providers, not a new
   provider implementation.
3. Worker definitions use a capability-based AgentSpec.
4. Ordinary user additions enter a durable suggestion inbox and do not
   immediately steer active work.
5. Human gates are durable dependencies distinct from provider permission
   prompts.
6. `agent-comms` remains a generic event/command bus and does not become the
   scheduler.
7. Nearly-headless/Hyperspace remains the manager and rich artifact surface.
8. The existing managed todo wrapper remains the initial TaskStore backend.
9. Reusable runtime code belongs in an external project, not inside dotfiles.
10. Read-only cross-provider workflows precede write-capable orchestration.

## Open decisions

These require explicit resolution during Phase 0:

1. Should the runtime be its own `agent-workflows` project or a core component
   of nearly-headless with a standalone CLI?
2. Should generated workflows use restricted JavaScript, a structured IR, or a
   script compiled into a canonical IR?
3. What is the minimum capability vocabulary that both Codex and Claude can
   enforce rather than merely approximate?
4. Which official Codex execution surface provides the most stable local
   session and event contract?
5. Which Claude surface best supports dynamic session definitions without
   coupling the core runtime to `.claude/workflows/`?
6. Which data belongs in the workflow runtime store versus `agent-comms`
   SQLite?
7. Should suggestions be stored in the TaskStore, the workflow store, or both
   through linked immutable IDs?
8. Is OpenSpec adopted directly, adapted, or used only as inspiration for the
   ArtifactStore layout?
9. What exact actions require workflow-level approval in addition to provider
   approval?
10. How long should completed provider sessions and workflow run data be
    retained?
11. How should cost and token budgets be normalized when providers expose
    different accounting data?
12. When should a successful ephemeral worker definition be promoted to a
    durable reusable agent profile?

## First implementation slice

The recommended first slice is deliberately narrow:

> From one terminal command, run a reviewed, read-only workflow that asks a
> Codex worker and a Claude worker to inspect the same repository question,
> synthesizes their structured results, records normalized events and task
> references, and produces one durable Markdown report.

It should include:

- a hand-authored workflow rather than generated workflow code;
- one portable AgentSpec schema;
- two provider adapters;
- no background daemon requirement;
- no repository writes by workers;
- stable JSON status;
- one canonical parent task and two child task references;
- one immutable run report with provenance;
- a failure path where one provider is unavailable;
- a terminal view that clearly distinguishes partial from complete success.

This slice tests the central claim—portable semantic orchestration over native
provider execution—before investing in dynamic generation, suggestion intake,
artifact maintenance, or a richer UI.

## Reference material

- [Claude Code dynamic workflows](https://code.claude.com/docs/en/workflows):
  model-authored workflow scripts, restricted orchestration, background runs,
  dynamic fan-out, execution limits, and resumability behavior.
- [Claude Code custom subagents](https://code.claude.com/docs/en/sub-agents):
  dynamically supplied agent definitions, capability restrictions, model
  selection, background execution, and native session behavior.
- [Codex subagents documentation](https://developers.openai.com/codex/subagents/):
  Codex subagent workflows, custom agent configuration, native agent threads,
  model and reasoning settings, sandbox controls, MCP servers, and skills.
- [Beads documentation](https://beads.gascity.com/): dependency-aware agent task
  tracking, atomic claims, gates, and event-journal patterns to evaluate behind
  the TaskStore interface.
- [OpenSpec](https://github.com/Fission-AI/OpenSpec): a candidate convention for
  proposals, specifications, design documents, tasks, and cross-repository
  planning artifacts.
- Live machine-level architecture references currently under `~/.agents/docs`:
  `agent-comms.md`, `hyperspace-product.md`, `nearly-headless-product.md`, and
  `agent-architecture-exploration.html`.
