---
name: next-task
description: Finish the active task, validate and commit only its owned changes, prove every touched Git worktree is clean, and then begin the newly supplied task. Use only when the user explicitly invokes `$next-task` or explicitly asks to finish and commit the current work before switching to a new request.
---

# Next Task

Treat the new request as queued work. Do not mix it into the active task or begin
editing for it until the transition gate below passes.

## 1. Capture the boundary

1. Preserve the next request exactly as supplied after the invocation.
2. Identify the active objective, its repository, its canonical task entry when
   one exists, and the paths it owns.
3. Keep both objectives separate in commentary and in Git history.

If no next request was supplied, finish the active task through the clean-worktree
gate, then ask for the next request.

## 2. Finish the active task

1. Continue the active objective until it is genuinely complete. Do not treat the
   invocation as permission to truncate validation or hide a blocker.
2. Run the focused validation required by the repository and the change risk.
3. Inspect the complete diff and separate active-task changes from unrelated or
   pre-existing work. Preserve unrelated changes.
4. Update the active task's durable handoff or status when repository instructions
   require canonical task tracking.

If the active task is genuinely blocked, report the blocker and stop. Do not start
the next task from a partially finished state.

## 3. Commit through a clean-worktree gate

1. Review `git status --short`, the unstaged diff, and the staged diff.
2. Stage explicit active-task paths only. Never use a broad commit as a shortcut
   around uncertain ownership.
3. Inspect the staged diff and staged stat before committing.
4. Create one or more coherent local commits. Use multiple commits only when the
   completed work contains genuinely distinct changes.
5. Do not amend, push, deploy, stash, discard, or rewrite history unless the user
   separately authorizes that action.
6. Run `git status --porcelain` after the commit. The gate passes only when it
   produces no output in every repository touched by the active task.

Do not commit another person's or the user's unrelated changes merely to make the
tree clean. If such changes prevent a clean tree, list the exact paths and stop
before the next task. A separate clean worktree is an option only with the user's
approval or when repository instructions already authorize it.

## 4. Start the next task

After the clean-worktree gate passes:

1. State the completed commit hash or hashes and confirm the clean worktree.
2. Re-read the instructions for the next task's repository and inspect only its
   scoped open tasks.
3. Reuse or create the appropriate canonical task entry for nontrivial change
   work, following that repository's task-tracking rules.
4. Begin executing the queued request immediately. Do not stop at a transition
   summary unless the request requires a missing decision or authorization.

The invocation authorizes local commits needed for this transition. It does not
authorize pushes, deployments, external writes, or destructive cleanup.
