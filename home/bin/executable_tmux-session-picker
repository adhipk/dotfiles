#!/usr/bin/env bash
# Quick picker to switch between existing tmux sessions only

# Get existing tmux sessions (excluding current)
if [[ -n "${TMUX}" ]]; then
    current_session=$(tmux display-message -p '#S')
    sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -vFx "$current_session")
else
    sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
fi

if [[ -z "$sessions" ]]; then
    echo "No other tmux sessions found"
    exit 0
fi

# Use fzf to select
selected=$(echo "$sessions" | fzf --height 40% --reverse --border --prompt="Switch to session: ")

if [[ -z $selected ]]; then
    exit 0
fi

# Switch to the selected session
if [[ -z $TMUX ]]; then
    tmux attach-session -t "$selected"
else
    tmux switch-client -t "$selected"
fi
