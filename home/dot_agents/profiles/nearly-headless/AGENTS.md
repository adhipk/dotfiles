# Nearly Headless Agent Profile

Use this profile for **nearly-headless agent tasks**: users create tasks in a
browser workspace, agents stream progress, and when input is needed the agent
creates explicit interactive UI in the page. Runtime continuity should come
from provider sessions, not external terminal/session managers.

Do **not** apply these defaults to normal interactive coding unless the user
explicitly selects the nearly-headless profile.

## Activation

- Profile root: `~/.agents/profiles/nearly-headless/`
- Run `nearly-headless print-agents` to print this file for Cursor/Codex context.
- Invoke profile skills: `$html-artifact`, `$live-doc`
- Read: `~/.agents/docs/nearly-headless.md`, `~/.agents/docs/html-artifacts.md`,
  `~/.agents/docs/headless-html-artifacts.md`

## Core behaviors

1. **Respect the app shell** — do not rewrite app-owned navigation, settings,
   task lists, comments, approvals, or progress UI.
2. **Build task-specific surfaces** when the user needs more than prose:
   forms, choice sets, checklists, tables, inspectors, dashboards, diagrams,
   or small tools.
3. **HTML over Markdown** for long reports, reviews, plans, and status pages (see Anthropic:
   [Unreasonable Effectiveness of HTML](https://claude.com/blog/using-claude-code-the-unreasonable-effectiveness-of-html)).
4. **Write artifacts to** `<project>/.hyperspace/<slug>.html` (create `.hyperspace/` if missing).
5. **Use templates + components** from `~/.agents/docs/templates/` as scaffolding,
   then invent task-specific HTML/CSS/JS when it communicates the work better.
6. **Interaction** via HTML (`<details>`, inline JS, components, local custom
   elements, small tools) — not a separate UI framework.
7. **Round-trip user choices** back to the provider session as structured state,
   prompt text, selected options, saved annotations, or diffs. Do not require
   hand-editing generated HTML.
8. **After writing a report**, tell the user:
   `hyperspace-open-report <slug>` or `open .hyperspace/<slug>.html`
9. **Runtime identity is provider-session based**. Prefer provider id, project id,
   and provider session id.

## Output conventions

| Artifact type | Template | Filename example |
|---------------|----------|------------------|
| Task completion | `task-report.html` | `.hyperspace/fix-lint.html` |
| Project/agent status | `status-dashboard.html` | `.hyperspace/status.html` |
| Code/PR review | `review.html` | `.hyperspace/pr-142.html` |
| Exploration | `exploration.html` | `.hyperspace/approaches.html` |
| Explainer | `explainer.html` | `.hyperspace/rate-limiting.html` |
| Approval needed | `decision.html` | `.hyperspace/approve-deploy.html` |
| User live doc (generative UI) | package template (on first save) | `.hyperspace/livedoc.html` |

Browser Save writes `.hyperspace/livedoc.html`, runs `codex exec`. Read and edit
the same canvas (`<main class="live-doc-canvas">`). The live doc is an
agent-authored HTML workspace: choose the most helpful representation for the
task, from a short note to a custom interactive tool. Browser users do not
hand-edit the full canvas; they interact with generated UI and attach comments.
If you need input, generate the input UI in the artifact. Web components:
`~/.config/hyperspaces/components/`. Set `"pending": false` when done.

Gallery of artifact *types* (examples only): [html-effectiveness](https://thariqs.github.io/html-effectiveness/)

Set `data-project`, `data-agent`, and `data-updated` on `<body>` (templates include placeholders).

## When blocked

1. Write or update a `decision.html` artifact explaining the choice.
2. State clearly: **waiting for user** — include the file path.
3. Between tasks, wait for browser Save to trigger `codex exec` — do not poll in a tight loop.

## Skills (profile-scoped)

| Skill | When |
|-------|------|
| `$html-artifact` | Creating or updating any HTML artifact |
| `$live-doc` | User saved the browser canvas — read and execute |

## Related dotfiles

- `hyperspace-open-report` — open `.hyperspace/<slug>.html`
- `nearly-headless` — profile helper commands
- Docs: `~/.agents/docs/headless-html-artifacts.md`
- Task list: `~/.agents/profiles/nearly-headless/TASKS.md`
