# Planned changes

This document tracks **future** behaviors and ergonomics. For migration and
extraction status, see [MIGRATION.md](MIGRATION.md). For product build
checklists, see
[home/dot_agents/profiles/nearly-headless/TASKS.md](home/dot_agents/profiles/nearly-headless/TASKS.md).

## Migration summary

| Area | Status | Details |
| --- | --- | --- |
| Chezmoi layout | Done | `home/` source state since `try to migrate` |
| Nearly-headless Phase 1 | Done | Profile, templates, skills, shims |
| Nearly-headless Phase 2 | Partial | Serve/live-doc done; provider backend pending |
| Tmux/sesh workspace manager | Dropped | Removed — see `MIGRATION.md` § Dropped |
| External extraction | In progress | See [EXTERNAL-PROJECTS.md](EXTERNAL-PROJECTS.md) |
| Agent-comms | Prototype only | `extensions/gemma-gem/agent-comms/` |
| Gemma-gem fork | Pending | Chezmoi points at upstream kessler repo |

## nearly-headless

Task checklist: `home/dot_agents/profiles/nearly-headless/TASKS.md`

- [x] Agent profile `nearly-headless` under `home/dot_agents/profiles/`
- [x] HTML templates + HyperClay patterns in `home/dot_agents/docs/templates/`
- [x] Skills `$html-artifact`, `$live-doc`
- [x] `nearly-headless` and `hyperspace-open-report` commands
- [x] `nearly-headless serve` localhost :4200 workspace for repo `.hyperspace/`
- [x] Workspace discovers configured/current repos without tmux sessions
- [ ] Provider-session task backend and settings page
- [ ] Task progress streaming and app-owned comments/actions

## agent-comms + gemma-gem

- [ ] Create `adhipk/agent-comms` repo from `extensions/gemma-gem/agent-comms/`
- [ ] Register agent-comms in `.chezmoidata.toml` + add shim
- [ ] Fork `kessler/gemma-gem` and point Chrome external at fork
- [ ] Wire gemma-gem and nearly-headless to agent-comms adapters

See [MIGRATION.md](MIGRATION.md) and `home/dot_agents/docs/agent-comms.md`.

## quick terminal (scratchpad) window

- Launch with tmux
- automatically close (find out how scratchpads do this)
- Custom terminal windows as scratchpad, usecase (open dotfiles repo with codex, tell it to fix something, quit. tmux preserves session, alert when fixed)

## workspace organization

- at any given time I will have like 5-10 active terminal windows
- background servers can be launched and attached to tmux using `daemon`
- yabai spaces + app focus shortcuts are the primary organization layer

## define space templates, tied to a project (dev-space)

`` $ dev-space new ~/project``
creates a new space.
creating new terminals are automatically cded to that folder,
opening cursor automatically uses that one.
no cycling between dev-spaces.
idea is to isolate all the programs related to a project in one place.
idk if space is the right primitive but we create a container for all

## daemon raycast manager like https://www.raycast.com/lucaschultz/port-manager

I want to manage running daemons I launched easily

Add tail-f watchers for all the services of dotfile logs, and add timestamps
# Source - https://superuser.com/a/1182270
# Posted by David Ongaro
# Retrieved 2026-06-02, License - CC BY-SA 3.0

tail -f outputfile | xargs -IL date +"%Y%m%d_%H%M%S:L"
