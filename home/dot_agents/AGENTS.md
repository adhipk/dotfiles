# Agent Configuration

This directory is the checked-in source of truth for personal agent behavior on a machine.
Chezmoi applies it to `~/.agents`.

## Layout

- `skills/` maps to `~/.agents/skills` for personal Codex skills.
- `docs/` maps to `~/.agents/docs` for centralized agent-readable documentation.
- `profiles/` maps to `~/.agents/profiles` for optional agent profiles that do not
  override these defaults unless explicitly activated.

## Profiles

Optional profiles live under `profiles/<name>/`. They are **opt-in** — default behavior
is unchanged unless you activate a profile (e.g. `nearly-headless print-agents`).

| Profile | Purpose |
|---------|---------|
| `nearly-headless` | Headless tmux agents, HTML artifacts, hyperspace integration |

See `profiles/nearly-headless/README.md` and `docs/nearly-headless.md`.

## Codex Skills

- Prefer personal skills under `~/.agents/skills/<skill-name>/SKILL.md`.
- Invoke personal skills as `$skill-name` or select them with `/skills`.
- Keep built-in Codex slash commands separate from personal skills. For example, `/memories` configures Codex memory behavior, while `$memorise` is planned as a personal documentation-capture skill.
- Use `$skill-creator` when creating or revising skills.

## Documentation

- Use `~/.agents/docs` for durable machine-level documentation that should be available across projects.
- Keep project-specific notes in the project or in `~/notes` unless they describe default agent behavior.
