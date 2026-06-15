# Nearly-Headless

Nearly-headless is a browser workspace for sending tasks to coding agents
without staying in a terminal chat. The user creates tasks, sends them to
provider sessions, watches streamed progress, and responds through interactive
surfaces the agent creates when it needs input.

Implementation boundary: nearly-headless is a standalone TypeScript app in its
own repository. **Product behavior (UI, server, defaults) lives in that repo**
 — see `~/.local/share/nearly-headless/SETUP.md`. Dotfiles only installs local
shims, profile docs, and machine-specific wiring (`~/.config/nearly-headless/`).

Repository:

```text
git@github.com:adhipk/nearly-headless.git
```

Expected checkout:

```text
~/.local/share/nearly-headless
```

Expected compiled binary:

```text
~/.local/share/nearly-headless/bin/nearly-headless
```

Product thesis: nearly-headless is an HTML-first agent workspace, not chat with
components. See `nearly-headless-product.md`.

## Architecture

```text
task workspace      → app-owned shell for tasks, progress, artifacts, approvals
provider sessions   → native provider conversation/session continuity
artifact surfaces   → agent-authored UI for reports, forms, dashboards, tools
settings            → provider/model/project configuration
runner adapter      → Codex/Claude/OpenAI/mock providers
```

Inspired by [t3code](https://github.com/pingdotgg/t3code) session abstractions, without its UI.
Implementation plan: `nearly-headless-port-plan.md` (port patterns, not the t3 server).
HTML output follows [Anthropic's HTML guidance](https://claude.com/blog/using-claude-code-the-unreasonable-effectiveness-of-html).
The local dotfiles source includes a captured copy at
`articles/Unreasonable-Effectiveness-of-HTML.html`.

## HTML Interaction Model

Nearly-headless should treat HTML as the durable interaction surface, not just
as a prettier report format.

- The app shell is stable and app-owned: tasks, settings, provider selection,
  session state, progress, approvals, comments, and navigation.
- Agent-authored HTML is scoped to task/artifact surfaces. It can be a report,
  explainer, form, comparison grid, visual diff, dashboard, simulator, or
  one-off editor.
- When the agent needs input, it should produce a concrete control in the page:
  a form, checklist, selector, draggable board, editor, slider, or other
  task-specific UI.
- User interaction must round-trip into the provider session as structured
  state, a prompt fragment, JSON, a diff, or a selected option. The browser
  should not require users to hand-edit generated HTML.
- Generated surfaces should remain useful without reading the transcript.

Project split:

- `headless-html-artifacts.md` — nearly-headless product notes
- `agent-comms.md` — planned cross-tool event bus (prototype only)

Migration status: `MIGRATION.md` in the dotfiles repository.

## Profile

| Item | Path |
|------|------|
| Profile instructions | `~/.agents/profiles/nearly-headless/AGENTS.md` |
| Task list | `~/.agents/profiles/nearly-headless/TASKS.md` |
| Templates | `~/.agents/docs/templates/` |
| Skills | `$html-artifact`, `$live-doc` |

Activate: `nearly-headless print-agents` — does not alter default `~/.agents/AGENTS.md`.

## Project layout

```text
my-project/
├── .hyperspace/
│   ├── shared/                 # copied from nearly-headless on init
│   ├── status.html             # agent artifacts (no default livedoc)
│   └── task-report.html
└── .gitignore                  # include .hyperspace/ (see templates/gitignore-snippet)
```

General setup: `~/.local/share/nearly-headless/SETUP.md` after chezmoi installs the external checkout.

## Commands

```bash
nearly-headless info              # paths and activation help
nearly-headless print-agents      # cat profile AGENTS.md
nearly-headless tasks             # show TASKS.md
hyperspace-serve start            # compatibility server command
nearly-headless init-project      # .hyperspace/shared/ only in current repo
nearly-headless serve start       # http://127.0.0.1:4200 — All projects hub at /
nearly-headless serve open        # browser -> task/artifact workspace
hyperspace-open-report status     # compatibility artifact opener
```

Local server: `/dotfiles/` renders the app-owned workspace plus
`.hyperspace/live-doc.html` task/artifact surfaces. Users create tasks, add
comments, or fill generated inputs; saves/commands dispatch provider turns.

## Agent workflow

1. User creates a task in the browser workspace (app shell).
2. Nearly-headless dispatches the task to a provider session (worker agent).
3. The app streams worker progress and runtime events.
4. The **manager agent** updates HTML artifacts on milestones — not the worker.
5. If input is needed, the manager surfaces controls in the page (or worker
   requests approval through the provider; manager reflects it in the UI).
6. User steers via the page; nearly-headless routes structured input back to
   the selected worker session(s).

## Related files in this repo

- `home/dot_agents/profiles/nearly-headless/` — profile
- `home/bin/executable_nearly-headless` — shim into standalone app
- `home/bin/executable_hyperspace-serve` — compatibility alias for `nearly-headless serve`
- `home/bin/executable_hyperspace-open-report` — compatibility alias for `nearly-headless open`
- `home/bin/executable_headless-artifacts` — compatibility alias for `nearly-headless`
- `home/.chezmoidata.toml` — declares the external `nearly-headless` checkout
- `MIGRATION.md` — migration status dashboard
- `EXTERNAL-PROJECTS.md` — extraction workflow
- `plan.md` — future ergonomics not tied to extraction

See `TASKS.md` for implementation checklist.
