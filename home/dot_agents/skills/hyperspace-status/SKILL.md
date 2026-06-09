---
name: hyperspace-status
description: >-
  Generate a status-dashboard HTML artifact for the current project by reading
  tmux session state. Use with nearly-headless profile when user asks for agent
  status, hyperspace overview, or what's running.
---

# Hyperspace Status

Build or refresh `.hyperspace/status.html` from live tmux data.

## Steps

1. Resolve project root (git root or cwd).
2. Infer tmux session name: `hs-<dirname>` or ask user.
3. Gather state:
   ```bash
   tmux has-session -t "$SESSION" 2>/dev/null
   tmux list-windows -t "$SESSION" -F '#{window_name}|#{window_active}' 2>/dev/null
   tmux list-panes -a -F '#{session_name}|#{window_name}|#{pane_title}|#{pane_current_command}' 2>/dev/null | rg "^${SESSION}\|"
   ```
4. Copy `status-dashboard.html` template; fill table rows per window.
5. Map status heuristics:
   - **running** — pane has active command (codex, claude, npm, etc.)
   - **needs-input** — pane title contains `Action Required` or `approve`
   - **exited** — pane shell idle after agent command
   - **unknown** — cannot determine
6. Write `.hyperspace/status.html`; ensure `shared/hyperspace.css` exists.
7. Suggest: `hyperspace-open-report status`

## If tmux session missing

Note "session not running" in the dashboard; suggest `sesh connect <name>` or hyperspace setup from `~/.agents/docs/nearly-headless.md`.

## Related

- `$html-artifact` for non-status HTML
- `~/.agents/profiles/nearly-headless/TASKS.md` for runtime CLI roadmap
