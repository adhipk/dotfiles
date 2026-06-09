---
name: html-artifact
description: >-
  Create or update HTML artifacts for the nearly-headless profile using
  ~/.agents/docs/templates and HyperClay. Use when producing reports, reviews,
  status pages, or decision prompts instead of long Markdown. Only when
  nearly-headless profile is active.
---

# HTML Artifact

Produce rich HTML files for the user to open in a browser. **Nearly-headless profile only.**

## When to use

- Task reports, PR/code reviews, plans, status dashboards
- Anything over ~100 lines or needing color, tables, collapsible sections
- User is in headless tmux agent mode

Prefer Markdown for short notes and repo docs unless the user asks for HTML.

## Steps

1. Read `~/.agents/docs/hyperclay-patterns.md`.
2. Pick a template from `~/.agents/docs/templates/`:
   - `task-report.html` — completed work
   - `status-dashboard.html` — agent/session status
   - `review.html` — findings with severity
   - `decision.html` — blocked, needs approval
   - `base.html` — generic
3. Ensure `<project>/.hyperspace/` exists.
4. Copy `shared/hyperspace.css` to `<project>/.hyperspace/shared/` if missing.
5. Write `<project>/.hyperspace/<slug>.html` — fill content sections only.
6. Set `data-project`, `data-agent`, `data-updated` on `<body>` with real values.
7. Tell the user: `hyperspace-open-report <slug>` (omit `.html`).

## Placeholders

Replace `{{TITLE}}`, `{{PROJECT}}`, `{{AGENT}}`, `{{ISO8601}}`, `{{TIMESTAMP}}`, and template-specific blocks. Remove unused placeholder sections.

## Do not

- Build SPAs or import npm packages
- Invent new CSS frameworks (use `shared/hyperspace.css` classes)
- Replace default agent behavior outside nearly-headless profile
