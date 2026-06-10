# HTML Artifacts

Self-contained `.html` files agents write to `<project>/.hyperspace/`. Open in a
browser with `hyperspace-open-report <slug>`.

Inspired by artifact *types* in the [html-effectiveness gallery](https://thariqs.github.io/html-effectiveness/) — those demos are examples of what agents can generate, not dependencies to vendor.

## Model

```text
templates/     → starting shells per artifact type (copy, fill #content)
components/    → reusable HTML snippets to compose into pages
shared/        → hyperspace.css (one link tag)
```

**Default:** plain HTML + CSS. Inline `<script>` only when the page needs interaction
(collapsible sections, copy-export, simple toggles). No React, no build step.

**HyperClay:** optional; see `hyperclay-patterns.md` only if you explicitly want its
save/edit APIs.

## Artifact types

| Type | Template | When |
|------|----------|------|
| Generic | `base.html` | Anything that doesn't fit below |
| Task report | `task-report.html` | Work completed, commands run, next steps |
| Status | `status-dashboard.html` | tmux/agents overview |
| Code review | `review.html` | PR/diff findings with severity |
| Decision | `decision.html` | Agent blocked; user picks an option |
| Exploration | `exploration.html` | Side-by-side approaches or directions |
| Explainer | `explainer.html` | Feature/concept with collapsible sections |

New types: copy the nearest template, or compose from `components/`.

## Components

Reusable blocks in `~/.agents/docs/templates/components/`. Copy into `#content`:

| Component | File | Use |
|-----------|------|-----|
| Finding | `finding.html` | Severity-tagged review item |
| Callout | `callout.html` | Warning, note, success box |
| Comparison columns | `comparison-columns.html` | Two–three approach cards |
| Details / FAQ | `details-section.html` | `<details>` accordion block |
| Export bar | `export-bar.html` | Copy page section to clipboard |

Agents may combine multiple components in one artifact or invent new components following the same CSS classes.

## Authoring rules

1. Single file; opens via `file://` or `open` — no server required.
2. `<link rel="stylesheet" href="shared/hyperspace.css">` — copy `shared/` into `.hyperspace/` once per project (`nearly-headless init-project`).
3. Fill `#content` (or marked sections); keep header/footer from the template.
4. Set `data-project`, `data-agent`, `data-updated` on `<body>`.
5. Spatial layouts for diffs, diagrams, timelines — don't flatten into markdown walls.
6. Interactive pages: prefer `<details>`, `contenteditable`, small inline JS, or components — not a framework unless asked.

## Output path

```text
<project>/.hyperspace/<slug>.html
```

Tell the user: `hyperspace-open-report <slug>` or `http://127.0.0.1:4200/<route>/<slug>` when the server is running.

## Local server

```bash
hyperspace serve start          # background on :4200
hyperspace serve open           # browser → index
hyperspace serve stop
```

| URL | Serves |
|-----|--------|
| `http://127.0.0.1:4200/` | Live doc — pick a project, edit a blank canvas |
| `http://127.0.0.1:4200/dotfiles/` | Canvas for `hs-dotfiles`; Save → `.hyperspace/live-doc.html` |
| `http://127.0.0.1:4200/dotfiles/status.html` | Static artifact file |

**Live doc workflow:**

1. `hyperspace open dotfiles` + `hyperspace serve start`
2. Open `http://127.0.0.1:4200/dotfiles/` — blank canvas, Save (⌘S)
3. Server writes `.hyperspace/live-doc.html` and runs `hyperspace-run-live-doc` → `codex exec`
4. Agent edits the **same** canvas; browser reloads it when the agent finishes (if you haven't edited since)

Optional: `HYPERSPACE_CODEX_YOLO=1` for unattended `codex exec`.

Route = project id by default (e.g. `dotfiles` for `hs-dotfiles`). Optional `"route"` on the project in `agents.json` overrides the URL slug.
