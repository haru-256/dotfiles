# Opencode Agent Structural Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the accepted structural fixes to the opencode agent configuration and prompts, excluding P0 items and excluding oracle hidden changes.

**Architecture:** Keep the existing 1-primary + 4-specialist design. Make only clarifying prompt/config changes: disable built-in agents, add implementer pre-flight checks, tighten orchestrator edge-case handling, improve explorer hybrid/config-only guidance, and add oracle confidence/explorer-use guidance.

**Tech Stack:** opencode JSON config, Markdown agent prompts under `.config/opencode/prompts/`.

---

## Scope

Accepted changes:
- Disable built-in opencode agents.
- Add implementer pre-flight ambiguity check.
- Add orchestrator guidance for R0 vs R2a, insufficient explorer reports, ACCEPT+ESCALATE ordering, and malformed/contradictory reviewer findings.
- Add explorer Hybrid output template, config-only repo guidance, and concrete-risk threshold.
- Add oracle guidance for when to invoke `@explorer` and add `Confidence: HIGH | MEDIUM | LOW` to output.
- Add reviewer severity examples.

Explicit non-goals:
- Do not change P0 symlink/prompt-path handling.
- Do not narrow orchestrator permissions; opencode-go subagents inherit parent permissions.
- Do not add `hidden: true` to oracle.
- Do not rewrite the agent architecture.

## File Structure

- Modify `.config/opencode/opencode.json`: disable built-in agents without changing custom agent definitions.
- Modify `.config/opencode/prompts/orchestrator.md`: clarify routing/adjudication edge cases.
- Modify `.config/opencode/prompts/implementer.md`: add a pre-flight check before edits.
- Modify `.config/opencode/prompts/explorer.md`: clarify Hybrid output and config-only repos.
- Modify `.config/opencode/prompts/reviewer.md`: add severity calibration examples.
- Modify `.config/opencode/prompts/oracle.md`: add explorer-use rule and confidence output field.

---

### Task 1: Disable built-in agents

**Files:**
- Modify: `.config/opencode/opencode.json`

- [ ] **Step 1: Inspect existing agent object**

Read `.config/opencode/opencode.json` and locate the top-level `agent` object containing `orchestrator`, `implementer`, `explorer`, `reviewer`, and `oracle`.

- [ ] **Step 2: Add built-in disable entries**

Add or merge these entries inside the top-level `agent` object, preserving existing custom agents unchanged:

```json
"build": { "disable": true },
"plan": { "disable": true },
"general": { "disable": true },
"explore": { "disable": true },
"scout": { "disable": true }
```

If any of these keys already exist, preserve any existing fields and add `"disable": true`.

- [ ] **Step 3: Validate JSON syntax**

Run:

```bash
python -m json.tool .config/opencode/opencode.json >/tmp/opencode-config-check.json
```

Expected: command exits 0 with no JSON parse error.

---

### Task 2: Add implementer pre-flight ambiguity check

**Files:**
- Modify: `.config/opencode/prompts/implementer.md`

- [ ] **Step 1: Insert pre-flight section before stop conditions**

Add this section before `Stop conditions (NEEDS_CONTEXT)`:

```md
## Pre-flight check

Before editing, confirm the brief or referenced plan provides enough information to act without making product, architecture, or scope decisions yourself:

- concrete target behavior or acceptance criteria
- relevant path, plan path, or sufficiently specific impact area
- scope boundaries that distinguish required work from optional cleanup

If these are missing, return `NEEDS_CONTEXT` before reading broadly or editing. Do not start a partial implementation hoping the ambiguity will resolve mid-task.
```

- [ ] **Step 2: Keep existing stop conditions intact**

Verify the existing `Stop conditions (NEEDS_CONTEXT)` section remains after the new pre-flight section and still covers mid-implementation blockers.

---

### Task 3: Clarify orchestrator edge cases

**Files:**
- Modify: `.config/opencode/prompts/orchestrator.md`

- [ ] **Step 1: Clarify R0 vs R2a**

In `Routing Rules`, add a note near R0/R2a:

```md
Ambiguous code-change requests still route to R2a by default. Ask a clarifying question instead only when the user's goal itself is unclear, the request may be destructive/irreversible, or proceeding would require inventing product requirements rather than exploring the repo.
```

- [ ] **Step 2: Add insufficient explorer result handling**

Near the R2a flow or `Workflow Patterns`, add:

```md
If `@explorer` returns `DONE` but the report is too shallow or missing facts needed for a safe plan, do not guess. Re-dispatch the same `@explorer` session with a refined brief that names the missing facts and explains why continuity is useful. If the second report is still insufficient, surface the gap to the user.
```

- [ ] **Step 3: Clarify ACCEPT + ESCALATE ordering**

In `Review Adjudication`, refine the ACCEPT+ESCALATE rule to state:

```md
When ACCEPT and ESCALATE findings co-exist: surface the adjudication table to the user, then immediately dispatch `@implementer` for ACCEPT items and `@oracle` for ESCALATE items without waiting for user approval. Relay oracle's verdict once it returns.
```

- [ ] **Step 4: Add malformed/contradictory reviewer output handling**

In `Review Adjudication`, add:

```md
If reviewer output is malformed, has duplicate finding IDs, omits severity/evidence for blocking findings, or contains mutually contradictory findings where both cannot be true, classify the affected items as `NEEDS_CONTEXT` and re-dispatch `@reviewer` with the specific correction needed. Do not forward ambiguous or contradictory findings to `@implementer`.
```

---

### Task 4: Improve explorer guidance

**Files:**
- Modify: `.config/opencode/prompts/explorer.md`

- [ ] **Step 1: Add config/docs-only repo guidance**

In the repo exploration guidance, add:

```md
If the task concerns configuration, prompts, commands, documentation, or another repo with no relevant source/test files, adapt the behavioral pass: inspect runtime references, config merge points, command files, prompt files, docs, and permission boundaries instead of forcing a function/test search.
```

- [ ] **Step 2: Add Hybrid output template**

In the output structure section, add:

```md
For Hybrid mode, output in this order:

1. Repo Summary Report
2. External Research Brief
3. Reconciliation: where repo reality and external docs agree, diverge, or leave gaps
4. Risks / impact radius tied to concrete paths, sources, or runtime behavior
5. Exploration Log
6. Research Log

Do not duplicate the same fact in multiple sections unless the repetition explains a repo-vs-external contradiction.
```

- [ ] **Step 3: Calibrate risk threshold**

Add:

```md
Report risks only when they are tied to concrete paths, runtime behavior, permissions, public behavior, data integrity, workflow failure, or external source contradictions. Do not list purely theoretical risks without evidence.
```

---

### Task 5: Add reviewer severity calibration examples

**Files:**
- Modify: `.config/opencode/prompts/reviewer.md`

- [ ] **Step 1: Add severity examples near finding format or discipline**

Add:

```md
Severity calibration examples:

- `CRITICAL`: data loss, credential exposure, remote code execution, broken authentication/authorization, or migration/state corruption likely in normal use.
- `MAJOR`: violates acceptance criteria, causes user-visible incorrect behavior, creates security weakness without immediate exploit, breaks compatibility, or makes tests misleading.
- `MINOR`: maintainability, observability, error-message, or edge-case issue that is valid but does not block the stated goal.
- `NIT`: wording, formatting, naming, or style preference that does not affect correctness or maintainability materially.

Do not elevate a preference to `MAJOR` unless it has concrete correctness, security, data integrity, compatibility, or user-visible impact.
```

---

### Task 6: Improve oracle guidance and output

**Files:**
- Modify: `.config/opencode/prompts/oracle.md`

- [ ] **Step 1: Add explorer-use rule**

In `Decision principles`, add:

```md
Use `@explorer` only when the decision depends on missing repo facts or external facts that cannot be resolved from the provided context. Otherwise decide from the inherited context; do not request broad exploration as a substitute for judgment.
```

- [ ] **Step 2: Add confidence to output format**

In `Output format`, add a field:

```md
Confidence: HIGH | MEDIUM | LOW
```

Place it near the decision/verdict fields so callers can interpret how strongly to rely on the answer.

---

### Task 7: Verify changes

**Files:**
- Verify: `.config/opencode/opencode.json`
- Verify: `.config/opencode/prompts/*.md`

- [ ] **Step 1: Validate JSON**

Run:

```bash
python -m json.tool .config/opencode/opencode.json >/tmp/opencode-config-check.json
```

Expected: exits 0.

- [ ] **Step 2: Inspect diff for non-goals**

Run:

```bash
git diff -- .config/opencode/opencode.json .config/opencode/prompts/orchestrator.md .config/opencode/prompts/implementer.md .config/opencode/prompts/explorer.md .config/opencode/prompts/reviewer.md .config/opencode/prompts/oracle.md
```

Expected: diff contains only accepted structural changes. It must not narrow orchestrator permissions, change `{file:~/.config/...}` paths, or add oracle `hidden: true`.

- [ ] **Step 3: Report result**

Return:

```text
status: DONE | BLOCKED | NEEDS_CONTEXT
changed_files:
- <path>
verification:
- json validation: <pass/fail>
- diff non-goals: <pass/fail>
notes:
- <any deviations>
```

## Implementation Log
<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N -> STATUS | commit-or-failure-signature -->
[2026-05-23] attempt #1 -> DONE | no commit (uncommitted changes)

## Review Findings
<!-- This template is also defined in commands/plan.md. Keep them in sync on every edit. -->

### Reviewer Raw Findings
<!-- Orchestrator copies @reviewer's structured findings verbatim here when invoking @reviewer during a workflow. Direct /review-* calls do not write here. Raw findings are review input, not implementation instructions. -->

#### [2026-05-23] implementation -> APPROVE
[2026-05-23] implementation -> APPROVE | no findings

### Orchestrator Adjudication
<!-- Orchestrator appends adjudication tables for workflow reviews. Only ACCEPT rows are implementation instructions: | ID | Severity | Decision | Reason | Action | -->

## Deviations from Plan
<!-- Implementer documents intentional deviations and reasons. -->

## Open Questions
<!-- Any agent adds questions for orchestrator or oracle. -->
