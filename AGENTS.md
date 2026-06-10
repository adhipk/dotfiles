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
- Tools that outgrow dotfiles become external projects; see [EXTERNAL-PROJECTS.md](EXTERNAL-PROJECTS.md).

## Keycode Note
- The tilde binding uses keycode `0x32` in `home/dot_skhdrc` for reliability.

## Hyperspace live doc

Generative UI canvas — not chat. Edit `.hyperspace/livedoc.html` as an
agent-authored HTML workspace: use the representation that best conveys the
work, whether that is prose, a structured report, a diagram, a dashboard, a
small interactive tool, custom elements, inline scripts, or existing `<hs-*>`
web components. Registry: `~/.config/hyperspaces/components/`.
Browser users interact with generated UI and attach comments; they do not
hand-edit the full canvas. If input is needed, generate a text box, form, or
other explicit input surface in the artifact. The live-doc shell also has a
default message box; when it is focused, user clicks on artifact elements insert
DOM identifiers that the agent should resolve from the saved HTML.

When `.hyperspace/live-doc.json` has `"pending": true` or `"status": "running"`:

1. Read `.hyperspace/livedoc.html` — canvas in `<main class="live-doc-canvas">`.
2. Edit the canvas with valid, balanced HTML. Existing `<hs-callout>`,
   `<hs-finding>`, and related components are scaffolding; invent task-specific
   markup/CSS/JS when it is more helpful. No build step.
3. Set `"pending": false` and `"status": "done"` in `.hyperspace/live-doc.json` when finished.

Save in the browser triggers `codex exec`. Preview: `http://127.0.0.1:4200/<route>/preview/`.
