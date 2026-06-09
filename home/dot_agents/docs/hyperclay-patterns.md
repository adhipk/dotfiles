# HyperClay Patterns for Agent-Authored Pages

Reference for agents using the **nearly-headless** profile. Full API:
[hyperclayjs.com/docs](https://hyperclayjs.com/docs).

## Script bundles

Load features via query string on the HyperClay script URL:

| Use case | Features |
|----------|----------|
| Read-only report | *(none — CSS only)* |
| Editable report | `edit-mode,save-system,save-toast` |
| Needs user text input | `+ask` |
| Approval / confirm | `+consent` |
| Live updates from agent (advanced) | `live-sync` |

Example:

```html
<script src="https://hyperclayjs.com/hyperclay.js?edit-mode,save-system,save-toast,ask"></script>
```

## Agent rules

1. Copy a template from `~/.agents/docs/templates/`; only replace `#content` (or marked sections).
2. Keep `shared/hyperspace.css` as a relative link — copy `shared/` into `.hyperspace/` when publishing.
3. Do not add React, Vue, or extra CSS frameworks.
4. Use semantic HTML: `section`, `article`, `details`, `table`, `pre`.
5. Severity colors: classes `finding severity-high|medium|low`, `callout warning|error|success`.
6. Status badges: `badge running|needs-input|exited`.

## Publishing to a project

When writing to `<project>/.hyperspace/report.html`:

1. Create `.hyperspace/` if missing.
2. Copy `shared/hyperspace.css` to `.hyperspace/shared/hyperspace.css` (once per project).
3. Use `<link rel="stylesheet" href="shared/hyperspace.css">` in artifacts.
4. Prefer slugs: `status.html`, `pr-142.html`, `fix-lint.html`.

## Useful HyperClay APIs

| API | Purpose |
|-----|---------|
| `toast(msg, 'success'\|'error')` | Save feedback |
| `ask(prompt)` | Modal text input → Promise |
| `consent` | Confirm/cancel flows |
| `save-system` | Manual save with change detection |
| `edit-mode` | Toggle in-browser editing |

## live-sync (optional, phase 3)

For dashboards that update while an agent runs:

```html
<script type="module">
  await import('https://hyperclayjs.com/hyperclay.js?features=live-sync');
</script>
```

Requires HyperClay Local / SSE setup — optional; only enable when you have SSE running locally.
