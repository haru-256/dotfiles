# Herdr Orchestrator Workers Implementation Plan

**Date:** 2026-08-01  
**Status:** Implemented

**Goal:** Replace the old Herdr specialist package with an opt-in Codex/Claude Orchestrator and three task-scoped Cursor/OpenCode worker roles.

**Architecture:** Keep policy and prompts in `orchestrating-herdr-workers`, use the official upstream `herdr` skill for terminal control, and route worker launches through a POSIX `herdr-worker` command with conservative fallback and pane cleanup inside the human-managed task tab.

## Constraints

- Preserve unrelated dirty worktree changes.
- Require explicit user approval before Implementer starts.
- Use Cursor Agent by default and OpenCode only under the safe fallback boundary.
- Never create or close human-managed task tabs.
- Keep failed or ambiguous Herdr worker panes open.
- Do not commit or push.

## Tasks

- [x] Add regression tests for role validation, plan paths, dry-run routing, installer targets, fallback, lifecycle, and follow-up.
- [x] Add the `orchestrating-herdr-workers` skill, worker prompts, POSIX runner, helper library, and installer.
- [x] Add opt-in Codex and Claude Orchestrator definitions with the approval and cleanup contract.
- [x] Remove the obsolete OpenCode `scout_v2` compatibility agent while preserving current worker configuration.
- [x] Update README installation, operations, dry-run, and validation guidance.
- [x] Install the official upstream `herdr` skill for Codex and Claude and install repository-managed symlinks.
- [x] Remove old `using-herdr-agents` HOME links and repository package after cutover verification.
- [x] Run shell, configuration, dry-run, symlink, and diff verification; obtain a fresh review.
- [x] Replace worker-created tabs with adaptive sibling panes scoped to the current human-managed tab.

## Validation Commands

```sh
sh tests/herdr-worker.sh
sh -n .agents/skills/orchestrating-herdr-workers/scripts/* \
  .agents/skills/orchestrating-herdr-workers/tests/herdr-worker.sh \
  tests/herdr-worker.sh
HERDR_WORKER_DRY_RUN=1 herdr-worker run explorer --task-id smoke --brief "find files"
git diff --check
```
