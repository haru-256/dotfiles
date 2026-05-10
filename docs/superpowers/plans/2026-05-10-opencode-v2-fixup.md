# OpenCode v2 Setup Fix-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the bugs and improvements identified in the OpenCode v2 multi-agent setup review.

**Architecture:** Edit 4 files under `.config/opencode/` to (1) restore the lost living-section template in `commands/plan-v2.md`, (2) restore the dropped critical thinking instruction in `commands/review-impl-v2.md`, (3) tighten dispatcher_v2 permissions in `opencode.json` (deny webfetch/websearch, keep skill), and (4) add a skill safety-net to `prompts/dispatcher_v2.md`. All changes are config-only and independently reversible.

**Tech Stack:** OpenCode config (JSON for `opencode.json`, Markdown for prompts and commands)

---

## Background

The v2 multi-agent setup (dispatcher_v2 / planner_v2 / implementer_v2 / explorer_v2 / reviewer_v2 / arbiter_v2) was introduced alongside the v1 setup. A review identified 4 issues:

| # | Severity | Issue | File |
|---|---|---|---|
| 1 | 🔴 Bug | `commands/plan-v2.md` lost the inline living-section template that v1's `plan.md` had. The current file lists section names but `Planner V2 Adjudication` is shown as if top-level when it is actually nested under `Review Findings`. The cross-reference comment in `prompts/planner_v2.md` ("This template is also defined in commands/plan-v2.md") becomes false. | `.config/opencode/commands/plan-v2.md` |
| 2 | 🟡 Regression | `commands/review-impl-v2.md` dropped the "Generate critical thinking findings before forming the verdict" instruction that v1 `review-impl.md` had. While `prompts/reviewer_v2.md` retains the elicitation section, command-side reinforcement helps trigger it reliably. | `.config/opencode/commands/review-impl-v2.md` |
| 3 | 🟡 Improvement | `dispatcher_v2` is routing-only; webfetch/websearch are unnecessary research tools that broaden blast radius. **`skill: allow` MUST be kept** because dispatcher_v2 is the primary agent (`mode: primary`), and `using-superpowers` plus `/<skill-name>` slash commands need skill access on the primary agent. | `.config/opencode/opencode.json` |
| 4 | 🟢 Hardening | `prompts/dispatcher_v2.md` should explicitly state that skill invocations don't change its routing role. This prevents `using-superpowers` ("invoke skills before any response") from causing dispatcher to start brainstorming/planning instead of routing. | `.config/opencode/prompts/dispatcher_v2.md` |

**Reference**: `docs/superpowers/notes/2026-05-10-opencode-gpt55-token-reduction-claude-response.md` and the follow-up discussion turns establishing that `skill: allow` must stay on dispatcher_v2.

## Working directory

The v2 files are currently **untracked in main** at `/Users/haru256/Documents/projects/dotfiles`. They have not been committed yet. The `.config/opencode/opencode.json` is also currently shown as modified (with the v2 agent blocks added).

The implementer should:

1. `cd /Users/haru256/Documents/projects/dotfiles` (main checkout root)
2. Edit files relative to that root
3. Commit each fix as its own commit. Untracked v2 files become tracked with the fix already applied — that is acceptable.

Optional: if cleaner history is desired, commit the v2 baseline (current untracked files + `opencode.json` modifications) as a separate commit *before* applying fixes. This is **out of scope** of this plan.

## File Structure

| File | What changes | Task |
|---|---|---|
| `.config/opencode/commands/plan-v2.md` | Replace section-name list with full inline template (with `## Review Findings` containing nested `### Reviewer Raw Findings` and `### Planner V2 Adjudication` subsections) | Task 1 |
| `.config/opencode/commands/review-impl-v2.md` | Append "Generate critical thinking findings before forming the verdict." to the framework sentence | Task 2 |
| `.config/opencode/opencode.json` | In `agent.dispatcher_v2.permission`, change `webfetch` and `websearch` from `"allow"` to `"deny"`. Keep `skill: allow`. | Task 3 |
| `.config/opencode/prompts/dispatcher_v2.md` | Append a new bullet to the `# Do Not` section about skill behavior | Task 4 |

---

## Pre-flight

- [ ] **Step 1: Switch to main checkout**

```bash
cd /Users/haru256/Documents/projects/dotfiles
```

Verify with `pwd`.
Expected: `/Users/haru256/Documents/projects/dotfiles`

- [ ] **Step 2: Verify branch and v2 file state**

Run:
```bash
git branch --show-current && \
git status --short | grep -E "v2|opencode\.json"
```

Expected: branch is `main`, and you see (order may vary):
```
 M .config/opencode/opencode.json
?? .config/opencode/commands/adr-v2.md
?? .config/opencode/commands/explore-v2.md
?? .config/opencode/commands/feature-v2.md
?? .config/opencode/commands/plan-v2.md
?? .config/opencode/commands/quick-fix-v2.md
?? .config/opencode/commands/review-adr-v2.md
?? .config/opencode/commands/review-docs-v2.md
?? .config/opencode/commands/review-impl-v2.md
?? .config/opencode/commands/review-plan-v2.md
?? .config/opencode/prompts/arbiter_v2.md
?? .config/opencode/prompts/dispatcher_v2.md
?? .config/opencode/prompts/explorer_v2.md
?? .config/opencode/prompts/implementer_v2.md
?? .config/opencode/prompts/planner_v2.md
?? .config/opencode/prompts/reviewer_v2.md
```

- [ ] **Step 3: Verify the 4 target files exist**

Run:
```bash
ls -la \
  .config/opencode/commands/plan-v2.md \
  .config/opencode/commands/review-impl-v2.md \
  .config/opencode/prompts/dispatcher_v2.md \
  .config/opencode/opencode.json
```

Expected: all 4 files listed (no "No such file" errors).

- [ ] **Step 4: Verify `opencode.json` parses**

Run:
```bash
jq . .config/opencode/opencode.json > /dev/null && echo OK
```

Expected: `OK`

---

### Task 1: Restore living-section template in plan-v2.md

**Files:**
- Modify: `.config/opencode/commands/plan-v2.md`

**Why:** Bug. v1 `plan.md` inlined the full living-section template. v2 `plan-v2.md` regressed to a flat name list, mixing `Planner V2 Adjudication` (a `###` subsection) with top-level `##` sections. This causes (a) the planner to potentially create the wrong heading level, and (b) makes the cross-reference comment in `prompts/planner_v2.md` ("This template is also defined in commands/plan-v2.md. Keep them in sync") factually wrong since the template no longer exists in `plan-v2.md`.

- [ ] **Step 1: Read current state**

Run:
```bash
cat .config/opencode/commands/plan-v2.md
```

Expected current content (verbatim):

```markdown
---
description: Create a Superpowers implementation plan through the v2 planner
agent: planner_v2
---

Create a Superpowers implementation plan for the following task:
$ARGUMENTS

Rules:
- Use the writing-plans skill when applicable.
- Save the plan under `docs/superpowers/plans/`.
- Append living-document sections for Implementation Log, Review Findings, Planner V2 Adjudication, Deviations from Plan, and Open Questions.
- Do not implement the plan.
- After saving, report the plan path and recommended execution mode.
```

If the content differs, stop and report `BLOCKED` with `failure_signature: precondition/plan-v2/content-mismatch`.

- [ ] **Step 2: Overwrite plan-v2.md with v1-style inline template**

Replace the entire content of `.config/opencode/commands/plan-v2.md` with the following exact bytes:

````markdown
---
description: Create a Superpowers implementation plan through the v2 planner
agent: planner_v2
---

Create a Superpowers implementation plan for the following task:
$ARGUMENTS

Rules:
- Use the writing-plans skill when applicable.
- Save the plan under `docs/superpowers/plans/`.
- After the plan body is written, append the following living-document sections at the end (if not already present):

  ## Implementation Log
  <!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N -> STATUS | commit-or-failure-signature -->

  ## Review Findings
  <!-- This template is also defined in prompts/planner_v2.md. Keep them in sync on every edit. -->

  ### Reviewer Raw Findings
  <!-- Planner V2 copies @reviewer_v2's structured findings verbatim here when invoking @reviewer_v2
       during a workflow. Direct /review-*-v2 calls do not write here.
       Raw findings are review input (audit history), not implementation instructions. -->

  ### Planner V2 Adjudication
  <!-- Planner V2 appends adjudication tables for v2 workflow reviews.
       Only ACCEPT rows are implementation instructions:
       | ID | Severity | Decision | Reason | Action | -->

  ## Deviations from Plan
  <!-- Implementer documents intentional deviations and reasons -->

  ## Open Questions
  <!-- Any agent adds questions for planner_v2 or arbiter_v2 -->

- Do not implement the plan.
- After saving, report the plan path and recommended execution mode.
````

- [ ] **Step 3: Verify all 6 sections present and correctly nested**

Run:
```bash
grep -q "^  ## Implementation Log" .config/opencode/commands/plan-v2.md && \
grep -q "^  ## Review Findings" .config/opencode/commands/plan-v2.md && \
grep -q "^  ### Reviewer Raw Findings" .config/opencode/commands/plan-v2.md && \
grep -q "^  ### Planner V2 Adjudication" .config/opencode/commands/plan-v2.md && \
grep -q "^  ## Deviations from Plan" .config/opencode/commands/plan-v2.md && \
grep -q "^  ## Open Questions" .config/opencode/commands/plan-v2.md && \
echo "All sections present and correctly nested"
```

Expected: `All sections present and correctly nested`

- [ ] **Step 4: Confirm cross-reference comment in planner_v2.md is now accurate**

Run:
```bash
grep "commands/plan-v2.md" .config/opencode/prompts/planner_v2.md
```

Expected: 1 match — the line:
```
<!-- This template is also defined in commands/plan-v2.md. Keep them in sync on every edit. -->
```
This grep already matched before our changes. We are confirming the comment is no longer false (the referenced template now actually exists in `plan-v2.md`).

- [ ] **Step 5: Commit**

```bash
git add .config/opencode/commands/plan-v2.md
git commit -m "fix(opencode): plan-v2.md に living-section template を inline で復活"
```

---

### Task 2: Restore critical thinking instruction in review-impl-v2.md

**Files:**
- Modify: `.config/opencode/commands/review-impl-v2.md`

**Why:** Regression. v1 `review-impl.md` reinforced reviewer's critical thinking elicitation step at the command level. v2 dropped this. Although `prompts/reviewer_v2.md` retains the elicitation section, command-side reinforcement makes the elicitation more reliable to trigger.

- [ ] **Step 1: Read current state**

Run:
```bash
cat .config/opencode/commands/review-impl-v2.md
```

Expected current content (verbatim):

```markdown
---
description: Critically review an implementation diff through v2 reviewer
agent: reviewer_v2
---

ARTIFACT_TYPE: implementation

Target:
$ARGUMENTS

Read the plan first if a plan path is provided, then the diff (`git diff main...HEAD`). Apply only the implementation review framework.

List individual issues under Critical issues / Non-blocking suggestions using the Finding format defined in reviewer_v2.md.
```

If the content differs, stop and report `BLOCKED` with `failure_signature: precondition/review-impl-v2/content-mismatch`.

- [ ] **Step 2: Append the critical thinking sentence to the framework line**

Edit `.config/opencode/commands/review-impl-v2.md`. Replace this exact line:

```
Read the plan first if a plan path is provided, then the diff (`git diff main...HEAD`). Apply only the implementation review framework.
```

With:

```
Read the plan first if a plan path is provided, then the diff (`git diff main...HEAD`). Apply only the implementation review framework. Generate critical thinking findings before forming the verdict.
```

(Only one sentence is added — the rest of the file stays unchanged.)

- [ ] **Step 3: Verify the new sentence is present**

Run:
```bash
grep -c "Generate critical thinking findings" .config/opencode/commands/review-impl-v2.md
```

Expected: `1`

- [ ] **Step 4: Verify the framework line is intact**

Run:
```bash
grep "Apply only the implementation review framework" .config/opencode/commands/review-impl-v2.md
```

Expected: 1 match showing the full sentence with both "Apply only the implementation review framework." and "Generate critical thinking findings before forming the verdict." present.

- [ ] **Step 5: Commit**

```bash
git add .config/opencode/commands/review-impl-v2.md
git commit -m "fix(opencode): review-impl-v2.md に critical thinking 喚起を復活"
```

---

### Task 3: Tighten dispatcher_v2 permissions

**Files:**
- Modify: `.config/opencode/opencode.json` (within `agent.dispatcher_v2.permission` block only)

**Why:** Improvement. dispatcher_v2 is routing-only. webfetch/websearch are research tools that don't apply to routing decisions. Denying them reinforces the role and reduces blast radius.

**`skill: allow` is intentionally kept**. dispatcher_v2 is the primary agent (`mode: primary`). The `using-superpowers` skill only runs on primary agents (subagents are skipped via `<SUBAGENT-STOP>`). Denying skill would break the using-superpowers entry point and any `/<skill-name>` slash command invoked while dispatcher_v2 is the active agent.

- [ ] **Step 1: Read current dispatcher_v2 permission state**

Run:
```bash
jq '.agent.dispatcher_v2.permission | {webfetch, websearch, skill}' .config/opencode/opencode.json
```

Expected:
```json
{
  "webfetch": "allow",
  "websearch": "allow",
  "skill": "allow"
}
```

If the output differs, stop and report `BLOCKED` with `failure_signature: precondition/dispatcher_v2-permission/state-mismatch`.

- [ ] **Step 2: Edit opencode.json — change `webfetch` and `websearch` to `"deny"`**

Edit `.config/opencode/opencode.json`. In the `agent.dispatcher_v2.permission` block (which appears around line 13–38), find the lines:

```json
        "external_directory": "allow",
        "webfetch": "allow",
        "websearch": "allow",
        "question": "allow",
        "codesearch": "allow",
        "skill": "allow",
        "todowrite": "allow",
```

And change them to:

```json
        "external_directory": "allow",
        "webfetch": "deny",
        "websearch": "deny",
        "question": "allow",
        "codesearch": "allow",
        "skill": "allow",
        "todowrite": "allow",
```

**Only `webfetch` and `websearch` change**. `skill` stays `allow`. Other lines are unchanged.

- [ ] **Step 3: Verify JSON syntax is still valid**

Run:
```bash
jq . .config/opencode/opencode.json > /dev/null && echo OK
```

Expected: `OK`

If `jq` reports a syntax error, stop and report `BLOCKED` with `failure_signature: edit/opencode.json/json-parse-error`.

- [ ] **Step 4: Verify dispatcher_v2 permission changes**

Run:
```bash
jq '.agent.dispatcher_v2.permission | {webfetch, websearch, skill}' .config/opencode/opencode.json
```

Expected:
```json
{
  "webfetch": "deny",
  "websearch": "deny",
  "skill": "allow"
}
```

- [ ] **Step 5: Verify other v2 agents are unchanged**

Run:
```bash
jq '{
  planner_v2_skill: .agent.planner_v2.permission.skill,
  planner_v2_webfetch: .agent.planner_v2.permission.webfetch,
  implementer_v2_webfetch: .agent.implementer_v2.permission.webfetch,
  explorer_v2_webfetch: .agent.explorer_v2.permission.webfetch,
  reviewer_v2_webfetch: .agent.reviewer_v2.permission.webfetch
}' .config/opencode/opencode.json
```

Expected: every value is `"allow"`. If any is `"deny"`, you accidentally edited the wrong block — revert with `git checkout .config/opencode/opencode.json` and retry from Step 2.

- [ ] **Step 6: Commit**

```bash
git add .config/opencode/opencode.json
git commit -m "fix(opencode): dispatcher_v2 の webfetch/websearch を deny、skill は維持"
```

---

### Task 4: Add skill safety-net to dispatcher_v2 prompt

**Files:**
- Modify: `.config/opencode/prompts/dispatcher_v2.md`

**Why:** Hardening. `using-superpowers` runs on primary agents at session start and instructs them to "invoke skills before any response, even with 1% chance of relevance." For dispatcher_v2 (routing-only), this rule could cause it to start doing brainstorming/planning itself instead of routing. Although `using-superpowers` defines its own priority order ("user instructions override skills"), making the override explicit in the dispatcher prompt removes ambiguity.

- [ ] **Step 1: Read current `# Do Not` section**

Run:
```bash
grep -A 10 "^# Do Not" .config/opencode/prompts/dispatcher_v2.md
```

Expected:
```
# Do Not
- Do not write plans, ADRs, README, or docs.
- Do not implement code.
- Do not adjudicate reviewer findings.
- Do not call @reviewer_v2 directly.
- Do not call @arbiter_v2 directly.
- Do not narrate hidden reasoning.
```

(The output may include the next blank line and section header; that's fine. The key is that those 6 bullets are present.)

If the section differs, stop and report `BLOCKED` with `failure_signature: precondition/dispatcher_v2-prompt/section-mismatch`.

- [ ] **Step 2: Append safety-net rule as a new bullet**

Edit `.config/opencode/prompts/dispatcher_v2.md`. Replace this exact block:

```
# Do Not
- Do not write plans, ADRs, README, or docs.
- Do not implement code.
- Do not adjudicate reviewer findings.
- Do not call @reviewer_v2 directly.
- Do not call @arbiter_v2 directly.
- Do not narrate hidden reasoning.
```

With:

```
# Do Not
- Do not write plans, ADRs, README, or docs.
- Do not implement code.
- Do not adjudicate reviewer findings.
- Do not call @reviewer_v2 directly.
- Do not call @arbiter_v2 directly.
- Do not narrate hidden reasoning.
- Skills you invoke (including using-superpowers) must not change your role. If a skill suggests planning, brainstorming, or implementation work, route to the appropriate subagent instead of executing the work yourself.
```

The new line is appended as the 7th bullet under `# Do Not`. No other content changes.

- [ ] **Step 3: Verify the new line is present**

Run:
```bash
grep -c "Skills you invoke" .config/opencode/prompts/dispatcher_v2.md
```

Expected: `1`

- [ ] **Step 4: Verify the prior 6 bullets are still present**

Run:
```bash
grep -c "^- Do not" .config/opencode/prompts/dispatcher_v2.md
```

Expected: `6` (the 6 original `Do not ...` bullets; the new bullet starts with "Skills you invoke" so it doesn't count, which is intentional — confirms originals are intact).

- [ ] **Step 5: Commit**

```bash
git add .config/opencode/prompts/dispatcher_v2.md
git commit -m "chore(opencode): dispatcher_v2 prompt に skill 起動時の routing 維持ルールを追記"
```

---

### Task 5: Final verification

**Files:** (no edits — verification only)

- [ ] **Step 1: All four fix commits are present in order**

Run:
```bash
git log --oneline -4
```

Expected (newest first):
```
<sha> chore(opencode): dispatcher_v2 prompt に skill 起動時の routing 維持ルールを追記
<sha> fix(opencode): dispatcher_v2 の webfetch/websearch を deny、skill は維持
<sha> fix(opencode): review-impl-v2.md に critical thinking 喚起を復活
<sha> fix(opencode): plan-v2.md に living-section template を inline で復活
```

- [ ] **Step 2: opencode.json parses and dispatcher_v2 permissions are correct**

Run:
```bash
jq . .config/opencode/opencode.json > /dev/null && \
jq '.agent.dispatcher_v2.permission | {edit, webfetch, websearch, skill}' .config/opencode/opencode.json
```

Expected:
```
{
  "edit": "deny",
  "webfetch": "deny",
  "websearch": "deny",
  "skill": "allow"
}
```

- [ ] **Step 3: plan-v2.md sections present and correctly nested**

Run:
```bash
grep -q "^  ## Implementation Log" .config/opencode/commands/plan-v2.md && \
grep -q "^  ## Review Findings" .config/opencode/commands/plan-v2.md && \
grep -q "^  ### Reviewer Raw Findings" .config/opencode/commands/plan-v2.md && \
grep -q "^  ### Planner V2 Adjudication" .config/opencode/commands/plan-v2.md && \
grep -q "^  ## Deviations from Plan" .config/opencode/commands/plan-v2.md && \
grep -q "^  ## Open Questions" .config/opencode/commands/plan-v2.md && \
echo "All sections present and correctly nested"
```

Expected: `All sections present and correctly nested`

- [ ] **Step 4: review-impl-v2.md has critical thinking instruction**

Run:
```bash
grep -c "Generate critical thinking findings" .config/opencode/commands/review-impl-v2.md
```

Expected: `1`

- [ ] **Step 5: dispatcher_v2.md has skill safety-net**

Run:
```bash
grep -c "Skills you invoke" .config/opencode/prompts/dispatcher_v2.md
```

Expected: `1`

- [ ] **Step 6: No unintended side-effects in v2 prompts/commands**

Run:
```bash
git diff HEAD~4 HEAD --stat
```

Expected: exactly 4 files changed:
```
 .config/opencode/commands/plan-v2.md         |  ...
 .config/opencode/commands/review-impl-v2.md  |  ...
 .config/opencode/opencode.json               |  ...
 .config/opencode/prompts/dispatcher_v2.md    |  ...
```

If more files appear, investigate before reporting DONE.

- [ ] **Step 7: Smoke test (manual, optional)**

If end-to-end verification is desired:

1. Start OpenCode in a fresh terminal.
2. Confirm the default agent is `dispatcher_v2` (no warnings on startup).
3. Try `/plan-v2 dummy task to verify section nesting`. Confirm the resulting plan in `docs/superpowers/plans/` has correctly nested sections (`### Reviewer Raw Findings` and `### Planner V2 Adjudication` as `###` under `## Review Findings`).
4. Try `/review-impl-v2 some-target`. Confirm reviewer outputs the critical thinking findings block (Failure modes / Steel-man alternative / Unstated assumptions / Senior engineer rejection).
5. Type a natural-language request (e.g. "fix the typo in README"). Confirm dispatcher_v2 routes to `@implementer_v2` without trying to do work itself.
6. Type a natural-language request that triggers superpowers (e.g. "let me brainstorm a feature"). Confirm dispatcher_v2 still routes to `@planner_v2` and does not start brainstorming itself.

If anything is broken, roll back with: `git revert HEAD~3..HEAD` (or `HEAD~4..HEAD` to also revert Task 4's safety-net).

---

## Implementation Log
<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N -> STATUS | commit-or-failure-signature -->

## Review Findings

### Reviewer Raw Findings
<!-- Planner V2 copies @reviewer_v2's structured findings verbatim here when invoking @reviewer_v2
     during a workflow. Direct /review-*-v2 calls do not write here. -->

### Planner V2 Adjudication
<!-- Planner V2 appends adjudication tables for v2 workflow reviews.
     Only ACCEPT rows are implementation instructions:
     | ID | Severity | Decision | Reason | Action | -->

## Deviations from Plan
<!-- Implementer documents intentional deviations and reasons -->

## Open Questions
<!-- Any agent adds questions for planner_v2 or arbiter_v2 -->
