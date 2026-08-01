# Herdr Orchestrator Workers Design

**Date:** 2026-08-01  
**Status:** Approved

## Goal

Use Codex or Claude for planning and orchestration while delegating bounded repository work to lower-cost Cursor Agent workers, with OpenCode as a controlled fallback. Herdr provides visible panes so the user can observe and interrupt workers.

## Architecture

The opt-in Orchestrator owns planning, the explicit approval gate, delegation, review adjudication, and cleanup. The repository-managed `orchestrating-herdr-workers` skill defines this policy and provides `herdr-worker`; the upstream `herdr` skill supplies direct Herdr control instructions.

Workers have three roles:

| Role | Responsibility | Lifecycle |
| --- | --- | --- |
| Explorer | Gather read-only repository evidence | fresh one-shot; quick by default |
| Implementer | Execute an approved plan and validate it | retained through the same task review/fix loop |
| Reviewer | Review plan, diff, and validation evidence | fresh one-shot per review |

The Orchestrator reads known files directly. Explorer is justified only when unknown repository facts block a safe plan. Implementer never starts before explicit plan approval.

## Backend Policy

Cursor Agent is primary. Explorer and Reviewer use ask mode with the non-fast `composer-2.5` model; Implementer uses the non-fast `cursor-grok-4.5-high` model. Cursor exposes fast variants as separate `-fast` model IDs. OpenCode uses its existing same-named agents as a one-time fallback.

Fallback is allowed only before Cursor launches: the command is unavailable, status or authentication preflight fails normally, or the configured model is unavailable. Signal-derived preflight exits do not trigger fallback. Once Cursor has launched, every nonzero exit is returned without starting OpenCode; determining that an arbitrary repository is unchanged is not reliable enough to justify automatic continuation.

OpenCode Explorer and Reviewer deny both edit and Bash permissions. They rely on read-only file, search, glob, and LSP tools. Implementer retains shell access for approved edits and validation.

## Pane Lifecycle

The human creates and manages task tabs. The skill never creates, renames, or closes a tab. It splits each worker into a sibling pane in the current tab and keeps focus in the caller pane. Following the upstream Herdr skill, it splits a sufficiently wide pane right and a narrow or tall pane down.

Fresh worker panes reduce stale-context risk and token use. Explorer and Reviewer close after a successful report is captured. Implementer remains visible and reusable only for accepted review findings in the same task, repository, worktree, backend, and human-managed tab. The Orchestrator closes it when the task succeeds.

Pane labels encode repository context, task, role, requested backend, run, and lifecycle state. Blocked, crashed, timed-out, and ambiguous panes remain open. Cleanup is scoped to the current tab and closes only labels marked successful. Implementer follow-up requires the unique successful pane for the current repository, task, and tab. Each initial or follow-up prompt includes a unique completion token; status parsing accepts only the marker for that turn.

## Installation Boundary

The upstream skill is installed only for Codex and Claude:

```sh
npx skills add herdrdev/herdr --skill herdr -g -a codex -a claude-code -y
```

The repository installer symlinks the custom skill and Orchestrator definitions into Codex and Claude, plus `herdr-worker` into `~/.local/bin`. If an agent directory already resolves to the repository directory through a parent symlink, the installer keeps the source file in place instead of creating a self-referential link. Cursor and OpenCode do not receive Orchestrator skills; they are worker harnesses.

## Rejected Alternatives

| Alternative | Decision and reason |
| --- | --- |
| Persistent panes for every role | Rejected because stale context and accumulated tokens outweigh startup savings for read-only roles. |
| Worker-created task tabs | Rejected because tab ownership belongs to the human and sibling panes provide better simultaneous visibility. |
| Separate Scout and Explorer roles | Rejected because both represented repository discovery; one Explorer role with quick/deep depth is simpler. |
| Automatic fallback after Cursor launch | Rejected because proving that an arbitrary repository is unchanged is unreliable, and continuing with a second backend can compound unknown state. |
| Long-lived cross-task Implementer | Rejected because repository and plan context can leak between unrelated tasks. |
| `gh skill` for upstream installation | Rejected for this rollout because the released repository layout did not expose the skill reliably; `npx skills` supports the required agent targets directly. |

## Verification

- Shell regression tests cover input validation, installer links, Cursor routing, safe fallback, post-edit refusal, lifecycle, follow-up, and ambiguous states.
- Dry-run output exposes role, model, backend, plan, and pane retention without splitting the layout.
- HOME verification checks exact symlink targets and retirement of the old package links.
