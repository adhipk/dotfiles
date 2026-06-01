#!/usr/bin/env bash
# tmux-sessionizer wrapper that uses zoxide for directory selection
# This provides frecency-based directory selection (directories you visit most/recently)

# Get directories from zoxide (sorted by frecency)
zoxide_dirs=$(zoxide query --list 2>/dev/null)

# Get existing tmux sessions
if [[ -n "${TMUX}" ]]; then
    current_session=$(tmux display-message -p '#S')
    tmux_sessions=$(tmux list-sessions -F "[TMUX] #{session_name}" 2>/dev/null | grep -vFx "[TMUX] $current_session")
else
    tmux_sessions=$(tmux list-sessions -F "[TMUX] #{session_name}" 2>/dev/null)
fi

# Combine both sources
combined=$(echo -e "${tmux_sessions}\n${zoxide_dirs}" | grep -v '^$')

# Use fzf to select
selected=$(echo "$combined" | fzf --height 40% --reverse --border)

if [[ -z $selected ]]; then
    exit 0
fi

# If it's a tmux session, switch to it
if [[ $selected == "[TMUX] "* ]]; then
    session_name=${selected#"[TMUX] "}
    if [[ -z $TMUX ]]; then
        tmux attach-session -t "$session_name"
    else
        tmux switch-client -t "$session_name"
    fi
    exit 0
fi

# Otherwise, pass the directory to tmux-sessionizer
exec tmux-sessionizer "$selected"
