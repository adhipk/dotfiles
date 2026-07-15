## Time-boxed Delivery

- The timer is optional and its managed `auto_start` default is `false`. Do not arm it unless the user explicitly requests a timer or the current session enables automatic start. A missing command, disabled lifecycle, unavailable worker, or failed automatic hook means ordinary untimed agent behavior; it is never a blocker.
- A task is time-boxed only after `agent-timer start` succeeds or a Codex hook supplies `TASK TIMEBOX ACTIVE` context. `TASK_TIMELIMIT_SECS` may override the managed 600-second block with another positive integer. Tool calls, subagents, retries, steering, and context compaction do not reset an active block.
- Warnings are native notifications only. At expiry the timer re-arms the next block first, notifies and beeps immediately, and may launch one bounded detached read-only Codex process to collect a repository snapshot under timer state. It never types into, steers, interrupts, or injects checkpoint instructions into the primary TUI. An unavailable launcher, an overlapping report, or an agent without Codex's detached execution surface stays native-only.
- The detached report should identify repository-visible artifacts, validation, working-tree state, open canonical task IDs, and the next concrete step. It has no live transcript or subagent context and must not make edits, use the network, contact external services, or claim unvalidated work is complete. Completion is surfaced through a bounded native-notification excerpt; the full report path and status remain in timer state. `/btw` remains available only as an explicit manual interactive Codex action.
- Checkpoint expiry is never a termination condition. The primary task continues until the requested outcome is complete or genuinely blocked; the timer never ends the agent turn or tmux session.

## Incoming Requests During Active Work

- Assess each incoming request against the active objective, implementation difficulty, architectural fit, dependencies, end-user experience, and remaining time.
- Integrate it when it produces a more coherent result without putting the current checkpoint at risk. Explain the integration and trade-offs in plain language.
- Push back when it conflicts with the existing design, duplicates native tooling, harms the user experience, or cannot fit safely inside the remaining budget. Offer the smallest coherent alternative.
- If an addition should be deferred, capture or reuse its distinct canonical todo entry and continue the highest-value deliverable. Do not silently extend the timer.
