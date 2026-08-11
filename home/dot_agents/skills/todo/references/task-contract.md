# Global agent task contract

## Shared state

`todo root` resolves the machine-wide state directory:

```text
~/.agents/tasks/
├── todo.txt
├── done.txt
└── handoffs/
    └── TASK_ID.md
```

The managed wrapper owns one lock beside these files. Commands from different
repositories therefore serialize against the same ledger.

## Task line

Use this shape:

```text
(B) YYYY-MM-DD Deliverable +REPO_ALIAS @AGENT id:UUID owner:AGENT repo:/ABSOLUTE/PATH flow:UUID depends:UUID,UUID status:blocked
```

Required fields:

- `id:` — stable task identity; never reuse it for another deliverable.
- `owner:` — named agent responsible for the work.
- `repo:` — absolute repository path.
- `flow:` — identity shared by every node created from one `@todo` request.
- `status:` — `ready`, `running`, or `blocked`.

Use `depends:` only when a task has direct dependencies. Store comma-separated
task IDs with no spaces. `+REPO_ALIAS` is the human-facing project filter and
`@AGENT` is the human-facing owner filter.

## Dependency rules

Rank evidence in this order:

1. Explicit `after=` or `depends=` declarations.
2. Direct natural language such as "use X's result."
3. An unavoidable artifact dependency visible in the requested deliverables.

Do not add an edge merely because tasks concern the same feature. Prefer
parallel work when a downstream node can consume both results later. Reject
self-dependencies, missing parents, and cycles.

## Status transitions

```text
blocked -> ready -> running -> completed
                    |
                    +-> blocked
```

Completion is the todo.txt `x` state and must be performed with
`todo task-done TASK_ID`. A blocked node stays open. Do not represent completion
only through `status:completed`.

## Handoff format

Store one Markdown document per finished or failed task:

```markdown
# Agent task handoff

- Task: TASK_ID
- Flow: FLOW_ID
- Agent: AGENT
- Repository: /absolute/path
- Status: completed

## Outcome

What now works or what was learned.

## Artifacts

- Absolute or repository-relative artifact paths.

## Validation

- Exact checks and their results.

## Worktree

- Task-owned changes and unrelated pre-existing changes.

## Notes for dependents

Exact evidence, constraints, identifiers, or decisions the next task must use.
```

For failures, set `Status: blocked`, state the blocking condition, and include
the strongest available evidence.

## Managed commands

```bash
todo root
todo ls --json
todo add "TASK LINE"
todo task-number TASK_ID
todo task-status TASK_ID ready
todo task-status TASK_ID running
todo task-status TASK_ID blocked
todo handoff put TASK_ID RESULT_FILE
todo handoff get TASK_ID
todo handoff path TASK_ID
todo task-done TASK_ID
```

Resolve and mutate by stable task ID. Never cache a physical todo.txt line
number across commands.
