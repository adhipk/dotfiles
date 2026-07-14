# Dependency inventory

`dotfiles-deps` is a central aggregation and pin-enforcement layer. Brewfile,
ChezMoi externals/data, TPM declarations, Yazi package data, Neovim's package
lock, module manifests, local Git plugin declarations, and VSCodium extension
declarations remain their own sources of truth. Every inventory/update command
is read-only; only the explicit `pins apply` action changes Git checkouts.

Commands:

- `dotfiles-deps status [--json]` builds the normalized inventory entirely
  offline and joins it to `dependencies.lock.json`. It reports declaration IDs
  missing from the lock and stale lock IDs separately.
- `dotfiles-deps check [--json]` additionally calls existing managers. It uses
  Homebrew inventory plus `brew outdated --json=v2` to refresh installed,
  missing, current, and available states, and compares local Git heads with the
  checked snapshot for ChezMoi and TPM drift. For declared local Git plugins it
  also reads `git status --porcelain` without changing the checkout: a dirty
  tree reports `local-modified`, while a clean declared HEAD reports
  `remote-unchecked`. It does not fetch or contact Git remotes, so
  `remoteStatus` remains `unchecked`, never current. Manager failures remain in
  the JSON report and make the command exit nonzero.
- `dotfiles-deps snapshot --json` emits a deterministic JSON snapshot of local
  installed and resolved versions for review before replacing the checked lock.
  Required-manager inventory failures produce no JSON and exit nonzero. Codium
  is optional for offline `status`, but when VSCodium extensions are declared,
  `snapshot` refuses replacement unless their installed versions can be
  captured. This prevents a partial snapshot from erasing known versions.
  Local Git plugin entries preserve the declared commit as `resolvedVersion`
  and capture the checkout's current HEAD and absolute local path as
  `installedVersion` and `installedPath`. Working-tree modifications are
  intentionally transient check results rather than lock data.
- `dotfiles-deps pins check [--manager chezmoi|tpm] [--json]` verifies the
  immutable Git revisions declared in `home/.chezmoidata.toml`. It ignores
  untracked build artifacts but fails on tracked modifications, missing
  checkouts, or revision drift.
- `dotfiles-deps pins apply [--manager chezmoi|tpm] [--json]` performs only
  clean detached checkouts of commits that already exist locally. It never
  fetches, pulls, or discards tracked changes. A checkout already at the pinned
  revision is a safe no-op even when it contains tracked local work; the result
  reports `current-local-modified` and leaves that work untouched. Revision
  drift plus tracked changes still fails closed. ChezMoi runs the `chezmoi`
  group after applying externals; `install.sh` runs the `tpm` group after TPM
  has installed plugins.

Local Git plugins use standard TOML array tables in `config/sources.toml`:

```toml
[[local_git_plugins]]
id = "awrit"
path = "awrit"
commit = "c692a737bfbfa8c647e03d0a1ab904247ce28ac5"
provides = ["awrit"]
```

`path` is relative to `$HOME`, commits must be immutable 40-character Git
object IDs, and each provided executable can have only one local authority.
When a module requires a provided executable, the inventory folds that module
requirement into the local Git record and retains the module as an owner/source
instead of emitting a misleading second executable dependency.

Homebrew is intentionally marked `rolling`: a Brewfile describes stable package
intent, not a portable promise that arbitrary historical bottles remain
installable. The lock records the exact installed version observed on one
machine for audit and drift visibility; update checks use `brew outdated`.

The inventory, status, check, and snapshot commands never install, upgrade,
check out, or remove dependencies. `pins apply` is the deliberately explicit
exception: it enforces already-declared local Git revisions without network
access.
`config/sources.toml` is the only parent-path adapter, so removing this folder
and its thin `home/bin` bridge does not alter any package manager.
The bridge supplies the checked-out source root; standalone invocations may set
`DOTFILES_DIR` explicitly.

When ChezMoi installs TPM itself and tmux also declares TPM as a plugin, the
inventory emits one target authority with both declaration sources and owners;
it does not double-count the checkout. Exact pins from standard ChezMoi TOML
data are compared directly with the checked resolution so declaration changes
surface as drift before any checkout occurs.

ChezMoi `git-repo` externals and TPM natively manage clones and branch/tag
updates, but do not provide a portable arbitrary-commit lock for every checkout.
The small pin lifecycle is the necessary adapter: the managers still own
installation, while it only verifies or detaches clean repositories to the
declared commit.
