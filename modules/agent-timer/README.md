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
auto_start = false
default_seconds = 600
warning_seconds = 60
report_timeout_seconds = 120
retention_seconds = 604800
expiry_sound = "Ping"
preferred_agents = ["codex", "claude", "opencode"]
```

The timer command and fail-open Codex hooks are installed, but `auto_start = false`
keeps ordinary Codex, Claude Code, and OpenCode turns untimed. Start a timer
explicitly with `agent-timer start`, set `AGENT_TIMER_AUTO_START=true` for one Codex
session, or opt a profile into automatic start in the TOML. When more than one
supported agent is present in a pane, the preferred list above decides which one
owns an explicitly started timer.

Automatic hooks are optional integration. A disabled lifecycle latch, missing timer
command, unavailable dependency, non-tmux session, or failed worker launch returns
an empty successful hook response and leaves the coding agent on its normal path.
Manual `agent-timer start` remains strict so an operator can diagnose an explicit
request.

An environment variable remains an explicit per-session override. Set it
before launching or prompting an agent when a different block is appropriate:

```sh
export TASK_TIMELIMIT_SECS=600
```

A native warning notification is sent according to `warning_seconds`; override that
for one session with `TASK_TIME_WARNING_SECS`. It never types a warning prompt into
the agent. At expiry the timer advances the same state record into another block,
then immediately notifies and beeps. For Codex it may start one separate
`codex exec` process with `--ephemeral`, `--ignore-user-config`, a read-only sandbox,
approvals disabled, automatic timing disabled, and a bounded timeout. It writes the
full repository snapshot to a unique report beneath
`~/.local/state/agent-timer`; state records its PID, status, timeout, report, and log
paths. A second expiry never overlaps a running report. The detached process sees
the repository, not the live TUI transcript or subagent state, and its prompt forbids
edits, network access, external actions, and tmux mutation. Completion produces a
second native notification with a sanitized bounded excerpt. Missing launch
capability and non-Codex agents stay native-only. Automated delivery never sends
tmux keys; `/btw` remains an explicit manual interactive Codex action.

At checkpoint expiry, macOS immediately plays the configured system
sound once using `/usr/bin/afplay`. Set `expiry_sound = "none"` (or export
`AGENT_TIMER_EXPIRY_SOUND=none`) to silence it; other names resolve below
`/System/Library/Sounds`.

The single worker captures immutable tmux session/pane IDs, the pane PID and TTY, and
the exact agent PID, kind, start time, and command. Before delivery it verifies those
fingerprints, so a stale timer cannot schedule a report for a reused pane;
ordinary session renames and foreground-command display changes remain safe.
Those fingerprints are retained across every re-armed block. Automated delivery
never sends terminal input or creates or closes tmux resources. It allows at most one
detached report process per timer, terminates it on timeout or lifecycle retirement,
and otherwise falls back to native delivery. The worker checks liveness
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
Normal chezmoi apply manages that same marked entry automatically: the entry is
present only when both the module and automatic start are enabled. The checked-in
`auto_start = false` profile therefore runs no periodic timer service; an explicit
manual timer uses only its dedicated worker. Reconciliation preserves unrelated
cron jobs.

Lifecycle changes have a separate before-apply boundary. When
`modules.agentTimer.enabled` changes to `false`, chezmoi invokes the currently
installed `agent-timer shutdown --reason module-disabled` before it removes the
command, hooks, configuration, and tmux integration. An enabled apply with
`autoStart: false` similarly invokes
`shutdown --reason auto-start-disabled --automatic-only` so timers armed by an
older automatic profile cannot survive the transition while explicitly started
manual timers continue; it keeps the command, hooks, and configuration installed
for manual use. New state records distinguish `automatic` from `manual` origin, and
legacy hook records retain their canonical `codex-*` identity. Shutdown stops matching
live
timer workers, records their terminal status, and writes a disabled latch while it
still owns the lifecycle lock; it does not delete
`~/.local/state/agent-timer`. The after-apply lifecycle then removes only the
marked cron entry when disabled and clears the transient latch after the managed
targets and new `auto_start` setting are installed. The latch prevents a prompt from
re-arming a worker during reconciliation. If any timer state cannot be locked and stopped, the
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

The default checkpoint request deliberately does not request a commit. A global timer cannot
know whether every dirty file belongs to the active agent. When a commit is
part of the requested workflow, use `--message` or
`AGENT_TIMER_EXPIRY_MESSAGE` to say so explicitly.
