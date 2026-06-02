# Dotfiles

Personal macOS setup managed with [chezmoi](https://www.chezmoi.io/).

## Layout

`.chezmoiroot` points chezmoi at `home/`, which declares the desired state of
`$HOME`.

```text
home/
├── .chezmoidata.toml                 # VS Code and Chrome extension inventory
├── .chezmoiexternal.toml.tmpl        # Chrome extension git repositories
├── .chezmoiscripts/                  # Apply hooks and one-time setup scripts
├── bin/                              # Helper commands installed into ~/bin
├── dot_config/
│   ├── skhd/                         # skhd helper scripts
│   ├── yabai/                        # yabai helper scripts
│   ├── yazi/                         # Yazi configuration
│   ├── tmux/                         # tmux configuration
│   └── zsh/                          # zsh support files
├── dot_skhdrc
├── dot_yabairc
├── dot_tmux.conf
└── dot_zshrc
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

Declare VS Code extension IDs and Chrome extension repositories in
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

## One-Time Setup

Add idempotent setup scripts under `home/.chezmoiscripts/` using chezmoi's
`run_once_` naming convention:

```text
home/.chezmoiscripts/run_once_after_setup-example.sh
```

Use `run_onchange_` when a script should run again after its contents change.

## Shell Secrets

`~/.zshrc` sources `~/.zshrc.secrets` when present. Keep machine-specific
values and tokens there. `zshrc.secrets.example` is the repository template.

## Commands

```bash
make test
make diff
make apply
make apply-debug
make watch
make reload
default-apps
```

## Keyboard Shortcuts

- `alt + n`: create a space and focus it
- `alt + shift + ~`: open a Ghostty window in the current space
- `alt + backtick`: focus Ghostty
- `alt + r`: restart yabai and skhd
- `alt + /`: show the keybinding cheat sheet
