# Agent Notes

## Key Bindings (skhd)
- `alt + n` creates a new space and focuses it.
- `alt + backtick` and `alt + ~` focus Ghostty (app focus shortcut).

## Terminal Defaults
- `home/dot_config/skhd/executable_open_terminal_window.sh` defaults to Ghostty.

## Chezmoi
- `.chezmoiroot` points to `home/`, the desired state for `$HOME`.
- `install.sh` applies the source state with chezmoi.
- Add helper commands under `home/bin/` with the `executable_` attribute.
- Add one-time setup scripts under `home/.chezmoiscripts/` with a `run_once_` prefix.
- Add personal agent defaults under `home/dot_agents/`; chezmoi applies this to `~/.agents/`.

## Keycode Note
- The tilde binding uses keycode `0x32` in `home/dot_skhdrc` for reliability.

## Hyperspace live doc

Generative UI canvas — not chat. Edit `.hyperspace/livedoc.html` with `<hs-*>` web components. Registry: `~/.config/hyperspaces/components/`.

When `.hyperspace/live-doc.json` has `"pending": true` or `"status": "running"`:

1. Read `.hyperspace/livedoc.html` — canvas in `<main class="live-doc-canvas">`.
2. Edit the canvas: `<hs-callout>`, `<hs-finding>`, plain HTML, inline scripts. No build step.
3. Set `"pending": false` and `"status": "done"` in `.hyperspace/live-doc.json` when finished.

Save in the browser triggers `codex exec`. Preview: `http://127.0.0.1:4200/<route>/preview/`.
