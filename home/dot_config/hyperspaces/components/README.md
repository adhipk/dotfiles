# Hyperspace web components

Native `<hs-*>` elements for generative UI. Light DOM — safe for contenteditable round-trip.

| Tag | Use |
|-----|-----|
| `hs-callout` | Note, warning, error, success (`variant`, `label`) |
| `hs-finding` | Severity-tagged item (`severity`: high/medium/low) |
| `hs-comparison` | Side-by-side options (`title` + `hs-option` children) |
| `hs-option` | One column in a comparison (`title`) |
| `hs-details` | Collapsible section (`summary`, optional `open`) |

Agents may add new `hs-*` elements here following the same pattern.
