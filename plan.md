# Planned changes
This document tracks changes and behaviors I want to add to the dotfiles.

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

## hyperspace

- [x] tmux/sesh hyperspace runtime (phase 2 in TASKS.md)
- [x] `hyperspace` default path is tmux workspace only
- [ ] hyperspace watch + notification paths (phase 3 in TASKS.md)

## quick terminal (scratchpad) window.
 - Launch with tmux
 - automatically close (find out how scratchpads do this)
 - Custom terminal windows as scratchpad, usecase (open dotfiles repo with codex, tell it to fix something, quit. tmux preserves session, alert when fixed)


## tmux commands
- easily look through open vindows,
- close unused sessions/windows.
- figure out whats the difference between windows and sessions, where each abstraction works best.

## hyperspaces (tmux sessions + fixed app set)
- Create project-specific session groups called hyperspaces.
- Each hyperspace should map to:
  - 1 bare terminal window (primary tmux session shell)
  - 1 text editor window
  - 1 Chrome window
  - 1 coding agent window
- Use a pinned map for fast switching:
  - `hyper + number` jumps to pinned hyperspace slot (1-9).
  - `hyper + '+'`, then number pins current tmux session into slot.
  - `hyper + '-'`, then number removes pinned hyperspace from slot.
  - `hyper + space` opens sesh search filtered for hyperspaces (Raycast extension once configured).
- Build `home/bin/executable_hyperspace` as the controller for pinning/search/connect operations backed by a config file at `~/.config/sesh/hyperspaces.json`.

## opt ~ to cycle through all terminal sessions too broad
- at any given time I will have like 5-10 active terminal windows.
- background servers and such can be launched and attached to tmux using our `daemon`
- however for active windows, (mostly codex, claude, etc) I need better organization


## define space templates, tied to a project. (dev-space)

`` $ dev-space new ~/project``
creates a new space.
creating new terminals are automatically cded to that folder,
opening cursor automatically uses that one.
no cycling between dev-spaces.
idea is to isolate all the programs related to a project in on place.
idk if space is the right primative but we create a container for all 

can use its own tmux session? with windows?



## daemon raycast manager like https://www.raycast.com/lucaschultz/port-manager
    I want to manage running daemons I launched easily

    Add tail-f watchers for all the services of dotfile logs, and add timestamps
# Source - https://superuser.com/a/1182270
# Posted by David Ongaro
# Retrieved 2026-06-02, License - CC BY-SA 3.0

tail -f outputfile | xargs -IL date +"%Y%m%d_%H%M%S:L"


