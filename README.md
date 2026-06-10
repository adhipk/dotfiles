# Dotfiles

Personal macOS setup managed with [chezmoi](https://www.chezmoi.io/).

## Layout

`.chezmoiroot` points chezmoi at `home/`, which declares the desired state of
`$HOME`. The repository-level `nvim/` directory is linked into
`~/.config/nvim` so edits remain live in the checkout.

```text
home/
├── .chezmoidata.toml                 # VS Code, Chrome, and external project inventory
├── .chezmoiexternal.toml.tmpl        # External git repositories
├── .chezmoiscripts/                  # Apply hooks and one-time setup scripts
├── bin/                              # Helper commands installed into ~/bin
├── dot_agents/                       # Personal agent skills and docs -> ~/.agents
├── dot_config/
│   ├── symlink_nvim.tmpl              # ~/.config/nvim -> repository nvim/
│   ├── karabiner/                     # Caps Lock hyper key configuration
│   ├── skhd/                         # skhd helper scripts
│   ├── yabai/                        # yabai helper scripts
│   ├── yazi/                         # Yazi configuration
│   ├── tmux/                         # tmux configuration
│   └── zsh/                          # zsh support files
├── dot_skhdrc
├── dot_yabairc
├── dot_tmux.conf
└── dot_zshrc

nvim/                                 # Neovim configuration linked into ~/.config
```

## Setup

On this checkout:

```bash
./bootstrap.sh
```

`bootstrap.sh` installs Homebrew dependencies from `Brewfile`, including
chezmoi, and applies this repository with `./install.sh`.

On another Mac, chezmoi can clone and apply the repository directly:

```bash
chezmoi init --apply git@github.com:adhipk/dotfiles.git
```

Review and apply local changes with:

```bash
chezmoi -S "$PWD" diff
chezmoi -S "$PWD" apply
```

After the repository is installed in chezmoi's default source directory, the
normal update command is:

```bash
chezmoi update -v
```

## Extensions

Declare VS Code extension IDs, Chrome extension repositories, and reusable
external project repositories in
`home/.chezmoidata.toml`.

VS Code extensions are installed through the `code` CLI whenever the declared
list changes. Extra locally installed extensions are left alone.

Chrome extension source repositories are cloned into
`~/.local/share/chrome-extensions/` as chezmoi `git-repo` externals. They are
built locally during bootstrap and rebuilt when their Git revision changes.
Nothing is published. For unpacked extensions such as `gemma-gem`, enable
developer mode in `chrome://extensions` and load:

```text
~/.local/share/chrome-extensions/gemma-gem/.output/chrome-mv3-dev
```

Chrome requires this unpacked-extension approval in the browser.

Reusable scripts and apps that have grown beyond dotfile snippets are declared
as `externalProjects`. Chezmoi clones each project to its declared path as a
`git-repo` external. During bootstrap, the generic external-project hook checks
required executables, runs the declared setup commands when the Git revision
changes, and reruns setup if declared generated paths are missing.

The Lucide Excalidraw Raycast project is expected at:

```text
~/.local/share/raycast-extensions/raycast-lucide-excalidraw
```

## One-Time Setup

Add idempotent setup scripts under `home/.chezmoiscripts/` using chezmoi's
`run_once_` naming convention:

```text
home/.chezmoiscripts/run_once_after_setup-example.sh
```

Use `run_onchange_` when a script should run again after its contents change.

## Agent Defaults

Personal agent behavior is checked in under `home/dot_agents/`, which chezmoi
applies to `~/.agents/`. Use `home/dot_agents/skills/` for personal Codex
skills and `home/dot_agents/docs/` for centralized agent-readable
documentation.

Optional **nearly-headless** profile (`home/dot_agents/profiles/nearly-headless/`)
for headless tmux agents that produce HTML artifacts instead of a chat UI.
Activate with `nearly-headless print-agents`; open reports with
`hyperspace-open-report <slug>`. See `home/dot_agents/docs/nearly-headless.md`.

## Shell Secrets

`~/.zshrc` sources `~/.zshrc.secrets` when present. Keep machine-specific
values and tokens there. `zshrc.secrets.example` is the repository template.

## Commands

See [COMMANDS.md](COMMANDS.md) for the complete command, script, utility, and
shortcut reference.

```bash
make test
make diff
make apply
make apply-debug
make watch
make reload
default-apps
default-apps list
default-apps get .md
default-apps set .md Obsidian
default-apps set https: Safari
default-apps --help
```

`default-apps` prints macOS handlers and changes extension or URL-scheme
defaults. The app argument may be an application name, application path, or
bundle ID.

## Keyboard Shortcuts

- tap `caps lock`: toggle Caps Lock
- hold `caps lock`: send `ctrl + opt + cmd`
- `alt + n`: create a space and focus it
- `alt + backtick` / `alt + ~`: focus Ghostty, skipping task windows titled like `nvim`, `vim`, `codex`, `claude`, or Codex's `Action Required` status
- `alt + r`: restart yabai and skhd
- `alt + /`: show the keybinding cheat sheet
- `hyper + d`: defuddle the URL in the clipboard into readable HTML, keeping original CSS links, save it to `~/Downloads/defuddled-pages`, copy it, and open it

Hyperspace hyper bindings (`hyper+1-9` connect, `hyper++` pin, `hyper+-` unpin,
`hyper+space` search) are in `home/dot_skhdrc`. The `hyperspace` command
(`home/bin/executable_hyperspace`) manages tmux sessions and agents.
