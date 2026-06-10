# Personal Skills

Create personal Codex skills in this directory.

Each skill should live at:

```text
<skill-name>/SKILL.md
```

Chezmoi applies this directory to `~/.agents/skills`, where Codex can discover personal skills.

## Nearly-headless skills

| Skill | Profile | Purpose |
|-------|---------|---------|
| `html-artifact` | nearly-headless | Write HTML reports to `.hyperspace/` |
| `live-doc` | nearly-headless | Edit the shared `.hyperspace/livedoc.html` canvas |

Invoke with `$html-artifact` or `$live-doc`. Activate the profile first:
`nearly-headless print-agents`.
