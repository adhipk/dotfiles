# Nearly Headless Hyperspaces

Headless coding agents: run in tmux, report via HTML, notify when stuck. No custom chat frontend.

## Architecture

```text
tmux + sesh          → session/window runtime
hyperspace CLI       → pin, connect, (future: agent lifecycle)
HTML + HyperClay     → presentation layer
nearly-headless      → agent profile + skills + templates
```

Inspired by [t3code](https://github.com/pingdotgg/t3code) session abstractions, without its UI.
HTML output follows [Anthropic's HTML guidance](https://claude.com/blog/using-claude-code-the-unreasonable-effectiveness-of-html).

## Profile

| Item | Path |
|------|------|
| Profile instructions | `~/.agents/profiles/nearly-headless/AGENTS.md` |
| Task list | `~/.agents/profiles/nearly-headless/TASKS.md` |
| Templates | `~/.agents/docs/templates/` |
| Skills | `$html-artifact`, `$hyperspace-status` |

Activate: `nearly-headless print-agents` — does not alter default `~/.agents/AGENTS.md`.

## Project layout

```text
my-project/
├── .hyperspace/
│   ├── shared/hyperspace.css
│   ├── status.html
│   └── task-report.html
└── .gitignore          # include .hyperspace/ (see templates/gitignore-snippet)
```

## Commands

```bash
nearly-headless info              # paths and activation help
nearly-headless print-agents      # cat profile AGENTS.md
nearly-headless tasks             # show TASKS.md
hyperspace-open-report status     # open .hyperspace/status.html
```

## Agent workflow

1. User starts agent in tmux (`hs-<project>` session).
2. Agent uses `$html-artifact` to write `.hyperspace/<slug>.html`.
3. Agent tells user: `hyperspace-open-report <slug>`.
4. If blocked, agent writes `decision.html` and waits.
5. User edits in browser (HyperClay) or replies in tmux.

## Related files in this repo

- `home/dot_agents/profiles/nearly-headless/` — profile
- `home/bin/executable_nearly-headless` — CLI
- `home/bin/executable_hyperspace-open-report` — open artifacts
- `hyperspaces.md` — backend architecture notes
- `plan.md` — planned tmux/skhd work

See `TASKS.md` for implementation checklist.
