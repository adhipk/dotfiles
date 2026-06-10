---
name: live-doc
description: >-
  Handle the shared .hyperspace/livedoc.html generative UI canvas. User and agent
  edit the same HTML as an agent-authored workspace.
---

# Live Doc

One file: `.hyperspace/livedoc.html`. Canvas content lives in `<main class="live-doc-canvas">`.

**Not chat.** The directive is to convey the work in the most helpful HTML form
you can make. Use prose when prose is best, but prefer structured or interactive
surfaces when they communicate better: reports, diagrams, inspectors, timelines,
tables, dashboards, visual diffs, checklists, small tools, or task-specific
custom elements.

The canvas is the durable output plane. Chat is only the control plane. The user
does not directly edit the full canvas in the browser; they interact with the UI
you generate and can attach comments to parts of the artifact.

No React, no build step. Use plain HTML/CSS/JS, inline scripts, and CDN
dependencies only when they materially improve the artifact.

## Web components

Registered by `shared/hyperspace-components.js` (copied into `.hyperspace/shared/` on save).

These components are scaffolding, not boundaries. Use them for common structure;
invent local markup, custom elements, or one-off components when the task needs a
better representation.

| Tag | Attributes | Example |
|-----|------------|---------|
| `hs-callout` | `variant`, `label` | `<hs-callout variant="warning" label="Note">Body</hs-callout>` |
| `hs-finding` | `severity`, inner `h3` | `<hs-finding severity="high"><h3>Title</h3><p>…</p></hs-finding>` |
| `hs-comparison` | `title` | `<hs-comparison title="Options"><hs-option title="A">…</hs-option></hs-comparison>` |
| `hs-option` | `title` | Child of `hs-comparison` |
| `hs-details` | `summary`, `open` | `<hs-details summary="FAQ">Answer</hs-details>` |

Source: `~/.config/hyperspaces/components/`

## Representation choices

- **Operational artifact:** prefer a page that is useful without reading the
  transcript.
- **Structured state:** embed JSON in `<script type="application/json">` when a
  generated widget or visualization needs durable state.
- **Task-specific UI:** create the controls, filters, diagrams, or inspectors the
  user would naturally need next.
- **Reusable primitive:** add an `hs-*` component to the registry only when a
  pattern is likely to repeat; otherwise keep one-off code local to the canvas.
- **Copy/paste and files:** use browser-native affordances when they make the
  artifact more useful.
- **Input requests:** when you need user input, generate an explicit text box,
  form, choice set, checklist, file picker, or custom control in the artifact.

## Browser vs agent

- **Browser:** rendered interaction surface. Users can interact with generated
  controls, send default messages, and add comments to artifact elements. When
  the message box is focused, clicking an artifact element inserts a DOM
  identifier like `@dom:hs-...` or `#existing-id`; resolve those references from
  the saved HTML. Save writes messages, comments, and control values into
  `livedoc.html`. Comments live out-of-flow in `hs-comments` and reference
  targets with `data-comment-for`; read them as annotations without treating them
  as layout content.
- **Agent:** edit `livedoc.html` directly — add components, scripts, custom
  elements, or full generated HTML tools. No build step.

## Steps

1. Read `livedoc.html` (canvas = `<main class="live-doc-canvas">` contents).
2. Do the work; edit the canvas with the most helpful representation you can
   make (append, rewrite, add `<hs-*>`, custom elements, or inline tools).
3. Set `"pending": false`, `"status": "done"` in `live-doc.json`.
