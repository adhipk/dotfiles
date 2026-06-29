# Dotfiles Repository

This repository uses chezmoi. Read `README.md` for the source-state layout and
normal workflows.

## Editing Rules

- Edit desired home files under `home/`.
- Preserve chezmoi attributes such as `dot_`, `executable_`, and `symlink_`.
- Add helper commands under `home/bin/`.
- Add idempotent one-time setup under `home/.chezmoiscripts/` with `run_once_`.
- Declare VSCodium and Chrome extensions in `home/.chezmoidata.toml`.
- Run `make test` and `make diff` after changes.
