---
name: live-doc
description: >-
  Handle the shared .hyperspace/livedoc.html generative UI canvas. User and agent
  edit the same HTML with native web components.
---

# Live Doc

One file: `.hyperspace/livedoc.html`. Canvas content lives in `<main class="live-doc-canvas">`.

**Not chat** — compose `<hs-*>` web components, plain HTML, or inline scripts ([Generative UI](https://research.google/blog/generative-ui-a-rich-custom-visual-interactive-user-experience-for-any-prompt/)).

## Web components

Registered by `shared/hyperspace-components.js` (copied into `.hyperspace/shared/` on save).

| Tag | Attributes | Example |
|-----|------------|---------|
| `hs-callout` | `variant`, `label` | `<hs-callout variant="warning" label="Note">Body</hs-callout>` |
| `hs-finding` | `severity`, inner `h3` | `<hs-finding severity="high"><h3>Title</h3><p>…</p></hs-finding>` |
| `hs-comparison` | `title` | `<hs-comparison title="Options"><hs-option title="A">…</hs-option></hs-comparison>` |
| `hs-option` | `title` | Child of `hs-comparison` |
| `hs-details` | `summary`, `open` | `<hs-details summary="FAQ">Answer</hs-details>` |

Source: `~/.config/hyperspaces/components/`

## Browser vs agent

- **Browser:** editable rendered canvas (no source view). Save writes canvas HTML into `livedoc.html`.
- **Agent:** edit `livedoc.html` directly — add components, scripts, full generative UI. No build step.

## Steps

1. Read `livedoc.html` (canvas = `<main class="live-doc-canvas">` contents).
2. Do the work; edit the canvas (append, rewrite, add `<hs-*>` or custom elements).
3. Set `"pending": false`, `"status": "done"` in `live-doc.json`.
