# Agent timer

`agent-timer` is a machine-wide recurring checkpoint guard for terminal agents. The
dotfiles repository is only its distribution source: chezmoi installs the
command at `~/bin/agent-timer`, the policy in `~/.agents/AGENTS.md`, and the
Codex integration at `~/.codex/hooks.json`.

The managed machine defaults live in
`~/.config/agent-timer/config.toml`. Chezmoi renders that standard config from
the module data, so profiles can set the default budget, warning lead time, and
terminal-record retention without shell startup code:

```toml
default_seconds = 600
warning_seconds = 60
retention_seconds = 604800
expiry_sound = "Ping"
preferred_agents = ["codex", "claude", "opencode"]
```

Codex is the default terminal agent. The standard tmux layout starts it in window 1,
and its `UserPromptSubmit` hook arms the timer automatically. For Claude Code or
OpenCode, run `agent-timer start` at the beginning of the work turn. When more than
one supported agent is present in a pane, the preferred list above decides which one
owns the timer.

An environment variable remains an explicit per-session override. Set it
before launching or prompting an agent when a different block is appropriate:

```sh
export TASK_TIMELIMIT_SECS=600
```

A warning steer is sent according to `warning_seconds`; override that for one
session with `TASK_TIME_WARNING_SECS`. At expiry the timer asks the agent to
delegate a read-only status snapshot to an available subagent, post the update
as commentary, and keep the primary task moving. It immediately advances the
same state record into another block. With the managed defaults, every new
block is 600 seconds. Expiry never ends the Codex turn or tmux session; work
stops only when complete or genuinely blocked.

After a verified checkpoint steer is recorded, macOS plays the configured system
sound once using `/usr/bin/afplay`. Set `expiry_sound = "none"` (or export
`AGENT_TIMER_EXPIRY_SOUND=none`) to silence it; other names resolve below
`/System/Library/Sounds`.

The single worker captures immutable tmux session/pane IDs, the pane PID and TTY, and
the exact agent PID, start time, and command. Before steering it verifies those
fingerprints, so a stale timer will not type into a pane that has been reused;
ordinary session renames and foreground-command display changes remain safe.
Those fingerprints are retained across every re-armed block. Steering sends
literal text, a harmless `End` navigation key, then Enter. Codex deliberately
treats rapid literal input as a paste burst and otherwise turns Enter into a
newline. A non-character `End` event deterministically flushes that state and
keeps the cursor at the end before Enter submits the steer, regardless of
message length. It never sends Ctrl-C or Escape and never
starts a second Codex process, closes a tmux session, or creates a duplicate
timer. The worker checks liveness
between bounded sleep slices and retires the timer as stale when the exact pane
or agent exits, so a recurring timer cannot become an indefinite orphan.

The detached worker is the exact clock and loops over each re-armed block.
It is launched through tmux's server-owned `run-shell -b` boundary rather than
as a child of the invoking hook or shell. The worker registers its exact PID
and process start time under the state lock before `start` returns. Same-turn
reuse verifies that fingerprint and relaunches a dead worker without changing
the current block deadline; a launch that cannot register is canceled instead
of leaving active state for a delayed orphan.
`agent-timer install-cron` adds a once-per-minute `tick` as recovery if that
worker dies; cron is not the primary timer because it cannot provide
second-level deadlines. The state token and lock make a worker/tick race
idempotent: only one checkpoint can advance a deadline. Removal is explicit:
`agent-timer uninstall-cron` removes only its marked entry.
Normal chezmoi apply manages that same marked entry automatically: enabling the
module installs one entry, and disabling it removes the entry without touching
unrelated cron jobs.

Module disablement has a separate before-apply boundary. When
`modules.agentTimer.enabled` changes to `false`, chezmoi invokes the currently
installed `agent-timer shutdown --reason module-disabled` before it removes the
command, hooks, configuration, and tmux integration. Shutdown stops live timer
workers, records their terminal status, and writes a disabled latch while it
still owns the lifecycle lock; it does not delete
`~/.local/state/agent-timer`. The after-apply lifecycle then removes only the
marked cron entry. The latch prevents a prompt from re-arming a worker between
shutdown and target removal. Re-enabling the module clears that latch before
installing targets. If any timer state cannot be locked and stopped, the
before-apply hook fails the apply instead of removing the command while workers
may still be live.

Tmux sessions are durable, so timer state is joined with the existing sesh
inventory instead of maintaining a second session registry:

```sh
agent-timer sessions
agent-timer sessions --json
agent-timer manage               # table, close prompt, or built-in sesh picker
agent-timer close SESSION                       # confirms interactively
agent-timer close SESSION --yes                 # idle-session automation
agent-timer close SESSION --yes --force-active  # explicit active override
```

The table includes every sesh tmux session, attachment/window counts, detected
Codex/Claude/OpenCode processes and elapsed times, active timer state, remaining
time, and path. A process-scan failure is shown as unknown and is treated as
active, not idle. Reconciliation marks timers stale and stops their workers
when their exact pane or agent process no longer exists. Closing a session uses
sesh to select it, resolves the immutable tmux session ID, and retires workers
before tmux's native `kill-session` operation because sesh has no delete
command. Attached sessions, live agents, active timers, and unknown activity
require typing the exact session name interactively or passing
`--force-active`; activity is checked again while the session lock is held.
The existing tmux command center exposes the same `manage` view under
Sessions > Agent timers, and `Ctrl-a T` opens it directly.

Terminal timer records are retained according to `retention_seconds` (seven
days by default) after completion, cancellation, disablement, or staleness,
then the cron tick prunes them. Override one session with
`AGENT_TIMER_RETENTION_SECS`, or run `agent-timer prune` explicitly. Recurring
active timers are never pruned.

Codex requires one-time review of a new user hook. After applying the module,
open `/hooks`, review `~/.codex/hooks.json`, and trust its command definition.

The default checkpoint steer deliberately does not request a commit. A global timer cannot
know whether every dirty file belongs to the active agent. When a commit is
part of the requested workflow, use `--message` or
`AGENT_TIMER_EXPIRY_MESSAGE` to say so explicitly.
