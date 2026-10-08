# Markdown clipboard

A Swift launch agent watches new clipboard copies every 200 ms. Plain-text-only
copies with headings, bold, inline/fenced code, lists, links, quotes or table
separators receive an HTML representation from Pandoc. The original Markdown
remains the plain-text representation. Plain-text copies carrying Chromium/editor
metadata also qualify, including VSCodium copies with a null language mode.
VS Code Markdown-mode copies also qualify: their highlighted source HTML is
replaced with rendered HTML, preserving Chromium/editor metadata. Other existing
rich text, normal text, files,
images, multiple items, marked sensitive copies and copies over 256 KiB are skipped.
Code blocks use semantic `<pre><code>` HTML without syntax-highlighting spans
or per-line anchor links, for simpler rich-editor paste handling.
Detection is a heuristic; code resembling Markdown can also qualify.

The installed Clipboard Project `cb` 0.10.0 writes text to the macOS plain-text
pasteboard type, so ordinary `cb` text copies are eligible too. No `cb` hooks or
history settings are changed. Allow the polling interval plus conversion time
before pasting; an immediate paste can precede enrichment.

`markdown-clipboard once` processes the current copy explicitly (startup only
watches new copies). `markdown-clipboard status`, `start` and `stop` inspect, install/restart, and stop
this service. Stop removes its login agent; a subsequent dotfiles apply that
changes this module may restart it. Use `dotfiles-module disable markdown-clipboard`
for durable disable, and `dotfiles-module enable markdown-clipboard` to restore.

Bootstrap installs Pandoc from the Brewfile. Chezmoi's after-apply hook compiles
with Apple Command Line Tools and installs the per-user LaunchAgent. Setup and
teardown hooks provide the same lifecycle through the module manager. No clipboard
history or content is logged or saved. Conversion runs locally, with raw HTML
parsing disabled and Pandoc's sandbox enabled; newer copies supersede work in flight.
The pasteboard has no atomic compare-and-swap, so a tiny read/write race remains.

Run `bash modules/markdown-clipboard/tests/test_service.sh` to test on a private
named pasteboard without touching the user's clipboard. Teams paste appearance
still requires an interactive check; apps decide which representation to use.
