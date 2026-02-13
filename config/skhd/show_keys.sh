#!/usr/bin/env bash

# Toggle: if already showing, kill it
if pkill -x whichkey 2>/dev/null; then
    exit 0
fi

# Launch the SwiftUI overlay
~/.config/skhd/whichkey &
