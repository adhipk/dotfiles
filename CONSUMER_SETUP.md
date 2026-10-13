# Consumer desktop setup

The standalone `Dotfiles.app` includes the native host, CLI, service supervisor,
and Markdown Clipboard with Pandoc 3.12.1. Other catalog utilities connect to
the desktop and terminal tools installed by the consumer profile. All desktop
and terminal capabilities remain in scope for 1.0; the app alone does not install
the entire environment.

From a downloaded source checkout on macOS, first review the installation plan:

```sh
./bootstrap --consumer
./bootstrap --consumer --prepare /tmp/dotfiles-consumer-review
```

Preparation makes a separate source tree for inspection and does not install
software or change your account. The profile installs public utility repositories
over HTTPS at their checked-in commit pins. Setup grants Homebrew trust only to
the yabai, skhd and borders formulae declared in the plan; it does not trust whole
third-party taps. It omits personal browser/editor
extensions, private Raycast integration, and personal agent guidance. Default
app slots use Finder and Notes instead of work applications. The assistant tmux
slot opens a shell until agents are explicitly selected.

Installation changes your shell, editor, terminal, shortcuts and desktop settings.
It requires Xcode command-line tools and a Python 3 runtime, and provisions
Homebrew plus the complete desktop utility dependencies. Read the plan first:

```sh
./bootstrap --consumer --apply
```

Add `--agents` to include Codex and shared agent guidance, and `--work-apps` to
install Teams and Slack with the corresponding app slots. Credentials and sign-in
remain separate. No credentials are bundled or copied from the author.

The prepared source lives in `~/.local/share/dotfiles-consumer/source`. Its
`consumer-state.json` records preparation, installation, failure or completion.
Each successful bootstrap also writes `consumer-doctor.json`. Missing required
commands/apps or failed service probes set `degraded`; passing probes set
`installed-needs-acceptance` while manual permissions and desktop behavior remain
pending. The doctor command exits nonzero for detected failures and never calls
unknown approvals healthy.
Doctor reports `not-installed`, `prepared`, or `failed` when the consumer profile
has no completed installation record, even if personal tools already exist.
Mandatory doctor failures make installation exit unsuccessfully; an update with
those failures restores and reapplies the prior source. Interrupted preparation
directories are retained in `history` under the setup lock so installation or
update can be retried without deleting partial work. `--recover` also handles
those preparations before activation starts.
After an interrupted installation, rerun with the original selection flags:

```sh
./bootstrap --consumer --resume
./bootstrap --consumer --doctor
```

Resume refuses changed selections and preserves the existing source. Reapplying
the existing setup uses Chezmoi and the upstream dependency managers rather than
running standalone utility installers. The doctor reports missing commands and
read-only probes; it does not grant permissions or establish desktop acceptance.

To update from a newer downloaded checkout, run `./bootstrap --consumer --update`.
The candidate inherits your module enablement and preferences. The previous source
is retained for `./bootstrap --consumer --rollback`. Source transitions are
journaled: `./bootstrap --consumer --recover` (or `--resume`) restores and reapplies
the original source after interruption. A failed update automatically attempts
that restoration. Homebrew packages, downloaded voice models and external utility
effects are not rolled back; the lifecycle journal records this boundary. Failed
and older sources are retained under the profile's `history` directory.
Rollback keeps current preferences and module enablement when both source schemas
have the same setting groups. When those schemas differ, it explicitly restores
the prior settings snapshot and retains the replaced current source. Resume checks
the original agent/work application selections and executes the saved source;
new dependency declarations in a later checkout do not prevent retrying it.

Grant Accessibility to yabai, skhd and Ghostty, and approve Karabiner's DriverKit
extension and Input Monitoring. Full Space scripting requires the explicit yabai
SIP setup and `setup-yabai-sa`; the installer does not change SIP. Allow desktop
notifications when prompted. Kit downloads voice models on first use. Enable
native utility actions and clipboard monitoring explicitly in the app.

Clean-device desktop behavior, upgrades, uninstall, external utility licensing,
and Pandoc complete corresponding-source compliance remain required release
evidence. Local generation tests and build success do not satisfy those checks.
