# Utility ownership inventory

Reusable command implementations live in independent GitHub projects instead
of being copied into this dotfiles repository. Chezmoi clones each checkout
under `~/projects`, the dependency inventory pins its immutable commit, and a
small module owns the conditional `~/bin` links.

| GitHub project | Commands | Dotfiles integration |
| --- | --- | --- |
| [`adhipk/kittentts-cli`](https://github.com/adhipk/kittentts-cli) | `kit`, `kit-watch` | `modules/kit-tts` |
| [`adhipk/tuxedo-project-todo`](https://github.com/adhipk/tuxedo-project-todo) | `todo`, `chezmoi-todo` | `modules/todo` |
| [`adhipk/macos-default-apps`](https://github.com/adhipk/macos-default-apps) | `default-apps` | `modules/macos-default-apps` |
| [`adhipk/gh-create-repo`](https://github.com/adhipk/gh-create-repo) | `gh-create-repo` | `modules/gh-create-repo` |
| [`adhipk/unescape-cli`](https://github.com/adhipk/unescape-cli) | `unescape-buffer`, `unescape-string` | `modules/unescape-cli` |

Each upstream project owns command behavior, release tests, packaging, and its
standalone install/uninstall lifecycle. The dotfiles integration never runs
those installers or creates a second command copy. Module uninstall removes
only ChezMoi-owned links; whole-system uninstall also preserves the useful
project checkouts.

## Remaining parent-owned utilities

The remaining helpers stay in this repository because their boundary crosses a
dotfiles feature or machine-specific runtime:

| Commands | Why they remain coupled | Likely future home |
| --- | --- | --- |
| `man-me` | Resolves ChezMoi source paths, installed paths, and module-owned catalog metadata. | Documentation/catalog module if that source mapping becomes a public adapter. |
| `watch-sync` | Calls the repository's module-lifecycle controller and watches the parent module tree. | Module-lifecycle integration, not an independent plugin. |
| `lucide-icons-excalidraw` | Launches a fixed external Raycast checkout provisioned by this repository. | The Raycast extension/external bundle. |
| `reload-colors` | Coordinates yabai, skhd, tmux, and the active colorscheme. | Desktop service integration after its cross-module reload contract is explicit. |
| `ghostty-startup-bench`, `scratchpads` | Open or inspect Ghostty/yabai windows and share terminal policy. | Terminal or scratchpad vertical modules. |
| `tmux-session-picker`, `tmux-sessionizer*`, `tmux-workspace` | Depend on tmux session and persistence behavior. | Existing tmux vertical-module work. |

Other templates under `home/bin` are parent integration points for existing
modules rather than independent implementation sources.
