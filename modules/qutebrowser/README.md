# qutebrowser

This module keeps qutebrowser's default Vim-style bindings and adds the
familiar macOS Chrome layer on top. Browser-level Command shortcuts are active
in normal and insert modes; command/prompt editing and passthrough mode keep
their native behavior.

## Familiar layer

| Shortcut | Action |
| --- | --- |
| `Cmd+T` / `Cmd+Shift+T` | New tab / reopen closed tab |
| `Cmd+W` / `Cmd+Shift+W` | Close tab / close window |
| `Cmd+N` / `Cmd+Shift+N` | New window / private window |
| `Cmd+Option+Left/Right` | Previous / next tab |
| `Cmd+1..8` / `Cmd+9` | Select numbered / last tab |
| `Cmd+Shift+A` | Search all tabs |
| `Cmd+L` | Focus the URL/search command |
| `Cmd+[` / `Cmd+]` | Back / forward |
| `Cmd+R` / `Cmd+Shift+R` | Reload / reload without cache |
| `Cmd+F`, `Cmd+G`, `Cmd+Shift+G` | Find / next / previous result |
| `Cmd+D` | Bookmark the page |
| `Cmd+Shift+B` or `Cmd+Option+B` | Open bookmarks |
| `Cmd+Y` | Open history |
| `Cmd+Shift+J` | Open the last download's folder |
| `Cmd+,` | Open qutebrowser settings |
| `Cmd+Option+I/J` | Toggle developer tools |
| `Cmd+Option+U` | View page source |
| `Cmd+Shift+E` | Open userscript documentation |

qutebrowser 3.7 reports loaded Chromium WebExtensions but does not officially
support installing arbitrary Chrome extensions. Its supported extension points
are userscripts, Greasemonkey scripts, and the built-in ad blocker.

## Keyboard-first additions

- `,ts` search tabs; `,td` duplicate; `,tp` pin; `,tm` mute; `,to` close other tabs.
- `,tw` detach the tab; `,th` / `,tl` move it left / right.
- `,eh` userscript help; `,er` reload userscripts; `,ea` update adblock lists.
- `,eb` show every binding; `,ec` reload this configuration.

The source is `config/config.py`; ChezMoi installs it at
`~/.qutebrowser/config.py`. UI settings are loaded first, so this shortcut
layer remains authoritative while other changes made through `:set` persist.
