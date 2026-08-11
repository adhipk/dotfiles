---
name: todo
description: Turn an @todo or $todo request into a machine-wide dependency-aware workflow of repo-targeted agent tasks. Use when the user asks to split work across named agents or repositories, create several related todos, infer or declare task dependencies, run independent work concurrently, or carry one agent's result into downstream work. Create durable tasks through the global todo wrapper, orchestrate ready tasks with collaboration subagents when available, and store each completed result as a handoff for its dependents.
---

# Global Todo Orchestrator

Turn one request into a durable task graph, execute the ready work, and carry
validated results across dependency edges.

Read [references/task-contract.md](references/task-contract.md) before creating
or changing tasks.

## Core rules

1. Use the managed `todo` command for every ledger read and mutation. Never edit
   `todo.txt` directly and never invoke bare `tuxedo`.
2. Treat `todo root` as the canonical shared store. Do not derive task state from
   the current repository.
3. Create one task per distinct deliverable. Give every task a stable `id:`, an
   absolute `repo:`, an `owner:`, a shared `flow:`, and a `status:`.
4. Infer only necessary dependencies. Independent tasks remain parallel. Reject
   dependency cycles before creating anything.
5. Do not launch a dependent until every declared dependency is complete and
   its handoff exists.
6. Never archive or delete tasks automatically. Keep failed work open with
   `status:blocked` and a concise failure handoff.

## Parse the request

Treat `@todo` as the workflow trigger. Each following named `@agent` directive
is one candidate task:

```text
@todo
@analysis-bot repo=/absolute/path Find examples of this error.
@api-bot repo=/absolute/path Create an API regression test. after=analysis-bot
@prompt-agent repo=/absolute/path Explain why the evidence matters. after=analysis-bot
```

Accept natural dependency language such as "using the analysis," "after the API
test," or "based on both results." Explicit `after=` declarations win.

Resolve repositories in this order:

1. An absolute `repo=` path supplied by the user.
2. An exact local Git repository basename matching the directive.
3. The active repository when the directive clearly targets the current work.

If a target remains ambiguous, ask one consolidated question listing all
unresolved agents. Do not create a partially guessed workflow.

## Create the graph

1. Run `todo ls --json` and reuse an open task only when its deliverable, repo,
   owner, and flow intent truly match.
2. Generate one flow UUID and one task UUID per new node.
3. Topologically sort the nodes and assign `status:ready` only to nodes with no
   incomplete dependencies. Assign the others `status:blocked`.
4. Add every task through `todo add`, using the exact metadata contract.
5. Show the compact graph with agent, repository, dependencies, and current
   status before launching work.

Construct command arguments safely. Never use `eval` or interpolate user text
into executable shell syntax.

## Execute ready work

When collaboration tools are available, spawn one subagent for each ready task,
up to the harness concurrency limit. This skill explicitly requests subagent
delegation for ready graph nodes.

Before launch:

1. Set the node to `status:running` with `todo task-status TASK_ID running`.
2. Give the subagent only its task, absolute repository, stable task ID,
   constraints, and required upstream handoffs.
3. Tell it to preserve unrelated work and return a structured result containing
   outcome, artifact paths, validation, and worktree state.

For a node with dependencies, retrieve each direct parent with
`todo handoff get PARENT_ID` and copy the full contents into an
`Upstream handoffs` section of the downstream prompt. Include the handoff paths
as provenance. Do not substitute a summary when exact upstream evidence matters.

If collaboration tools are unavailable, create the graph and stop with the
ready task IDs. Do not claim agents were launched.

## Complete and hand off

For each finished subagent:

1. Verify its claimed artifacts and validation in proportion to risk.
2. Format the durable Markdown handoff defined in the task contract.
3. Store it atomically with `todo handoff put TASK_ID FILE`, or stream it on
   standard input without shell-interpolating the content.
4. Confirm `todo handoff get TASK_ID` returns the stored result.
5. Mark validated work complete with `todo task-done TASK_ID`.
6. Re-evaluate every direct dependent. When all its dependencies are complete
   and readable, set it to `status:ready` and launch it.

If a node fails, store the failure evidence as its handoff, set
`status:blocked`, and leave all descendants blocked. Continue unrelated branches.

## Report state

Restate the flow after every scheduling wave:

- completed task IDs and concrete outputs;
- running task IDs;
- newly ready task IDs;
- blocked task IDs and their unmet dependencies;
- handoff paths copied into downstream work.

Finish only when every node is complete or the remaining nodes are genuinely
blocked.
