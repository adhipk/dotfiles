# Decision 0002: Promote Hermes to the pluggable default

Status: accepted  
Date: 2026-08-12

## Context

Decision 0001 kept Codex as the default while Hermes was evaluated. The user
has now explicitly requested Hermes as the pluggable default for the dotfiles
repository. Hermes is already installed and configured on this machine.

## Decision

- Add an optional `hermes-agent` dotfiles module, enabled by default.
- Select `hermes-dotfiles` as `preferences.assistant` while retaining the
  stable internal tmux window type `codex`.
- Use a dedicated Hermes profile named `dotfiles`; the module owns only its
  launcher and preserves profile state when disabled or uninstalled.
- Keep the managed `todo` wrapper as the authoritative task and handoff store.
- Do not initialize Hermes Kanban, install a gateway service, or manage Hermes
  credentials, sessions, memories, and runtime databases through ChezMoi.
- Require approval for Hermes memory and skill writes in the live profile.

## Reversibility

The assistant can be switched without structural tmux changes:

```sh
dotfiles-settings set assistant codex
dotfiles-settings set assistant hermes-dotfiles
```

Disabling `modules.hermesAgent` removes `~/bin/hermes-dotfiles` while preserving
the upstream installation and the dedicated profile.

## Consequences

This supersedes only Decision 0001's temporary prohibition on changing the
default assistant. Its task-ledger, security, worktree-isolation, and
unmanaged-runtime boundaries remain in force. Hermes is the interactive shell;
it is not a second source of truth for durable work.
