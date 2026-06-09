# Nearly Headless Profile

Headless agent runtime: tmux + sesh for sessions, HTML + HyperClay for presentation.

## Why a separate profile?

Default agent behavior stays unchanged. This profile adds HTML artifact conventions,
hyperspace integration, and skills that only apply when you opt in.

## Quick start

```bash
# Print profile instructions (paste into agent context or Cursor rule)
nearly-headless print-agents

# Open an agent-written report in the default browser
hyperspace-open-report status
hyperspace-open-report status --project ~/dotfiles

# Show profile paths and task list
nearly-headless info
nearly-headless tasks
```

## Activating in agents

### Cursor

Add a project rule or paste `nearly-headless print-agents` into context when starting a
headless session. Point the agent at `~/.agents/profiles/nearly-headless/AGENTS.md`.

### Codex (tmux)

Start Codex in a hyperspace tmux window and invoke `$html-artifact` or
`$hyperspace-status` for profile skills. Personal skills live in `~/.agents/skills/`.

### Claude Code

Reference this profile in `CLAUDE.md` only for projects using headless mode — do not
merge into the repo root `CLAUDE.md` unless the whole project is nearly-headless.

## Layout

```text
~/.agents/
├── profiles/nearly-headless/
│   ├── AGENTS.md      # profile instructions
│   ├── README.md      # this file
│   └── TASKS.md       # implementation checklist
├── docs/
│   ├── nearly-headless.md
│   ├── hyperclay-patterns.md
│   └── templates/     # HTML shells
└── skills/
    ├── html-artifact/
    └── hyperspace-status/
```

## Project output

Each project should use:

```text
<project>/.hyperspace/
├── status.html
├── task-report.html
└── ...
```

Add `.hyperspace/` to the project `.gitignore` (see `docs/templates/gitignore-snippet`).
