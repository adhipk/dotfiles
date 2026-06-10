# Hyperspace web components

Native `<hs-*>` elements for generative UI. Light DOM — safe for contenteditable round-trip.

These are reusable primitives for common structures, not the boundary of the
canvas. The live doc is an agent-authored HTML workspace: agents should use
plain HTML, inline CSS/JS, local custom elements, or one-off mini-tools whenever
that is the clearer representation.

| Tag | Use |
|-----|-----|
| `hs-callout` | Note, warning, error, success (`variant`, `label`) |
| `hs-finding` | Severity-tagged item (`severity`: high/medium/low) |
| `hs-comparison` | Side-by-side options (`title` + `hs-option` children) |
| `hs-option` | One column in a comparison (`title`) |
| `hs-details` | Collapsible section (`summary`, optional `open`) |

Agents may add new `hs-*` elements here following the same pattern when a pattern
is likely to repeat. Keep one-off task-specific UI local to the artifact.
