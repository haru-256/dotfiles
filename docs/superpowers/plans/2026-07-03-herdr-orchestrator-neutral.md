# Herdr Orchestrator Neutrality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `using-herdr-agents` skill describe the parent orchestrator generically instead of assuming Codex, while keeping the current Herdr sub-agent role and backend defaults unchanged.

**Architecture:** Treat the parent as an arbitrary "orchestrator" or "parent agent" that owns planning, judgment, and user-facing decisions. Keep the worker roles and launch mapping as-is: Scout remains OpenCode by default with Cline fallback, Coder and Auditor remain Agy, and Advisor remains Codex unless a separate change explicitly revisits backend selection. Update tests so they protect the neutral parent wording and still protect the current sub-agent defaults.

**Tech Stack:** Markdown skill file, Markdown prompt files, POSIX shell regression tests.

## Global Constraints

- Do not change `herdr-agent` or `herdr-agent-session` runtime behavior unless tests reveal the docs cannot be made accurate without it.
- Preserve current sub-agent role defaults: `scout=opencode`, `coder=agy`, `auditor=agy`, `advisor=codex`.
- Preserve current model defaults and role prompts except for parent-orchestrator wording.
- Do not rename roles, commands, environment variables, or installed symlink targets.
- Do not touch unrelated dirty files, currently `.config/herdr/config.toml` and `.config/zed/prompts/prompts-library-db.0.mdb/lock.mdb`.
- Keep shell tests POSIX `sh`.

---

## File Structure

- Modify: `.agents/skills/using-herdr-agents/SKILL.md`
  - Responsibility: user-facing skill guidance. Replace Codex-as-parent wording with orchestrator-neutral wording while retaining examples and backend notes.
- Modify: `.agents/skills/using-herdr-agents/prompts/shared.md`
  - Responsibility: shared worker boundary. Replace "Codex Planner/Judge" with parent-orchestrator language.
- Modify: `.agents/skills/using-herdr-agents/prompts/scout.md`
  - Responsibility: Scout mission and output labels. Replace "Codex" references with "the parent orchestrator" or "orchestrator".
- Modify: `.agents/skills/using-herdr-agents/prompts/coder.md`
  - Responsibility: Coder output label. Replace "recommended next Codex action" with neutral wording.
- Modify: `.agents/skills/using-herdr-agents/prompts/advisor.md`
  - Responsibility: Advisor use cases and output labels. Keep the Advisor backend/model text as Codex-specific because that describes the sub-agent backend, not the parent orchestrator.
- Modify: `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`
  - Responsibility: regression coverage for neutral wording and unchanged backend defaults.
- Read-only expected: `.agents/skills/using-herdr-agents/scripts/herdr-agent`, `.agents/skills/using-herdr-agents/scripts/herdr-agent-lib`, `.agents/skills/using-herdr-agents/scripts/herdr-agent-session`
  - Responsibility: existing launch behavior. These should not need edits for this wording-only change.

---

### Task 1: Update Tests for Neutral Parent Wording

**Files:**
- Modify: `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`

**Interfaces:**
- Consumes: existing package files and dry-run helpers.
- Produces: regression checks that reject parent-Codex wording but still allow Codex as the Advisor backend.

- [ ] **Step 1: Replace the old skill wording assertion**

In `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`, replace:

```sh
assert_contains "$skill_text" "Do not delegate when Codex can answer faster"
```

with:

```sh
assert_contains "$skill_text" "Do not delegate when the parent agent can answer faster"
assert_not_contains "$skill_text" "Codex stays Planner/Judge"
assert_not_contains "$skill_text" "Codex can answer faster"
```

- [ ] **Step 2: Add prompt wording regression checks**

After the existing skill text assertions, add:

```sh
shared_prompt_text=$(cat "$PROMPT_DIR/shared.md")
scout_prompt_text=$(cat "$PROMPT_DIR/scout.md")
coder_prompt_text=$(cat "$PROMPT_DIR/coder.md")
advisor_prompt_text=$(cat "$PROMPT_DIR/advisor.md")

assert_contains "$shared_prompt_text" "launched by a parent orchestrator through Herdr"
assert_contains "$shared_prompt_text" "The parent orchestrator owns planning, final judgment, and user-facing decisions."
assert_contains "$shared_prompt_text" "The parent orchestrator decides what to do with every report."
assert_not_contains "$shared_prompt_text" "Codex Planner/Judge"
assert_not_contains "$shared_prompt_text" "parent Codex session"

assert_contains "$scout_prompt_text" "the parent orchestrator needs to write a safe brief"
assert_contains "$scout_prompt_text" "path the parent orchestrator should read directly before briefing Coder"
assert_not_contains "$scout_prompt_text" "Codex Planner/Judge"
assert_not_contains "$scout_prompt_text" "path Codex should read"

assert_contains "$coder_prompt_text" "recommended next parent-orchestrator action"
assert_not_contains "$coder_prompt_text" "recommended next Codex action"

assert_contains "$advisor_prompt_text" "The parent orchestrator needs a high-reasoning second pass before briefing Coder again"
assert_contains "$advisor_prompt_text" "exact brief the parent orchestrator should pass to Coder"
assert_not_contains "$advisor_prompt_text" "Codex Planner/Judge needs"
assert_not_contains "$advisor_prompt_text" "exact brief Codex should pass"
```

- [ ] **Step 3: Keep Advisor backend assertions unchanged**

Leave these existing assertions exactly as they are, because they verify the sub-agent backend default rather than the parent orchestrator:

```sh
assert_contains "$advisor_output" "BACKEND=codex"
assert_contains "$advisor_output" "MODEL=gpt-5.5"
assert_contains "$advisor_output" "THINKING=xhigh"
```

- [ ] **Step 4: Run the package test and confirm it fails before edits**

Run:

```sh
sh tests/herdr-agent.sh
```

Expected: FAIL with one or more missing neutral wording assertions, before the Markdown files are updated.

---

### Task 2: Neutralize the Skill Guidance

**Files:**
- Modify: `.agents/skills/using-herdr-agents/SKILL.md`

**Interfaces:**
- Consumes: current Herdr command and role behavior.
- Produces: orchestrator-neutral skill guidance without changing role/backend defaults.

- [ ] **Step 1: Replace the description frontmatter**

Change:

```markdown
description: Use when Codex is delegating repository exploration, implementation, review, or advisor work through Herdr-managed external agents
```

to:

```markdown
description: Use when a parent orchestrator is delegating repository exploration, implementation, review, or advisor work through Herdr-managed external agents
```

- [ ] **Step 2: Replace the Overview parent boundary**

Change:

```markdown
Codex stays Planner/Judge. Herdr agents are specialist workers used only when delegation beats doing the work inline.
```

to:

```markdown
The parent orchestrator stays Planner/Judge. Herdr agents are specialist workers used only when delegation beats doing the work inline.
```

- [ ] **Step 3: Replace the small-task delegation warning**

Change:

```markdown
Do not delegate when Codex can answer faster by reading a small file, making a trivial local edit, or running a simple check.
```

to:

```markdown
Do not delegate when the parent agent can answer faster by reading a small file, making a trivial local edit, or running a simple check.
```

- [ ] **Step 4: Leave the backend prerequisite line intact**

Do not change this line:

```markdown
Prerequisites: `herdr`, `mise`, and the selected backend CLI must be available on `PATH`. OpenCode and Cline are launched through `mise exec --`; Agy and Codex are launched directly.
```

Reason: this describes sub-agent backend launch behavior. It is not saying the parent orchestrator must be Codex.

---

### Task 3: Neutralize Worker Prompt Boundaries

**Files:**
- Modify: `.agents/skills/using-herdr-agents/prompts/shared.md`
- Modify: `.agents/skills/using-herdr-agents/prompts/scout.md`
- Modify: `.agents/skills/using-herdr-agents/prompts/coder.md`
- Modify: `.agents/skills/using-herdr-agents/prompts/advisor.md`

**Interfaces:**
- Consumes: current role prompt structure and output formats.
- Produces: worker prompts that can be used by any parent orchestrator while keeping the sub-agent roles scoped.

- [ ] **Step 1: Update `shared.md` parent language**

In `.agents/skills/using-herdr-agents/prompts/shared.md`, replace the opening two paragraphs:

```markdown
You are a specialist worker launched by Codex Planner/Judge through Herdr.

The parent Codex session owns planning, final judgment, and user-facing decisions.
```

with:

```markdown
You are a specialist worker launched by a parent orchestrator through Herdr.

The parent orchestrator owns planning, final judgment, and user-facing decisions.
```

Then replace:

```markdown
- Codex Planner/Judge decides what to do with every report.
```

with:

```markdown
- The parent orchestrator decides what to do with every report.
```

- [ ] **Step 2: Update `scout.md` mission and output labels**

In `.agents/skills/using-herdr-agents/prompts/scout.md`, replace:

```markdown
Find the smallest amount of repository context Codex Planner/Judge needs to write a safe brief.
```

with:

```markdown
Find the smallest amount of repository context the parent orchestrator needs to write a safe brief.
```

Then replace:

```markdown
- path Codex should read directly before briefing Coder
```

with:

```markdown
- path the parent orchestrator should read directly before briefing Coder
```

- [ ] **Step 3: Update `coder.md` next-action label**

In `.agents/skills/using-herdr-agents/prompts/coder.md`, replace:

```markdown
- recommended next Codex action
```

with:

```markdown
- recommended next parent-orchestrator action
```

- [ ] **Step 4: Update `advisor.md` parent language only**

In `.agents/skills/using-herdr-agents/prompts/advisor.md`, keep this line unchanged:

```markdown
Model/harness: Codex `gpt-5.5` with `model_reasoning_effort = high` or `xhigh`.
```

Reason: it documents the Advisor worker backend. It is not the parent orchestrator.

Replace:

```markdown
- Codex Planner/Judge needs a high-reasoning second pass before briefing Coder again
```

with:

```markdown
- The parent orchestrator needs a high-reasoning second pass before briefing Coder again
```

Replace:

```markdown
- exact brief Codex should pass to Coder
```

with:

```markdown
- exact brief the parent orchestrator should pass to Coder
```

---

### Task 4: Verify No Runtime Mapping Drift

**Files:**
- Test: `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`
- Read-only check: `.agents/skills/using-herdr-agents/scripts/herdr-agent-lib`

**Interfaces:**
- Consumes: current dry-run output.
- Produces: evidence that the change only generalized parent wording and did not alter sub-agent launch choices.

- [ ] **Step 1: Run shell syntax validation**

Run:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-lib \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-session \
  .agents/skills/using-herdr-agents/scripts/install \
  .agents/skills/using-herdr-agents/tests/herdr-agent.sh \
  tests/herdr-agent.sh
```

Expected: exits 0 with no output.

- [ ] **Step 2: Run the canonical package regression test**

Run:

```sh
sh tests/herdr-agent.sh
```

Expected:

```text
PASS: using-herdr-agents
```

- [ ] **Step 3: Confirm one-shot Scout default still uses OpenCode**

Run:

```sh
HERDR_AGENT_DRY_RUN=1 herdr-agent scout "find files"
```

Expected output includes:

```text
ROLE=scout
BACKEND=opencode
MODEL=opencode-go/deepseek-v4-flash
OPENCODE_AGENT=scout_v2
```

- [ ] **Step 4: Confirm Advisor default still uses Codex as worker backend**

Run:

```sh
HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_ADVISOR_THINKING=xhigh herdr-agent advisor "decide"
```

Expected output includes:

```text
ROLE=advisor
BACKEND=codex
MODEL=gpt-5.5
THINKING=xhigh
```

- [ ] **Step 5: Confirm session naming still includes backend/model**

Run:

```sh
HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_REUSE=never HERDR_AGENT_CONTEXT_KEY=neutral-parent herdr-agent-session scout "find files"
```

Expected output includes:

```text
ROLE=scout
BACKEND=opencode
RUNNER_MODE=interactive
REUSE=never
CONTEXT_KEY=neutral-parent
```

- [ ] **Step 6: Inspect the final diff**

Run:

```sh
git diff -- .agents/skills/using-herdr-agents/SKILL.md \
  .agents/skills/using-herdr-agents/prompts/shared.md \
  .agents/skills/using-herdr-agents/prompts/scout.md \
  .agents/skills/using-herdr-agents/prompts/coder.md \
  .agents/skills/using-herdr-agents/prompts/advisor.md \
  .agents/skills/using-herdr-agents/tests/herdr-agent.sh
```

Expected: only parent-orchestrator wording and test expectation updates. No role/model/backend mapping changes.

---

## Self-Review

- Spec coverage: The plan removes Codex as the assumed parent orchestrator in `SKILL.md` and worker prompts, while preserving the current sub-agent role/backend choices.
- Placeholder scan: No TBD/TODO/later placeholders are present.
- Type consistency: No code interfaces or shell functions are renamed; all commands and environment variables keep existing names.
