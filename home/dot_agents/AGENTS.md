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

## Canonical Task Tracking

- The current project or tmux session working directory owns its durable `./todo.txt` and `./done.txt`. Run the repo-owned `todo` wrapper from that root for every read and write; never use raw redirects or bare `tuxedo`. The wrapper pins Tuxedo to that directory and serializes agent mutations.
- At the start of nontrivial change work, inspect `todo ls --json` from the active project root. Reuse an open matching task or add one line per distinct deliverable using a priority, creation date, `+project`, `@agent`, stable `id:<uuid>`, and `owner:<agent>`. Do not create entries for trivial read-only questions.
- Re-resolve a task's current number immediately before changing it. After validation succeeds, run `todo do N`; never archive automatically.
- Keep blocked tasks open with `status:blocked` and a concise reason. Do not modify unrelated tasks.
- Ephemeral plans may support execution, but they never replace, duplicate, or split from the canonical todo.txt state.
- When an app is made accessible through tmux, launch it in the same working directory as the session's existing windows unless the user explicitly requests another root.
