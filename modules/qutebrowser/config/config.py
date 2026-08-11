"""Chrome-familiar macOS shortcuts layered over qutebrowser defaults."""

# Load UI-written settings first, then keep this checked-in shortcut layer
# authoritative. Native qutebrowser bindings remain enabled.
config.load_autoconfig()


def bind_browser(key, command):
    """Bind a browser-level shortcut while browsing or editing a page."""
    for mode in ("normal", "insert"):
        config.bind(key, command, mode=mode)


# Tabs and windows.
bind_browser("<Meta-n>", "open -w")
bind_browser("<Meta-Shift-n>", "open -p")
bind_browser("<Meta-t>", "open -t")
bind_browser("<Meta-Shift-t>", "undo")
bind_browser("<Meta-w>", "tab-close")
bind_browser("<Meta-Shift-w>", "close")
bind_browser("<Meta-Alt-Right>", "tab-next")
bind_browser("<Meta-Alt-Left>", "tab-prev")
bind_browser("<Meta-Shift-a>", "tab-select")

for tab_number in range(1, 9):
    bind_browser(f"<Meta-{tab_number}>", f"tab-focus {tab_number}")
bind_browser("<Meta-9>", "tab-focus -1")

# Navigation and the address bar.
bind_browser("<Meta-l>", "cmd-set-text -s :open")
bind_browser("<Meta-[>", "back")
bind_browser("<Meta-]>", "forward")
bind_browser("<Meta-r>", "reload")
bind_browser("<Meta-Shift-r>", "reload -f")
bind_browser("<Meta-Shift-h>", "home")

# Keep Command+Arrow available for text editing in insert mode.
config.bind("<Meta-Left>", "back")
config.bind("<Meta-Right>", "forward")

# Search, page actions, and browser surfaces.
bind_browser("<Meta-f>", "cmd-set-text /")
bind_browser("<Meta-g>", "search-next")
bind_browser("<Meta-Shift-g>", "search-prev")
bind_browser("<Meta-p>", "print")
bind_browser("<Meta-s>", "download --mhtml")
bind_browser("<Meta-d>", "bookmark-add")
bind_browser("<Meta-Shift-b>", "bookmark-list --jump")
bind_browser("<Meta-Alt-b>", "bookmark-list --jump")
bind_browser("<Meta-y>", "history")
bind_browser("<Meta-Shift-j>", "download-open --dir")
bind_browser("<Meta-,>", "open -t qute://settings")
bind_browser("<Meta-Alt-u>", "view-source")
bind_browser("<Meta-Alt-i>", "devtools")
bind_browser("<Meta-Alt-j>", "devtools")
bind_browser("<Meta-=>", "zoom-in")
bind_browser("<Meta-Shift-=>", "zoom-in")
bind_browser("<Meta-->", "zoom-out")
bind_browser("<Meta-0>", "zoom")

# Chrome has an extension manager; qutebrowser 3.7 instead exposes userscripts.
bind_browser("<Meta-Shift-e>", "open -t qute://help/userscripts.html")

# Keyboard-first tab management beyond Chrome's standard shortcut set.
config.bind(",ts", "tab-select")
config.bind(",td", "tab-clone")
config.bind(",tp", "tab-pin")
config.bind(",tm", "tab-mute")
config.bind(",to", "tab-only")
config.bind(",tw", "tab-give")
config.bind(",th", "tab-move -")
config.bind(",tl", "tab-move +")
config.bind("<Ctrl-Shift-PgUp>", "tab-move -")
config.bind("<Ctrl-Shift-PgDown>", "tab-move +")

# Userscript/adblock maintenance. Comma-prefix bindings are reserved for local
# customizations by qutebrowser, so these do not shadow native key chains.
config.bind(",eh", "open -t qute://help/userscripts.html")
config.bind(",er", "greasemonkey-reload")
config.bind(",ea", "adblock-update")
config.bind(",eb", "open -t qute://bindings")
config.bind(",ec", "config-source")
