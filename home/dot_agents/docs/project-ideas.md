# Project Ideas

## Centralized Codex Skills

Create personal Codex skills in `~/.agents/skills` and manage their source through this dotfiles repository at `home/dot_agents/skills`.

### Skills Created

- `$html-artifact`: HTML reports for nearly-headless profile (`.hyperspace/`).
- `$live-doc`: shared `.hyperspace/livedoc.html` canvas.

### Skills To Create

- `$add-note`: Save relevant user messages or requested content into the notes folder.
- `$organise`: Organize generated Markdown files in a folder according to that folder's instructions.
- `$add-task`: Add an item to the personal task list.
- `$reprioritise`: Add a new item and revise the current task or plan priority.
- `$memorise`: Add documentation to the centralized agent docs folder.

### Defaults

- Store personal skill source in `home/dot_agents/skills/<skill-name>/SKILL.md`.
- Apply skills with chezmoi so Codex discovers them at `~/.agents/skills`.
- Store centralized agent documentation in `home/dot_agents/docs`, applied as `~/.agents/docs`.
- Use `$skill-name` invocation for personal skills; reserve `/...` names for Codex built-in slash commands.
