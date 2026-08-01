---
name: orchestrating-herdr-workers
description: Use when the user explicitly invokes an Orchestrator to coordinate Explorer, Implementer, or Reviewer workers through Herdr
---

# Orchestrating Herdr Workers

## Overview

The Orchestrator owns planning, worker control, review adjudication, pane cleanup, and user-facing decisions. Workers receive compact file-based context and never become the Orchestrator.

Activation gate: use this skill only when the user explicitly invokes an Orchestrator or names `orchestrating-herdr-workers`.

**REQUIRED SUB-SKILL:** Use `herdr` for direct workspace, tab, pane, and agent control. Stop if `HERDR_ENV=1` is not set.

## Worker Roles

| Role | Use | Lifecycle |
| --- | --- | --- |
| `explorer` | Read-only repository evidence | fresh; `quick` by default, `deep` only when explicit |
| `implementer` | Execute an approved plan and validate it | retain through the task's review/fix loop |
| `reviewer` | Read-only plan/diff/test review | fresh for every review |

Use direct reads when the relevant files are already known. Do not launch Explorer only to summarize a small known file.

## Orchestration Contract

1. Inspect the worktree and preserve unrelated changes.
2. Use Explorer only when missing facts block a safe plan or brief.
3. Write the plan and wait for explicit user approval before launching Implementer.
4. Launch Reviewer when Implementer produces a diff.
5. Adjudicate every finding; send only accepted findings to the retained Implementer.
6. Close successful worker panes after their reports are captured. Keep blocked, crashed, or ambiguous panes open for diagnosis.

The human owns task tabs. Never create, rename, or close a tab. Split each worker into a sibling pane in the current tab without changing focus. Split a sufficiently wide pane to the right; split a narrow or tall pane down.

The normal interface is `herdr-worker --help`. Pass repository paths and plan paths rather than conversation transcripts.

## Backend Policy

Cursor Agent is primary. OpenCode is a one-time fallback only before Cursor launches: the Cursor command is missing, authentication/status preflight fails normally, or the configured model is unavailable. Signal-derived preflight exits do not fall back. After Cursor launches, never start OpenCode automatically, regardless of exit status or apparent worktree state. OpenCode Explorer and Reviewer have Bash denied to preserve read-only behavior. Preserve the Cursor pane and report `BLOCKED` when safe continuation is uncertain.

## Session Policy

Sessions are task-scoped, not long-lived. Explorer and Reviewer are one-shot. Retain Implementer only for accepted review fixes in the same repository, worktree, task, and backend. Never reuse a worker across unrelated tasks.

Blocked or ambiguous panes are intentionally excluded from `herdr-worker close`. Capture the evidence first; after diagnosis and an explicit decision to discard that worker, close it directly with `herdr pane close <pane-id>`.

## Common Mistakes

- Launching Implementer before plan approval.
- Using deep exploration by default.
- Reusing Reviewer or carrying implementation context into review.
- Falling back after partial edits.
- Creating or closing a task tab instead of using a sibling pane.
- Closing a failed pane before evidence is captured.
