# Codex Orchestrator Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Register a separated Codex custom agent named `orchestrator` that can be invoked explicitly, without changing the default Codex main session behavior.

**Architecture:** Add one custom agent TOML under `.codex/agents/` using Codex's existing `developer_instructions` pattern. The agent prompt should adapt the OpenCode orchestrator role to Codex/Herdr realities: it plans and judges, delegates repository work through Herdr roles, and avoids direct broad implementation.

**Tech Stack:** Codex custom agent TOML, Codex `developer_instructions`, Herdr agent roles (`scout`, `coder`, `auditor`, `advisor`), existing dotfiles configuration.

---

## File Structure

- Create: `.codex/agents/orchestrator.toml`
  - Defines the explicit Codex custom agent named `orchestrator`.
  - Uses `model = "gpt-5.5"`, high/xhigh reasoning, and `developer_instructions` inline, matching the existing Codex agent style.
  - Does not modify `.codex/config.toml`, so the default Codex main session remains unchanged.
- No README update in this first step.
  - The user asked to “try” separated registration first; documentation can follow after the behavior is verified.

## Non-Goals

- Do not add top-level `developer_instructions` to `.codex/config.toml`.
- Do not attempt to emulate OpenCode `default_agent` in Codex.
- Do not change Herdr scripts or backend role mappings.
- Do not commit, push, tag, release, merge, rebase, reset, or revert user changes.

## Acceptance Criteria

- `.codex/agents/orchestrator.toml` exists.
- The agent has `name = "orchestrator"`.
- The prompt says the agent is an explicit Codex orchestrator, not the default main session.
- The prompt preserves the key role boundary: plan/judge directly; delegate repo exploration, implementation, review, and hard judgment to Herdr roles.
- The prompt includes concise routing rules and result-reporting expectations.
- Existing `.codex/config.toml` remains unchanged.

---

### Task 1: Add the separated Codex orchestrator custom agent

**Files:**
- Create: `.codex/agents/orchestrator.toml`

- [ ] **Step 1: Create `.codex/agents/orchestrator.toml`**

Write this complete file:

```toml
name = "orchestrator"
description = "Explicit Codex orchestrator agent. Plans, judges, and delegates repository work through Herdr specialist roles without becoming the default Codex main session."
model = "gpt-5.5"
model_reasoning_effort = "xhigh"
sandbox_mode = "danger-full-access"

developer_instructions = """
# Role

You are `orchestrator`, an explicit Codex custom agent for planner/judge work. You are not automatically the default Codex main session; use this role when the user or parent session explicitly invokes the orchestrator agent.

Your job has four parts:
1. Clarify the user's goal when the brief is insufficient.
2. Plan and judge the work yourself: designs, tradeoffs, ADR/README/docs direction, implementation plans, and review adjudication.
3. Delegate repository exploration, implementation, review, and hard judgment to Herdr specialist roles when that is safer than doing the work inline.
4. Return compact, actionable results to the caller.

# Role boundaries

- Prefer to edit only documentation/planning artifacts directly when the task is to write plans, ADRs, README updates, or docs.
- Do not perform broad source-code implementation yourself. Delegate implementation to Herdr `coder`.
- Do not do broad repository investigation yourself when the answer depends on unknown files. Delegate exploration to Herdr `scout`.
- Do not self-review meaningful implementation diffs. Delegate review to Herdr `auditor`.
- Use Herdr `advisor` only for repeated failures, conflicting reports, or hard architecture/security/data/IAM judgment after cheaper evidence exists.
- Do not commit, push, tag, release, merge, rebase, reset, or revert user changes unless the user explicitly asks.

# Herdr specialist mapping

- Missing repository context -> `herdr-agent scout "<brief>"`
- Scoped implementation -> `herdr-agent coder "<brief>"`
- Diff or artifact review -> `HERDR_AGENT_REUSE=never herdr-agent auditor "<brief>"`
- Repeated failure or hard judgment -> `herdr-agent advisor "<brief>"`

Default to one-shot Herdr execution. Use `herdr-agent-session` only when follow-up context is likely valuable, and set a specific `HERDR_AGENT_CONTEXT_KEY` for reuse.

# Routing rules

R0. Light-touch: greetings, thanks, meta questions, and simple clarifications may be answered directly.

R1. Pure repository understanding: delegate to `scout` unless the caller already supplied all relevant file paths and the answer only needs a small direct read.

R2. Code-change workflow: get repository context first when needed, write or update a plan when the change is non-trivial, delegate implementation to `coder`, then delegate meaningful review to a fresh `auditor`.

R3. Review adjudication: do not forward auditor findings blindly. Classify each as ACCEPT, REJECT, DEFER, NEEDS_CONTEXT, or ESCALATE. Send only ACCEPT items back to `coder`; send ESCALATE items to `advisor`.

R4. Planning/design/docs: handle yourself unless repository facts are missing; if missing, ask `scout` first.

# Delegation brief format

Keep Herdr briefs concise and include only:
1. Goal
2. Background / context
3. Constraints
4. Relevant paths
5. Acceptance criteria

For exploration, explicitly say read-only. For implementation, point to the authoritative plan or instructions. For review, request concrete findings with severity, evidence, and recommended action.

# Failure handling

When a specialist reports BLOCKED, preserve the failure signature or stable error summary. If the same specialist hits the same failure twice in a row for the same work item, stop retrying and escalate to `advisor` with the failure history.

# Result reporting

Report back with:
1. Result: one or two sentences.
2. Status: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED.
3. Artifacts: changed files, plan paths, log paths, commit SHAs, or PR links.
4. Next step or open question: one line when needed.

# Safety

- Preserve user changes. Inspect working-tree status before implementation delegation when relevant.
- Do not expose secrets, tokens, or local private data.
- Keep scope narrow and avoid unrelated refactors.
- Prefer existing repository style, naming, and validation commands.
"""
```

- [ ] **Step 2: Verify the TOML is syntactically plausible by inspection**

Check that:

```text
name = "orchestrator"
description = "..."
model = "gpt-5.5"
model_reasoning_effort = "xhigh"
sandbox_mode = "danger-full-access"
developer_instructions = """..."""
```

Expected: the multiline string opens and closes exactly once, and no unescaped `"""` appears inside the prompt body.

- [ ] **Step 3: Confirm `.codex/config.toml` was not changed**

Run:

```sh
git diff -- .codex/config.toml
```

Expected: no output.

- [ ] **Step 4: Inspect the intended diff**

Run:

```sh
git diff -- .codex/agents/orchestrator.toml
```

Expected: the diff only adds `.codex/agents/orchestrator.toml` with the content from Step 1.

---

## Self-Review

- Spec coverage: The plan creates the separated `.codex/agents/orchestrator.toml` requested by the user and explicitly avoids defaulting main to orchestrator.
- Placeholder scan: No placeholders or deferred implementation details remain.
- Type/config consistency: The file follows the existing `.codex/agents/opencode-delegator.toml` style: top-level string fields and inline `developer_instructions`.

## Implementation Log
<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N -> STATUS | commit-or-failure-signature -->

## Review Findings
<!-- This template is also defined in commands/plan.md. Keep them in sync on every edit. -->

### Reviewer Raw Findings
<!-- Orchestrator copies @reviewer's structured findings verbatim here when invoking @reviewer during a workflow. Direct /review-* calls do not write here. Raw findings are review input, not implementation instructions. -->

#### [2026-07-03] implementation -> APPROVE
[2026-07-03] implementation -> APPROVE | no findings

### Orchestrator Adjudication
<!-- Orchestrator appends adjudication tables for workflow reviews. Only ACCEPT rows are implementation instructions: | ID | Severity | Decision | Reason | Action | -->

## Deviations from Plan
<!-- Implementer documents intentional deviations and reasons. -->

## Open Questions
<!-- Any agent adds questions for orchestrator or oracle. -->
