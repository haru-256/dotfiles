# Implementer Preflight Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the implementer stop with `NEEDS_CONTEXT` before any broad reading or editing when the brief is too vague to act on safely.

**Architecture:** Harden the implementer prompt by moving the ambiguity gate to the top of the prompt, changing the trigger from “before editing” to “before tool use,” and adding an explicit anti-loop rule for vague briefs. Verify with the previously failing `opencode run --agent implementer` scenario.

**Tech Stack:** opencode Markdown agent prompt, non-interactive `opencode run` empirical validation.

---

## Evidence

The failing empirical scenario was:

```text
Fix the dotfiles. I need better config management.
```

Expected behavior: return `NEEDS_CONTEXT`.

Observed behavior: timeout after 120 seconds, 44 tool calls, no `NEEDS_CONTEXT`.

Root cause from validation report:

1. Existing pre-flight section is after `Inputs` and `Rules`, so the model starts following “run checks / inspect worktree” style rules first.
2. Existing wording says `Before editing`, which permits broad exploration before the stop decision.
3. `kimi-k2.6` entered a stable repeated tool-call loop instead of breaking out with a status.

## File Structure

- Modify `.config/opencode/prompts/implementer.md`: move and rewrite pre-flight as a top-level hard gate before `Inputs you should rely on` and `Rules`.
- Verify with `opencode run --agent implementer` on the known failing prompt.

---

### Task 1: Move pre-flight to a hard gate at the top

**Files:**
- Modify: `.config/opencode/prompts/implementer.md`

- [ ] **Step 1: Locate current pre-flight section**

Find the existing `## Pre-flight check` section in `.config/opencode/prompts/implementer.md`.

- [ ] **Step 2: Replace it with a hard gate near the top**

Move the pre-flight content so it appears immediately after `# Role` and before `# Inputs you should rely on`.

Use this exact text:

```md
# Pre-tool-use ambiguity gate

Before using any tool, reading broadly, or editing any file, decide whether the brief is actionable.

Return `NEEDS_CONTEXT` immediately if the brief lacks any of these:

- concrete target behavior or acceptance criteria
- relevant path, plan path, or sufficiently specific impact area
- scope boundaries that distinguish required work from optional cleanup or redesign

For vague requests like “fix the repo,” “improve config,” “clean this up,” or “make it better,” do not inspect the repository to infer the missing goal. Ask for the missing context instead.

This gate runs before git status, file reads, search, tests, or implementation. If this gate returns `NEEDS_CONTEXT`, do not use tools first.
```

- [ ] **Step 3: Remove duplicate old pre-flight section**

Ensure there is only one pre-flight/pre-tool-use ambiguity section. Remove the old `## Pre-flight check` block if it remains lower in the file.

---

### Task 2: Add anti-loop stop rule

**Files:**
- Modify: `.config/opencode/prompts/implementer.md`

- [ ] **Step 1: Add loop guard under Rules or Stop conditions**

Add this text under `# Rules` or immediately before `# Stop conditions (NEEDS_CONTEXT)`:

```md
- If you notice you are repeating the same read/search/check pattern without new information, stop and return `NEEDS_CONTEXT` with `failure_signature: ambiguous_scope/repeated_tool_loop/missing_actionable_brief`.
```

- [ ] **Step 2: Preserve report format**

Ensure the existing report format still requires status and `failure_signature` when blocked.

---

### Task 3: Re-run empirical validation

**Files:**
- Verify: `.config/opencode/prompts/implementer.md`

- [ ] **Step 1: Run the known failing scenario**

Run:

```bash
mise exec -- opencode run \
  --agent implementer \
  --format json \
  --dir /Users/haru256/Documents/projects/dotfiles \
  --dangerously-skip-permissions \
  "Fix the dotfiles. I need better config management."
```

Expected:

- returns within 30 seconds
- no broad repository exploration loop
- no file edits
- output status is `NEEDS_CONTEXT`
- includes a missing-context explanation

- [ ] **Step 2: Check working tree**

Run:

```bash
git diff -- .config/opencode/prompts/implementer.md
```

Expected: only the prompt hardening changes appear for this file.

- [ ] **Step 3: Report result**

Append one implementation log line to this plan:

```md
[2026-05-24] attempt #1 -> DONE | implementer-preflight-hardening
```

If validation still fails, append:

```md
[2026-05-24] attempt #1 -> BLOCKED | ambiguous_scope/repeated_tool_loop/preflight_not_triggered
```

and include the output log path.

## Implementation Log
<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N -> STATUS | commit-or-failure-signature -->
[2026-05-24] attempt #1 -> DONE | implementer-preflight-hardening

## Review Findings
<!-- This template is also defined in commands/plan.md. Keep them in sync on every edit. -->

### Reviewer Raw Findings
<!-- Orchestrator copies @reviewer's structured findings verbatim here when invoking @reviewer during a workflow. Direct /review-* calls do not write here. Raw findings are review input, not implementation instructions. -->

#### [2026-05-24] implementation -> APPROVE
Critical issues:
- None.
Non-blocking suggestions:
- F1: Severity MINOR, Confidence HIGH, Category plan / process. Evidence: Plan lines 69–71 (Task 1, Step 3) instructs removal of old `## Pre-flight check` block; `git show 1f944a6` confirms no such section existed in the file. Why it matters: the plan's root cause analysis was inaccurate. Recommended action: add a Deviations entry noting Task 1, Step 3 was vacuously satisfied and the root cause was absence of a gate, not misplacement. Must fix before merge: no.
- F2: Severity NIT, Confidence LOW, Category maintainability. Evidence: prompt line 49 anti-loop rule placed under `# Rules` rather than under `# Stop conditions (NEEDS_CONTEXT)`. Why it matters: semantically a stop condition. Recommended action: consider moving it. Must fix before merge: no.
- F3: Severity MINOR, Confidence LOW, Category test. Evidence: Plan Task 3 specifies a single validation scenario. Why it matters: false-positive rate on borderline actionable briefs is unknown. Recommended action: document follow-up task to test 2–3 borderline cases. Must fix before merge: no.

### Orchestrator Adjudication
<!-- Orchestrator appends adjudication tables for workflow reviews. Only ACCEPT rows are implementation instructions: | ID | Severity | Decision | Reason | Action | -->

| ID | Severity | Decision | Reason | Action |
|----|----------|----------|--------|--------|
| F1 | MINOR | ACCEPT | The plan evidence note is valid and cheap to correct in the audit trail; it does not affect prompt correctness. | Add a deviation entry clarifying the old pre-flight section did not exist. |
| F2 | NIT | REJECT | The plan explicitly allowed either `Rules` or immediately before `Stop conditions`; current placement is spec-compliant and already effective in validation. | No action. |
| F3 | MINOR | DEFER | Valid empirical-hardening follow-up, but outside the current single-regression-fix plan. | Track borderline prompt testing as a follow-up. |

## Deviations from Plan
<!-- Implementer documents intentional deviations and reasons. -->

- [2026-05-24] Task 1 Step 3 was vacuously satisfied: no old lower `## Pre-flight check` section existed to remove. The root cause was absence of a pre-tool-use ambiguity gate in the active prompt, not merely misplacement of an existing gate.

## Open Questions
<!-- Any agent adds questions for orchestrator or oracle. -->

- [defer] [2026-05-24] F3: Run 2–3 borderline implementer prompt tests to measure false-positive risk for briefs that include a path or behavior but omit explicit scope boundaries.
