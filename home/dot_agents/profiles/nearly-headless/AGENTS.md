# Nearly Headless Agent Profile

Use this profile for **headless hyperspace work**: agents run in tmux, produce HTML
artifacts instead of chat UI, and notify you when input is needed.

Do **not** apply these defaults to normal interactive coding unless the user
explicitly selects the nearly-headless profile.

## Activation

- Profile root: `~/.agents/profiles/nearly-headless/`
- Run `nearly-headless print-agents` to print this file for Cursor/Codex context.
- Invoke profile skills: `$html-artifact`, `$hyperspace-status`
- Read: `~/.agents/docs/nearly-headless.md`, `~/.agents/docs/hyperclay-patterns.md`

## Core behaviors

1. **No custom frontend** — do not build chat UIs, WebSocket dashboards, or React shells.
2. **HTML over Markdown** for long reports, reviews, plans, and status pages (see Anthropic:
   [Unreasonable Effectiveness of HTML](https://claude.com/blog/using-claude-code-the-unreasonable-effectiveness-of-html)).
3. **Write artifacts to** `<project>/.hyperspace/<slug>.html` (create `.hyperspace/` if missing).
4. **Use templates** from `~/.agents/docs/templates/` — copy shell, fill `#content` only.
5. **HyperClay** for editable pages — follow `~/.agents/docs/hyperclay-patterns.md`.
6. **After writing a report**, tell the user:
   `hyperspace-open-report <slug>` or `open .hyperspace/<slug>.html`
7. **Prefer tmux session + window names** for agent identity (`hs-<project>:codex-main`), not
   Ghostty window titles.

## Output conventions

| Artifact type | Template | Filename example |
|---------------|----------|------------------|
| Task completion | `task-report.html` | `.hyperspace/fix-lint.html` |
| Project/agent status | `status-dashboard.html` | `.hyperspace/status.html` |
| Code/PR review | `review.html` | `.hyperspace/pr-142.html` |
| Approval needed | `decision.html` | `.hyperspace/approve-deploy.html` |

Set `data-project`, `data-agent`, and `data-updated` on `<body>` (templates include placeholders).

## When blocked

1. Write or update a `decision.html` artifact explaining the choice.
2. State clearly: **waiting for user** — include the file path.
3. Do not spin polling loops; the user opens the HTML or returns to the tmux pane.

## Skills (profile-scoped)

| Skill | When |
|-------|------|
| `$html-artifact` | Creating or updating any HTML artifact |
| `$hyperspace-status` | Status dashboard from tmux/project state |

## Related dotfiles

- `hyperspace` CLI — pin/connect tmux sessions (`~/.config/skhd/modules/hyperspace/hyperspace`)
- `hyperspace-open-report` — open `.hyperspace/<slug>.html`
- `nearly-headless` — profile helper commands
- Task list: `~/.agents/profiles/nearly-headless/TASKS.md`
