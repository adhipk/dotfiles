#!/usr/bin/env bash

set -uo pipefail

MODULE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ROOT_DIR=$(cd "$MODULE_DIR/../.." && pwd)
HUB="$MODULE_DIR/bin/tmux-hub"
BRIDGE="$ROOT_DIR/home/bin/executable_tmux-hub.tmpl"
LUA="$ROOT_DIR/nvim/lua/custom/tmux_hub.lua"
PASSED=0
FAILED=0

pass() { printf '  ✓ %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '  ✗ %s\n' "$1"; FAILED=$((FAILED + 1)); }
contains() {
  local description="$1" pattern="$2" file="$3"
  if rg -q -- "$pattern" "$file"; then pass "$description"; else fail "$description"; fi
}

printf 'Tmux Hub Tests\n'
printf '==============\n'

if [[ -x "$HUB" ]]; then pass 'hub launcher is executable'; else fail 'hub launcher is executable'; fi
if [[ -f "$BRIDGE" ]]; then pass 'thin chezmoi bridge exists'; else fail 'thin chezmoi bridge exists'; fi
if [[ -f "$LUA" ]]; then pass 'Neovim dashboard exists'; else fail 'Neovim dashboard exists'; fi

contains 'hub session skips the ordinary four-window template' 'DOTFILES_TMUX_TEMPLATE=skip' "$HUB"
contains 'bridge is gated by the tmux sessions module' 'modules.tmuxSessions.enabled' "$BRIDGE"
contains 'hub opens at the invoking session path' 'pane_current_path' "$HUB"
contains 'inside-tmux navigation switches the current client' 'switch-client' "$HUB"
contains 'fresh Ghostty windows drop inherited tmux state' 'env -u ZDOTDIR -u TMUX -u TMUX_PANE' "$HUB"
contains 'dashboard uses agent-timer live session inventory' "sessions.*--json" "$LUA"
contains 'dashboard detects approval prompts from pane content' 'capture-pane' "$LUA"
contains 'dashboard derives native agent attention states' 'derive_agent_status' "$LUA"
contains 'dashboard groups agents by repository path' 'group_agents' "$LUA"
contains 'dashboard renders a live pane preview' "capture-pane.*'-S'.*'-80'" "$LUA"
contains 'dashboard exposes explicit manual replies' "hub_binary().*'send'" "$LUA"
contains 'reply transport targets exact pane IDs' 'send requires an exact pane ID' "$HUB"
contains 'reply transport uses bracket-aware tmux paste buffers' 'paste-buffer -p -d' "$HUB"
contains 'session closure targets immutable session IDs' 'close requires an exact session ID' "$HUB"
contains 'session manager cannot close itself' 'refusing to close the active session manager' "$HUB"
contains 'dashboard confirms selected session closure' 'Running processes in these sessions will stop' "$LUA"
contains 'dashboard supports multi-session cleanup' 'Tab marks multiple' "$LUA"
contains 'dashboard reads tasks through the managed todo wrapper' "'todo', 'ls', '--json'" "$LUA"
contains 'dashboard labels the machine-wide queue' "Global todos" "$LUA"
contains 'dashboard maps task repository metadata to live sessions' "task_token.*repo:" "$LUA"
contains 'dashboard defaults to a compact project overview' "PROJECT OVERVIEW" "$LUA"
contains 'dashboard summarizes stale sessions instead of listing them' "without agents.*X to review" "$LUA"
contains 'dashboard removes task tracking metadata from overview titles' "local function task_title" "$LUA"
contains 'dashboard offers Telescope drilldowns' "require 'telescope.pickers'" "$LUA"
contains 'dashboard refreshes without blocking Neovim' 'vim.system.*dump-json' "$LUA"

self_test=$(TMUX_HUB_NVIM_CONFIG="$ROOT_DIR/nvim" "$HUB" self-test 2>&1)
if [[ "$self_test" == *'22 passed'* ]]; then pass 'Lua parser self-test passes'; else fail "Lua parser self-test passes ($self_test)"; fi

dump=$(TMUX_HUB_NVIM_CONFIG="$ROOT_DIR/nvim" TMUX_HUB_AGENT_TIMER=/does/not/exist TMUX_HUB_SKIP_TODOS=1 "$HUB" dump-json 2>/dev/null)
if jq -e '.summary and (.sessions | type == "array") and (.agents | type == "array") and (.agentGroups | type == "array") and (.approvals | type == "array") and (.todos | type == "array")' <<<"$dump" >/dev/null; then
  pass 'live JSON dump has the dashboard contract'
else
  fail 'live JSON dump has the dashboard contract'
fi

SOCKET="tmux-hub-test-$$"
if hub_window=$(env -u TMUX TMUX_HUB_SOCKET_NAME="$SOCKET" TMUX_HUB_SESSION=hub-test \
  TMUX_HUB_DASHBOARD_COMMAND='sleep 30' TMUX_HUB_NO_SWITCH=1 "$HUB" open "$ROOT_DIR" 2>/dev/null); then
  pass 'open creates a detached hub without requiring an existing client'
else
  fail 'open creates a detached hub without requiring an existing client'
fi
if env -u TMUX tmux -L "$SOCKET" show-environment -t hub-test DOTFILES_TMUX_TEMPLATE 2>/dev/null | rg -q '=skip$'; then
  pass 'created hub session records the template skip environment'
else
  fail 'created hub session records the template skip environment'
fi
if [[ "$(env -u TMUX tmux -L "$SOCKET" show-option -qv -t hub-test @dotfiles_hub 2>/dev/null)" == 1 && "$hub_window" == @* ]]; then
  pass 'created hub session and dashboard window are explicitly marked'
else
  fail 'created hub session and dashboard window are explicitly marked'
fi

env -u TMUX tmux -L "$SOCKET" new-session -d -s reply-test -c "$ROOT_DIR" 'bash --noprofile --norc' >/dev/null 2>&1
reply_pane=$(env -u TMUX tmux -L "$SOCKET" list-panes -t reply-test -F '#{pane_id}' 2>/dev/null)
if printf '%s' "printf 'received:%s\\n' vanilla" \
    | env -u TMUX TMUX_HUB_SOCKET_NAME="$SOCKET" "$HUB" send "$reply_pane" >/dev/null 2>&1; then
  reply_received=false
  for _ in {1..20}; do
    if env -u TMUX tmux -L "$SOCKET" capture-pane -p -t "$reply_pane" 2>/dev/null | rg -q '^received:vanilla$'; then
      reply_received=true
      break
    fi
    sleep 0.05
  done
  if [[ "$reply_received" == true ]]; then
    pass 'manual reply reaches the exact target pane through vanilla tmux'
  else
    fail 'manual reply reaches the exact target pane through vanilla tmux'
  fi
else
  fail 'manual reply reaches the exact target pane through vanilla tmux'
fi

reply_session=$(env -u TMUX tmux -L "$SOCKET" display-message -p -t reply-test '#{session_id}' 2>/dev/null)
if env -u TMUX TMUX_HUB_SOCKET_NAME="$SOCKET" "$HUB" close reply-test >/dev/null 2>&1; then
  fail 'session closure rejects mutable names'
else
  pass 'session closure rejects mutable names'
fi
if env -u TMUX TMUX_HUB_SOCKET_NAME="$SOCKET" "$HUB" close "$reply_session" >/dev/null 2>&1 \
    && ! env -u TMUX tmux -L "$SOCKET" has-session -t reply-test 2>/dev/null; then
  pass 'session closure removes the exact selected session'
else
  fail 'session closure removes the exact selected session'
fi
hub_session=$(env -u TMUX tmux -L "$SOCKET" display-message -p -t hub-test '#{session_id}' 2>/dev/null)
if env -u TMUX TMUX_HUB_SOCKET_NAME="$SOCKET" TMUX_HUB_SESSION=hub-test "$HUB" close "$hub_session" >/dev/null 2>&1; then
  fail 'session closure protects the active manager'
elif env -u TMUX tmux -L "$SOCKET" has-session -t hub-test 2>/dev/null; then
  pass 'session closure protects the active manager'
else
  fail 'session closure protects the active manager'
fi
env -u TMUX tmux -L "$SOCKET" kill-server >/dev/null 2>&1 || true

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
(( FAILED == 0 ))
