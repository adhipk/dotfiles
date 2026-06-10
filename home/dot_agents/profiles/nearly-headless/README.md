# Nearly Headless Profile

Nearly-headless profile: users create agent tasks in a browser workspace,
agents stream progress, and when they need input they create the right
interactive elements in the page. Runtime continuity should be based on
provider sessions.

The app is a standalone TypeScript project expected at
`~/.local/share/nearly-headless`. Dotfiles installs shims and profile docs only.

## Why a separate profile?

Default agent behavior stays unchanged. This profile adds task/artifact surface
conventions and skills that only apply when you opt in.

## Quick start

```bash
# Print profile instructions (paste into agent context or Cursor rule)
nearly-headless print-agents

# Initialize and serve the nearly-headless workspace
nearly-headless init-project
nearly-headless serve start
nearly-headless serve open

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

### Codex

Start Codex through the renderer runner or your preferred provider session and
invoke `$html-artifact` or `$live-doc` for profile skills. Personal skills live in `~/.agents/skills/`.

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
│   ├── headless-html-artifacts.md
│   ├── agent-comms.md
│   ├── hyperclay-patterns.md
│   └── templates/     # HTML shells
└── skills/
    ├── html-artifact/
    └── live-doc/
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
