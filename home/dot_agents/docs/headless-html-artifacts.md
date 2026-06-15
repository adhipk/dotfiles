# Nearly-Headless

Project name in this dotfiles repo: `nearly-headless`.

Nearly-headless is a browser workspace for interacting with coding agents
without living in a chat transcript. A user creates tasks and sends them to
provider sessions. The app tracks progress, streams updates, and when the agent
needs input it creates the right interactive surface in the page.

The core product idea comes from the "Unreasonable Effectiveness of HTML" model:
HTML is not decoration around an agent transcript. It is the readable,
shareable, interactive medium that keeps the user in the loop.

## Owns

- The stable browser shell for tasks, progress, artifacts, and approvals
- Provider/session/model selection
- Task dispatch and provider-session continuity
- Streaming status and runtime events
- Serving `<repo>/.hyperspace/*.html`
- Creating and rendering `.hyperspace/livedoc.html`
- Copying shared CSS/components into `.hyperspace/shared/`
- Saving browser comments/messages/control state into the artifact workspace
- Triggering a runner/provider turn when the user sends a task or saves input
- Settings for projects, providers, and provider sessions

## Does Not Own

- Terminal multiplexing or tmux workspace management
- Keyboard shortcut routing for session switching
- Repo file edits without an explicit runner/apply step

## Generic Repo Flow

```bash
cd ~/some-repo
nearly-headless init-project
nearly-headless serve start
nearly-headless serve open
```

Compatibility commands still work (`headless-artifacts`, `hyperspace-serve`,
`hyperspace-open-report`), but `nearly-headless` is the product entrypoint. The
app discovers the current repo directly and manages its own provider-session
settings.

## Environment

Nearly-headless accepts neutral environment names for standalone use:

```bash
NEARLY_HEADLESS_PORT=4200
NEARLY_HEADLESS_HOST=127.0.0.1
NEARLY_HEADLESS_PROJECT_PATH=/path/to/repo
NEARLY_HEADLESS_PROJECT=my-repo
NEARLY_HEADLESS_CONFIG_FILE=/path/to/config.json
NEARLY_HEADLESS_STATE_DIR=/path/to/state
NEARLY_HEADLESS_SETTINGS_FILE=/path/to/settings.json
NEARLY_HEADLESS_PROVIDER_SESSIONS_FILE=/path/to/provider-sessions.json
```

Some legacy `HEADLESS_ARTIFACTS_*` names still work for compatibility, but new
standalone setups should use `NEARLY_HEADLESS_*`.

## Settings Page

`/settings/` is app-owned UI. Agents should not edit it by changing
`.hyperspace/livedoc.html`.

Settings own:

- provider definitions (`codex`, `claude`, API runners, mock runners)
- project paths/routes/default providers
- provider-session records and status

The app forces `runtime.primary` to `provider-sessions`.

## Default UI Contract

Nearly-headless must be useful before an agent writes any artifact. The app owns
the default UI for:

- creating a task
- choosing provider, model, and project
- viewing active and completed provider sessions
- seeing progress, checkpoints, diffs, approvals, and pending input
- managing settings
- adding comments or responses that are attached to a task/session

Agent-written HTML lives below that shell as task-specific surfaces. It must not
replace settings, navigation, provider selection, session management, or the
canonical comment/input store.

## Agent-Written Surfaces

Generated HTML should be treated as a purpose-built workbench. Good surfaces can
include reports, annotated diffs, explainers, diagrams, sortable tables,
decision forms, side-by-side prototypes, prompt editors, feature-flag editors,
or triage boards.

Every interactive surface needs an export path back to the provider session:
copy as prompt, submit JSON, submit a selected option, save annotations, or
apply a diff. The app should capture that output as session input instead of
asking the user to paste it through a terminal.

## Manager agent

Nearly-headless hosts a **manager agent** separate from coding **worker**
agents (Codex, Claude, etc.). Workers focus on repo work and stream raw
progress. The manager watches worker events and maintains HTML artifacts —
project dashboards, task summaries, decision forms — on milestones rather
than every tool call.

The manager may read session summaries, runtime events, pending prompts,
checkpoint summaries, and artifact metadata. It updates `.hyperspace/` and
surfaces when user input is needed. It does not edit repository files directly;
steering goes back to workers as structured prompts routed through the app
shell.

Do not ask worker agents to generate HTML artifacts inline — that slows
progress, burns tokens, and produces too many pages. Use a local model
(gemma-gem or another harness) for lightweight artifact patches when useful.

## Product Direction

Use the T3 Code backend shape instead of inventing session management:

- projects contain threads/tasks
- threads own provider-backed sessions
- provider selection routes by instance id and model selection
- adapters own provider-specific runtime behavior
- app state owns comments, approvals, progress, and checkpoints
- agent-authored UI is scoped to task/artifact surfaces, not the app shell

## Standalone Project Boundary

Nearly-headless should live in its own TypeScript repo and build a CLI binary.
Dotfiles should only install/wire that binary. The standalone project owns:

- the nearly-headless app shell
- task/thread orchestration
- shared components/CSS
- HTML templates and artifact skills/docs
- a runner adapter interface for Codex, Claude, OpenAI API, or mock runners
- provider-session persistence and resume/apply flows
