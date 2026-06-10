---
name: html-artifact
description: >-
  Create self-contained HTML artifacts for the nearly-headless profile using
  templates and components in ~/.agents/docs/templates/. Use for reports,
  reviews, plans, explainers, and interactive pages instead of long Markdown.
  Only when nearly-headless profile is active.
---

# HTML Artifact

Produce single `.html` files the user opens in a browser. **Nearly-headless profile only.**

Read `~/.agents/docs/html-artifacts.md` first.

## When to use HTML

- Reports, reviews, plans, status, exploration, explainers
- Spatial content: diffs, diagrams, timelines, side-by-side comparisons
- Light interaction: `<details>`, copy-export, `contenteditable` — via templates/components

Prefer Markdown for short notes. Prefer HTML when the [html-effectiveness](https://thariqs.github.io/html-effectiveness/) *types* fit (review, report, exploration, etc.) — those demos are examples, not code to import.

## Workflow

1. Pick a **template** from `~/.agents/docs/templates/` (or extend one).
2. Compose **components** from `templates/components/` as needed.
3. Ensure `<project>/.hyperspace/` exists (`nearly-headless init-project`).
4. Copy `shared/hyperspace.css` into `.hyperspace/shared/` if missing.
5. Write `<project>/.hyperspace/<slug>.html`.
6. Tell the user: `hyperspace-open-report <slug>` or `http://127.0.0.1:4200/<route>/<slug>` if `hyperspace serve` is running.

## Templates

| Template | Type |
|----------|------|
| `base.html` | Generic |
| `task-report.html` | Completed work |
| `status-dashboard.html` | Agent/session status |
| `review.html` | Code/PR review |
| `decision.html` | Blocked — user chooses |
| `exploration.html` | Compare approaches |
| `explainer.html` | Feature/concept |

## Components

Copy snippets from `templates/components/` (`finding`, `callout`, `comparison-columns`, `details-section`, `export-bar`). Create new component files when a pattern repeats.

## Rules

- Plain HTML + `hyperspace.css` by default — no CDN frameworks unless the page needs them.
- Small inline `<script>` only for interaction (copy button, toggles).
- HyperClay is optional — see `hyperclay-patterns.md` only if explicitly requested.
- Do not build SPAs, React apps, or npm-based pages.
