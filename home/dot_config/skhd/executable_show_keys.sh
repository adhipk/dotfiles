#!/usr/bin/env bash
# man-me: name=show_keys.sh
# man-me: category=Desktop Helper Paths
# man-me: usage=~/.config/skhd/show_keys.sh
# man-me: description=Toggle the skhd whichkey keybinding overlay.
# man-me: tags=hotkeys hotkey keyboard shortcut shortcuts keybinding keybindings skhd whichkey keys
# man-me: name=whichkey
# man-me: source=home/dot_config/skhd/executable_whichkey
# man-me: category=Desktop Helper Paths
# man-me: usage=~/.config/skhd/whichkey
# man-me: description=Compiled SwiftUI keybinding overlay launched by show_keys.sh.
# man-me: tags=hotkeys hotkey keyboard shortcut shortcuts keybinding keybindings skhd whichkey keys

# Toggle: if already showing, kill it
if pkill -x whichkey 2>/dev/null; then
    exit 0
fi

# Launch the SwiftUI overlay
~/.config/skhd/whichkey &
