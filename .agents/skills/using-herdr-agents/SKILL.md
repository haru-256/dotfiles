---
name: using-herdr-agents
description: Use when the user explicitly names the `using-herdr-agents` skill
---

# Using Herdr Agents

## Overview

The parent orchestrator stays Planner/Judge. Herdr agents are specialist workers used only when delegation beats doing the work inline.

Activation gate: use this skill only when the user explicitly names the `using-herdr-agents` skill.
Do not use this skill merely because a task could be delegated, because the user asks for exploration, implementation, review, or because Herdr would be a plausible tool.

When the skill was not explicitly requested, handle the request directly or use the ordinary skills/tools that match the task.

Core rule: Default to one-shot execution. Use a persistent session only when future context is likely valuable.

This skill package owns its internal `./scripts/`, `./prompts/`, and `./scripts/install`.

If `herdr-agent` or `herdr-agent-session` is not on `PATH`, run from the repository root:

```sh
./.agents/skills/using-herdr-agents/scripts/install
```

Or, if the global/home skill symlink already exists, you can run it from anywhere:

```sh
~/.agents/skills/using-herdr-agents/scripts/install
```

Install only creates/updates symlinks. It does not copy files or edit shell startup files.

Do not delegate when the parent agent can answer faster by reading a small file, making a trivial local edit, or running a simple check.

## Command Boundary

| Need | Command | Lifecycle |
| --- | --- | --- |
| single task, fresh context, routing check | `herdr-agent <role> "<brief>"` | one-shot |
| follow-up likely, context map useful, startup overhead matters | `herdr-agent-session <role> "<brief>"` | persistent |
| non-persistent pane run | `HERDR_AGENT_SESSION_MODE=oneshot herdr-agent-session <role> "<brief>"` | one-shot in Herdr |

## Role Selection

| Need | Role | Default |
| --- | --- | --- |
| missing repo context | `scout` | cheap read-only exploration |
| scoped implementation | `coder` | one-shot unless follow-up context helps |
| diff or artifact review | `auditor` | fresh one-shot preferred |
| repeated failure or hard judgment | `advisor` | escalation-only |

## Session Lifecycle

Default to one-shot when:
- the task is small or self-contained
- freshness matters more than startup overhead
- reviewing Coder output
- the existing session may contain stale or unrelated context

Use persistence when:
- follow-up questions are likely
- Scout is building a repo or feature map
- the same investigation will continue
- startup overhead outweighs contamination risk

Reuse only when role, repository/worktree, backend/model class, and `HERDR_AGENT_CONTEXT_KEY` all match. Otherwise use `HERDR_AGENT_REUSE=never`.

`HERDR_AGENT_CONTEXT_KEY` is the explicit contract for reuse. When it is not set, `herdr-agent-session` downgrades the default `HERDR_AGENT_REUSE=auto` to `never` and starts a fresh `no-context-*` session name. `HERDR_AGENT_REUSE=require` without a context key is invalid.

Close stale sessions:

```sh
herdr agent list
herdr pane close <pane_id>
```

## Recipes

One-shot Scout:

```sh
herdr-agent scout "Find the relevant files for ..."
```

Persistent Scout:

```sh
HERDR_AGENT_CONTEXT_KEY=feature-auth herdr-agent-session scout "Map the auth-related files. Do not edit."
```

Fresh Auditor:

```sh
HERDR_AGENT_REUSE=never herdr-agent auditor "Review the current git diff against ..."
```

Advisor escalation:

```sh
HERDR_AGENT_ADVISOR_THINKING=xhigh herdr-agent advisor "Judge these conflicting reports and choose the next narrow action ..."
```

## Reading and Reusing Sessions

Inspect sessions before reuse:

```sh
herdr agent list
herdr agent read <agent-name-or-pane-id> --source recent-unwrapped --lines 160 --format text
```

If Herdr reports `working` but the pane appears complete, read before assuming it is active.

## Detailed Routing Policy

Always apply these routing rules for Herdr agent delegation:

- **`coder` (Implementation)**: Default for all actual source, test, script, or configuration changes.
- **`scout` (Discovery)**: Used strictly for discovery when relevant paths, impact radius, or validation commands are unknown. Scout output is evidence, not authority.
- **Direct Reads**: When decisive files are already known, the orchestrator reads them directly before planning instead of asking scout to summarize.
- **`auditor` (Review)**: Used as a fresh one-shot execution to review meaningful implementation diffs.
- **`advisor` (Escalation)**: Used for high-level judgment/escalation only after cheaper evidence has been gathered or when a repeated failure has occurred.

### Routing Matrix

| Flow | Action |
| --- | --- |
| Greetings, thanks, meta-questions | Answer directly |
| Pure repository understanding | Read directly if paths are known, otherwise delegate to `scout` |
| Code-change workflow | Read/get context -> Write/update plan -> Delegate implementation to `coder` -> Delegate review to fresh `auditor` |
| Review adjudication | Classify findings (ACCEPT/REJECT/DEFER/NEEDS_CONTEXT/ESCALATE). Send ACCEPT to `coder`, ESCALATE to `advisor` |
| Planning/design/docs | Handle directly, read files directly if known, otherwise `scout` first |

## Delegation Brief Format

Keep Herdr briefs concise and include only:
1. Goal
2. Background / context
3. Constraints
4. Relevant paths
5. Acceptance criteria

For exploration, explicitly say read-only. For implementation, point to the authoritative plan or instructions. For review, request concrete findings with severity, evidence, and recommended action.

## Failure Handling and Escalation

When a specialist reports `BLOCKED`, preserve the failure signature or stable error summary. If the same specialist hits the same failure twice in a row for the same work item, stop retrying and escalate to `advisor` with the failure history.

## Operational Contract

Prerequisites: `herdr`, `mise`, and the selected backend CLI must be available on `PATH`. OpenCode and Cline are launched through `mise exec --`; Agy and Codex are launched directly.

`scripts/install` only creates or updates symlinks for `herdr-agent`, `herdr-agent-session`, `~/.config/herdr/agents`, and the skill package. It must not copy package files or edit shell startup files.

Validation:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-lib \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-session \
  .agents/skills/using-herdr-agents/scripts/install \
  .agents/skills/using-herdr-agents/tests/herdr-agent.sh \
  tests/herdr-agent.sh
sh tests/herdr-agent.sh
HERDR_AGENT_DRY_RUN=1 herdr-agent scout "find files"
HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_REUSE=never herdr-agent-session scout "find files"
```

The root `tests/herdr-agent.sh` wrapper is the canonical repo-level check; the package-local test contains the assertions.

Shared shell helpers live in the package's internal `./scripts/herdr-agent-lib`. Entry scripts keep only the minimal bootstrap needed to resolve symlinked entrypoints and source the package-local library.

Use the `herdr` skill first when direct Herdr workspace, tab, pane, wait, or low-level agent coordination is needed. Only do this when running inside Herdr (`HERDR_ENV=1`) or when explicitly verifying Herdr CLI behavior; ordinary `herdr-agent` and `herdr-agent-session` usage does not require loading that skill.

## Common Mistakes

- Using `herdr-agent-session` just because it exists. Persistence is a context decision, not the default goal.
- Reusing Coder or Auditor sessions across unrelated tasks.
- Letting Scout plan, Coder broaden scope, or Auditor decide final action.
- Escalating to Advisor before cheaper Scout/Coder/Auditor evidence exists.
- Leaving task-specific sessions open after their context is no longer useful.
