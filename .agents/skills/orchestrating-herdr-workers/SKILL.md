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

Decide the path before you start. When the user's deliverable is an answer, only steps 2 and 6 apply: gather the facts, check them, report, and finish — do not manufacture a plan just to have something to approve. When the deliverable is a diff, walk all six in order, scaling the machinery to the change: a one-line documentation edit does not need the same loop as a refactor, and if you think the loop is disproportionate, offer the user the choice rather than deciding silently.

1. Inspect the worktree and preserve unrelated changes.
2. Reach for Explorer only when the facts you need are spread across files you cannot yet name. When the relevant paths are already known, read them directly — never launch Explorer just to summarize a small known file.
3. Write the plan and wait for explicit user approval before launching Implementer.
4. Launch Reviewer when Implementer produces a diff.
5. Adjudicate every finding; send only accepted findings to the retained Implementer.
6. Leave pane cleanup on the normal path to `herdr-worker run`, which closes a successful Explorer or Reviewer pane itself. Close a retained Implementer explicitly with `herdr-worker close` once its review/fix loop is finished. Blocked, crashed, or ambiguous panes stay open for diagnosis.

The human owns task tabs. Never create, rename, or close a tab. `herdr-worker` splits each worker into a sibling pane in the current tab without changing focus, and chooses the direction itself: right from a sufficiently wide caller pane, down from a narrow or tall one. You neither pass nor check the direction — a successful pane is closed before its geometry can be read. What you do check once a task is finished is that nothing leaked: `herdr-worker status --task-id <id>` should list no panes except ones deliberately kept open for diagnosis.

The normal interface is `herdr-worker --help`. Pass repository paths and plan paths rather than conversation transcripts. Everything printed after the header by `run` and `follow-up` is the worker's report in full; read all of it. Never pipe that output through `head`, `tail`, or any other truncation — the job directory is discarded on success, so whatever a truncated read drops is unrecoverable.

Reading a report whole is not the same as believing it. Before relaying any worker claim to the user, confirm the parts that can be run or looked up: that a command actually works, that a path exists, that a file is what the report says it is. A report can be captured perfectly and still be wrong, and the reader cannot tell the difference.

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
- Truncating a worker report with `head` or `tail` instead of reading it whole.
- Relaying a worker's commands and paths to the user without checking that they hold.
