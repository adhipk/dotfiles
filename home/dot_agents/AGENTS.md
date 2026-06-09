# Agent Configuration

This directory is the checked-in source of truth for personal agent behavior on a machine.
Chezmoi applies it to `~/.agents`.

## Layout

- `skills/` maps to `~/.agents/skills` for personal Codex skills.
- `docs/` maps to `~/.agents/docs` for centralized agent-readable documentation.

## Codex Skills

- Prefer personal skills under `~/.agents/skills/<skill-name>/SKILL.md`.
- Invoke personal skills as `$skill-name` or select them with `/skills`.
- Keep built-in Codex slash commands separate from personal skills. For example, `/memories` configures Codex memory behavior, while `$memorise` is planned as a personal documentation-capture skill.
- Use `$skill-creator` when creating or revising skills.

## Documentation

- Use `~/.agents/docs` for durable machine-level documentation that should be available across projects.
- Keep project-specific notes in the project or in `~/notes` unless they describe default agent behavior.
