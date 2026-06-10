# HyperClay (optional)

**Not required** for nearly-headless artifacts. Default stack is plain HTML +
`hyperspace.css` + templates/components — see `html-artifacts.md`.

Use [HyperClay](https://hyperclayjs.com/docs) only when you explicitly want:

- In-browser save back to hosted pages (`save-system`, `edit-mode`)
- Modal `ask` / `consent` flows
- `live-sync` SSE updates

For most artifacts (reviews, reports, plans), use HTML templates and
`components/export-bar.html` instead.

```html
<!-- Only when HyperClay is requested -->
<script src="https://hyperclayjs.com/hyperclay.js?edit-mode,save-system,save-toast"></script>
```
