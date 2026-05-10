# OpenCode V2 Dispatcher Island Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an isolated OpenCode v2 agent group with a DeepSeek v4 Pro dispatcher while preserving the current orchestrator-based v1 setup as a one-line fallback.

**Architecture:** Keep every existing v1 agent, prompt, and command unchanged. Add copied-and-adjusted v2 agents (`dispatcher_v2`, `planner_v2`, `implementer_v2`, `explorer_v2`, `reviewer_v2`, `arbiter_v2`) with matching `_v2.md` prompts. Switch only `default_agent` to `dispatcher_v2`; rollback is changing `default_agent` back to `orchestrator`.

**Tech Stack:** OpenCode JSONC config, OpenCode custom prompts, Markdown command files, repository-level `AGENTS.md`, `mise exec -- opencode` verification.

---

## Constraints

- Do not edit existing v1 prompt files:
  - `.config/opencode/prompts/orchestrator.md`
  - `.config/opencode/prompts/implementer.md`
  - `.config/opencode/prompts/explorer.md`
  - `.config/opencode/prompts/reviewer.md`
  - `.config/opencode/prompts/arbiter.md`
- Do not edit existing v1 command files:
  - `.config/opencode/commands/feature.md`
  - `.config/opencode/commands/plan.md`
  - `.config/opencode/commands/adr.md`
  - `.config/opencode/commands/quick-fix.md`
  - `.config/opencode/commands/explore.md`
  - `.config/opencode/commands/review-*.md`
- Do not remove or rename existing v1 agent blocks in `.config/opencode/opencode.json`.
- Do not commit changes unless the user explicitly asks.
- Preserve unrelated existing changes:
  - `.codex/config.toml` is already modified.
  - `.claude/worktrees/pensive-hermann-300fff/` is already untracked.
  - `docs/superpowers/notes/` is already untracked.
- Use `opencode-go/deepseek-v4-pro` for `dispatcher_v2`.
- Use `openai/gpt-5.5` with `reasoningEffort: medium` for `planner_v2`.

## File Structure

- Create: `.config/opencode/prompts/dispatcher_v2.md`
  - New routing-only front door for v2.
  - Routes to v2 subagents only.
- Create: `.config/opencode/prompts/planner_v2.md`
  - GPT-5.5 planning and adjudication prompt.
  - Based on current `orchestrator.md`, but references v2 agents and `Planner V2 Adjudication`.
- Create: `.config/opencode/prompts/implementer_v2.md`
  - Based on current `implementer.md`.
  - Reports failures to `planner_v2` / `dispatcher_v2` naming.
- Create: `.config/opencode/prompts/explorer_v2.md`
  - Based on current `explorer.md`.
  - References `planner_v2` for persistence.
- Create: `.config/opencode/prompts/reviewer_v2.md`
  - Based on current `reviewer.md`.
  - Structured findings are for `planner_v2` adjudication.
- Create: `.config/opencode/prompts/arbiter_v2.md`
  - Based on current `arbiter.md`.
  - Invoked by `planner_v2` or `reviewer_v2`.
- Modify: `.config/opencode/opencode.json`
  - Change `default_agent` from `orchestrator` to `dispatcher_v2`.
  - Add v2 agent blocks.
  - Preserve all existing v1 agent blocks.
- Create v2 command files:
  - `.config/opencode/commands/feature-v2.md`
  - `.config/opencode/commands/plan-v2.md`
  - `.config/opencode/commands/adr-v2.md`
  - `.config/opencode/commands/quick-fix-v2.md`
  - `.config/opencode/commands/explore-v2.md`
  - `.config/opencode/commands/review-plan-v2.md`
  - `.config/opencode/commands/review-impl-v2.md`
  - `.config/opencode/commands/review-adr-v2.md`
  - `.config/opencode/commands/review-docs-v2.md`
- Modify: `.agents/AGENTS.md`
  - Document v2 as the normal trial entrypoint.
  - Document v1 `orchestrator` as fallback.

## Task 1: Preflight Verification

**Files:**
- Read: `.config/opencode/opencode.json`
- Read: `.config/opencode/prompts/*.md`
- Read: `.config/opencode/commands/*.md`
- Read: `.agents/AGENTS.md`

- [ ] **Step 1: Capture git state**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
git status --short
```

Expected output includes the already-known unrelated entries:

```text
 M .codex/config.toml
?? .claude/worktrees/pensive-hermann-300fff/
?? docs/superpowers/notes/
?? docs/superpowers/plans/2026-05-10-opencode-dispatcher-planner-fallback.md
```

If additional unrelated changes appear, record them in the implementation summary and do not revert them.

- [ ] **Step 2: Confirm required models exist**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
mise exec -- opencode models opencode-go | rg '^opencode-go/deepseek-v4-pro$'
mise exec -- opencode models openai | rg '^openai/gpt-5\.5$'
mise exec -- opencode models opencode-go | rg '^opencode-go/kimi-k2\.6$'
```

Expected output:

```text
opencode-go/deepseek-v4-pro
openai/gpt-5.5
opencode-go/kimi-k2.6
```

- [ ] **Step 3: Confirm v1 is currently intact**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
rg -n '"default_agent": "orchestrator"|"orchestrator":|"implementer":|"explorer":|"reviewer":|"arbiter":' .config/opencode/opencode.json
```

Expected output includes all existing v1 agents and `default_agent` set to `orchestrator`.

## Task 2: Create V2 Prompt Files

**Files:**
- Create: `.config/opencode/prompts/dispatcher_v2.md`
- Create: `.config/opencode/prompts/planner_v2.md`
- Create: `.config/opencode/prompts/implementer_v2.md`
- Create: `.config/opencode/prompts/explorer_v2.md`
- Create: `.config/opencode/prompts/reviewer_v2.md`
- Create: `.config/opencode/prompts/arbiter_v2.md`
- Preserve: `.config/opencode/prompts/orchestrator.md`
- Preserve: `.config/opencode/prompts/implementer.md`
- Preserve: `.config/opencode/prompts/explorer.md`
- Preserve: `.config/opencode/prompts/reviewer.md`
- Preserve: `.config/opencode/prompts/arbiter.md`

- [ ] **Step 1: Create `.config/opencode/prompts/dispatcher_v2.md`**

Create the file with this exact content:

```markdown
# Role
You are the v2 routing dispatcher.
You receive user requests and delegate them to the right v2 subagent.
You make routing decisions only: no implementation, no planning, no docs writing, no review adjudication.

You may not edit any file.

# Routing Decision
Apply the first matching rule:

1. Trivial typo, single-line fix, README/docs micro-edit with no design judgment -> @implementer_v2
2. User explicitly wants only repository exploration or asks where code lives -> @explorer_v2
3. Planning, ADRs, README/docs creation, multi-file changes, ambiguous scope, reviewer finding adjudication, repeated failure handling, or anything touching API, schema, security, IAM, data model, persisted state, or public behavior -> @planner_v2
4. If unsure -> @planner_v2

Defaulting to @planner_v2 is safer than misrouting to @implementer_v2.

# Failure Loop Handling
When a subagent reports BLOCKED with a `failure_signature`, record it in working memory.
If the same `failure_signature` appears twice in a row for the same task, stop dispatching and send the failure history to @planner_v2.

# Delegation Brief Format
When delegating, pass only:
1. Goal
2. Background / context
3. Constraints
4. Relevant file paths, plan paths, or prior agent reports

Keep the brief under 10 lines.
Do not include large code excerpts or full file contents.

# Do Not
- Do not write plans, ADRs, README, or docs.
- Do not implement code.
- Do not adjudicate reviewer findings.
- Do not call @reviewer_v2 directly.
- Do not call @arbiter_v2 directly.
- Do not narrate hidden reasoning.

# Output Style
Return one routing decision and one concise delegation brief.
```

- [ ] **Step 2: Create v2 copies from v1 prompt files**

Create these files as copies of the corresponding v1 files:

```bash
cp .config/opencode/prompts/orchestrator.md .config/opencode/prompts/planner_v2.md
cp .config/opencode/prompts/implementer.md .config/opencode/prompts/implementer_v2.md
cp .config/opencode/prompts/explorer.md .config/opencode/prompts/explorer_v2.md
cp .config/opencode/prompts/reviewer.md .config/opencode/prompts/reviewer_v2.md
cp .config/opencode/prompts/arbiter.md .config/opencode/prompts/arbiter_v2.md
```

Then edit only the new `_v2.md` files with the exact replacements in the next steps.

- [ ] **Step 3: Edit `.config/opencode/prompts/planner_v2.md`**

Apply these exact replacements to the copied file:

```text
You are the orchestration agent.
=> You are the v2 planning agent.

Your job is to clarify goals, choose the right workflow, delegate work to specialized subagents, write plans/ADRs/READMEs/docs when needed, and keep high-cost model usage focused on judgment.
=> Your job is to handle GPT-5.5 judgment work delegated by @dispatcher_v2: plans, ADRs, README/docs writing, review adjudication, design tradeoffs, and repeated failure handling.

delegate repository exploration to @explorer
=> delegate repository exploration to @explorer_v2

delegate implementation to @implementer
=> delegate implementation to @implementer_v2

request @reviewer for meaningful, risky, or durable artifacts
=> request @reviewer_v2 for meaningful, risky, or durable artifacts

ask before invoking @arbiter
=> ask before invoking @arbiter_v2

Trivial typo, single-line fix, or small README tweak: delegate directly to @implementer.
=> Trivial typo, single-line fix, or small README tweak: this should normally be routed by @dispatcher_v2 to @implementer_v2.

Non-trivial feature: use @explorer if scope is unclear, then write the plan yourself, then delegate to @implementer.
=> Non-trivial feature: use @explorer_v2 if scope is unclear, then write the plan yourself, then delegate to @implementer_v2.

ADR-worthy decision: write the ADR yourself, then request @reviewer.
=> ADR-worthy decision: write the ADR yourself, then request @reviewer_v2.

README or documentation update: write it yourself, then request @reviewer when externally visible.
=> README or documentation update: write it yourself, then request @reviewer_v2 when externally visible.

Risky implementation: request @reviewer after implementation.
=> Risky implementation: request @reviewer_v2 after implementation.

Repeated failure or unclear design direction: ask before invoking @arbiter.
=> Repeated failure or unclear design direction: ask before invoking @arbiter_v2.

Orchestrator copies @reviewer's structured findings
=> Planner V2 copies @reviewer_v2's structured findings

### Orchestrator Adjudication
=> ### Planner V2 Adjudication

Orchestrator appends adjudication tables
=> Planner V2 appends adjudication tables

Any agent adds questions for orchestrator or arbiter
=> Any agent adds questions for planner_v2 or arbiter_v2

When @implementer reports BLOCKED
=> When @implementer_v2 reports BLOCKED

propose @arbiter to the user before retrying
=> propose @arbiter_v2 to the user before retrying

When @reviewer returns findings
=> When @reviewer_v2 returns findings

requires @arbiter (ask user before invoking)
=> requires @arbiter_v2 (ask user before invoking)

Ask @implementer to fix
=> Ask @implementer_v2 to fix

Persistence (orchestrator is the sole writer to the plan):
=> Persistence (planner_v2 is the sole writer to the plan in v2 workflows):

Copy @reviewer's structured findings
=> Copy @reviewer_v2's structured findings

No Orchestrator Adjudication entry.
=> No Planner V2 Adjudication entry.

then re-dispatch @reviewer
=> then re-dispatch @reviewer_v2

ask user before invoking @arbiter
=> ask user before invoking @arbiter_v2
```

After replacements, add this paragraph after the first two role lines:

```markdown
You are part of the v2 agent island. Use only v2 subagents unless the user explicitly asks to fall back to the legacy orchestrator path.
```

- [ ] **Step 4: Edit `.config/opencode/prompts/implementer_v2.md`**

Apply these exact replacements:

```text
You are the implementation agent.
=> You are the v2 implementation agent.

orchestrator uses this to detect loops.
=> dispatcher_v2 and planner_v2 use this to detect loops.
```

Add this paragraph after the role lines:

```markdown
You are part of the v2 agent island. Do not delegate to or reference legacy v1 agents.
```

- [ ] **Step 5: Edit `.config/opencode/prompts/explorer_v2.md`**

Apply these exact replacements:

```text
You are a read-only deep repository exploration agent.
=> You are the v2 read-only deep repository exploration agent.

The orchestrator may save the Exploration Log
=> planner_v2 may save the Exploration Log

What @implementer should avoid
=> What @implementer_v2 should avoid
```

Add this paragraph after the role lines:

```markdown
You are part of the v2 agent island. Return context for @planner_v2 and @implementer_v2.
```

- [ ] **Step 6: Edit `.config/opencode/prompts/reviewer_v2.md`**

Apply these exact replacements:

```text
You are a read-only critical reviewer.
=> You are the v2 read-only critical reviewer.

You may consult @arbiter
=> You may consult @arbiter_v2

adjudication possible for the orchestrator.
=> adjudication possible for @planner_v2.

orchestrator may safely REJECT or DEFER.
=> planner_v2 may safely REJECT or DEFER.

Whether @implementer has enough context
=> Whether @implementer_v2 has enough context

when to consult @arbiter
=> when to consult @arbiter_v2

Return ESCALATE — and propose @arbiter
=> Return ESCALATE — and propose @arbiter_v2

Whether @arbiter should be consulted
=> Whether @arbiter_v2 should be consulted

The invoking workflow (@orchestrator or the user) is responsible for any plan persistence.
=> The invoking workflow (@planner_v2 or the user) is responsible for any plan persistence.
```

Add this paragraph after the role lines:

```markdown
You are part of the v2 agent island. Do not write plan files; @planner_v2 owns v2 review persistence and adjudication.
```

- [ ] **Step 7: Edit `.config/opencode/prompts/arbiter_v2.md`**

Apply these exact replacements:

```text
You are the last-resort consultation agent.
=> You are the v2 last-resort consultation agent.

You may be invoked by @orchestrator (typical) or by @reviewer (when reviewer returns ESCALATE).
=> You may be invoked by @planner_v2 or by @reviewer_v2 when reviewer_v2 returns ESCALATE.

explorer summary report
=> explorer_v2 summary report

implementer report
=> implementer_v2 report

reviewer report
=> reviewer_v2 report

the implementer failed twice
=> implementer_v2 failed twice

the reviewer returned ESCALATE
=> reviewer_v2 returned ESCALATE

the reviewer cannot decide
=> reviewer_v2 cannot decide

whether @reviewer is required
=> whether @reviewer_v2 is required

orchestrator should write them
=> planner_v2 should write them
```

Add this paragraph after the role lines:

```markdown
You are part of the v2 agent island. Return a compact decision to @planner_v2.
```

- [ ] **Step 8: Verify v1 prompts are unchanged**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
git diff -- .config/opencode/prompts/orchestrator.md .config/opencode/prompts/implementer.md .config/opencode/prompts/explorer.md .config/opencode/prompts/reviewer.md .config/opencode/prompts/arbiter.md
```

Expected: no output.

- [ ] **Step 9: Verify v2 prompts do not reference legacy agent names for active routing**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
rg -n '@(orchestrator|implementer|explorer|reviewer|arbiter)\\b|Orchestrator Adjudication|orchestrator is the sole writer' .config/opencode/prompts/*_v2.md || true
```

Expected: no output, except acceptable historical text if it explicitly says "legacy orchestrator path" in `planner_v2.md`.

## Task 3: Add V2 Agent Blocks To OpenCode Config

**Files:**
- Modify: `.config/opencode/opencode.json`

- [ ] **Step 1: Change only the default agent**

In `.config/opencode/opencode.json`, change:

```json
"default_agent": "orchestrator",
```

to:

```json
"default_agent": "dispatcher_v2",
```

- [ ] **Step 2: Add `dispatcher_v2` to the top-level `agent` object**

Add this block before the existing `orchestrator` block:

```json
"dispatcher_v2": {
  "description": "V2 routing-only front door. Delegates user requests to v2 implementer, explorer, or planner. Does not implement, plan, write docs, review, or adjudicate.",
  "mode": "primary",
  "model": "opencode-go/deepseek-v4-pro",
  "textVerbosity": "low",
  "temperature": 0.1,
  "prompt": "{file:~/.config/opencode/prompts/dispatcher_v2.md}",
  "permission": {
    "edit": "deny",
    "read": "allow",
    "bash": {
      "*": "allow",
      "rm -rf *": "deny",
      "sudo *": "ask"
    },
    "external_directory": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "question": "allow",
    "codesearch": "allow",
    "skill": "allow",
    "todowrite": "allow",
    "grep": "allow",
    "lsp": "allow",
    "task": {
      "*": "deny",
      "implementer_v2": "allow",
      "explorer_v2": "allow",
      "planner_v2": "allow"
    },
    "glob": "allow",
    "list": "allow"
  }
},
```

- [ ] **Step 3: Add `planner_v2` after the existing `orchestrator` block**

Add this block:

```json
"planner_v2": {
  "description": "V2 GPT-5.5 planning subagent. Writes plans/ADRs/README/docs, adjudicates reviewer_v2 findings, and resolves design judgment. Does not edit source code.",
  "mode": "subagent",
  "model": "openai/gpt-5.5",
  "reasoningEffort": "medium",
  "textVerbosity": "low",
  "temperature": 0.1,
  "prompt": "{file:~/.config/opencode/prompts/planner_v2.md}",
  "permission": {
    "edit": {
      "*": "deny",
      "docs/**": "allow",
      "README.md": "allow",
      "ADRs/**": "allow",
      "adr/**": "allow"
    },
    "read": "allow",
    "bash": {
      "*": "allow",
      "rm -rf *": "deny",
      "sudo *": "ask"
    },
    "external_directory": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "question": "allow",
    "codesearch": "allow",
    "skill": "allow",
    "todowrite": "allow",
    "grep": "allow",
    "lsp": "allow",
    "task": {
      "*": "deny",
      "implementer_v2": "allow",
      "explorer_v2": "allow",
      "reviewer_v2": "allow",
      "arbiter_v2": "ask"
    },
    "glob": "allow",
    "list": "allow"
  }
},
```

- [ ] **Step 4: Add `implementer_v2` after the existing `implementer` block**

Add this block:

```json
"implementer_v2": {
  "description": "V2 implementation subagent. Makes scoped code changes, runs checks, fixes failures, and reports compact results.",
  "mode": "subagent",
  "model": "opencode-go/kimi-k2.6",
  "temperature": 0.1,
  "prompt": "{file:~/.config/opencode/prompts/implementer_v2.md}",
  "permission": {
    "edit": "allow",
    "read": "allow",
    "bash": {
      "*": "allow",
      "rm -rf *": "deny",
      "sudo *": "ask"
    },
    "external_directory": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "question": "allow",
    "codesearch": "allow",
    "skill": "allow",
    "todowrite": "allow",
    "grep": "allow",
    "lsp": "allow",
    "task": "deny",
    "glob": "allow",
    "list": "allow"
  }
},
```

- [ ] **Step 5: Add `explorer_v2` after the existing `explorer` block**

Add this block:

```json
"explorer_v2": {
  "description": "V2 read-only deep repository exploration subagent. Finds relevant files, dependencies, data/control flow, and likely impact radius. Returns compact reports.",
  "mode": "subagent",
  "model": "opencode-go/deepseek-v4-pro",
  "temperature": 0.1,
  "prompt": "{file:~/.config/opencode/prompts/explorer_v2.md}",
  "permission": {
    "edit": "deny",
    "read": "allow",
    "bash": {
      "*": "allow",
      "rm -rf *": "deny",
      "sudo *": "ask"
    },
    "external_directory": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "question": "allow",
    "codesearch": "allow",
    "skill": "allow",
    "todowrite": "allow",
    "grep": "allow",
    "lsp": "allow",
    "task": "deny",
    "glob": "allow",
    "list": "allow"
  }
},
```

- [ ] **Step 6: Add `reviewer_v2` after the existing `reviewer` block**

Add this block:

```json
"reviewer_v2": {
  "description": "V2 read-only diff review subagent. Checks correctness, spec compliance, security, tests, maintainability, and over-engineering.",
  "mode": "subagent",
  "model": "opencode-go/deepseek-v4-pro",
  "reasoningEffort": "max",
  "temperature": 0.1,
  "prompt": "{file:~/.config/opencode/prompts/reviewer_v2.md}",
  "permission": {
    "edit": "deny",
    "read": "allow",
    "bash": {
      "*": "allow",
      "rm -rf *": "deny",
      "sudo *": "ask"
    },
    "external_directory": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "question": "allow",
    "codesearch": "allow",
    "skill": "allow",
    "todowrite": "allow",
    "grep": "allow",
    "lsp": "allow",
    "task": {
      "*": "deny",
      "arbiter_v2": "ask"
    },
    "glob": "allow",
    "list": "allow"
  }
},
```

- [ ] **Step 7: Add `arbiter_v2` after the existing `arbiter` block**

Add this block:

```json
"arbiter_v2": {
  "description": "V2 hidden last-resort consultation subagent. Diagnoses blocked tasks, redesigns approach, and returns a compact decision. It never edits files.",
  "mode": "subagent",
  "model": "openai/gpt-5.5",
  "reasoningEffort": "xhigh",
  "textVerbosity": "low",
  "temperature": 0.1,
  "prompt": "{file:~/.config/opencode/prompts/arbiter_v2.md}",
  "permission": {
    "edit": "deny",
    "read": "allow",
    "bash": {
      "*": "allow",
      "rm -rf *": "deny",
      "sudo *": "ask"
    },
    "external_directory": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "question": "allow",
    "codesearch": "allow",
    "skill": "allow",
    "todowrite": "allow",
    "grep": "allow",
    "lsp": "allow",
    "task": "deny",
    "glob": "allow",
    "list": "allow"
  }
}
```

- [ ] **Step 8: Verify v1 and v2 agents are both present**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
mise exec -- opencode agent list | rg '^(dispatcher_v2|planner_v2|implementer_v2|explorer_v2|reviewer_v2|arbiter_v2|orchestrator|implementer|explorer|reviewer|arbiter) \\('
```

Expected output includes all v1 and v2 agents. The order may differ.

## Task 4: Add V2 Commands Without Touching V1 Commands

**Files:**
- Create: `.config/opencode/commands/feature-v2.md`
- Create: `.config/opencode/commands/plan-v2.md`
- Create: `.config/opencode/commands/adr-v2.md`
- Create: `.config/opencode/commands/quick-fix-v2.md`
- Create: `.config/opencode/commands/explore-v2.md`
- Create: `.config/opencode/commands/review-plan-v2.md`
- Create: `.config/opencode/commands/review-impl-v2.md`
- Create: `.config/opencode/commands/review-adr-v2.md`
- Create: `.config/opencode/commands/review-docs-v2.md`
- Preserve: all existing `.config/opencode/commands/*.md` files without `-v2` suffix.

- [ ] **Step 1: Create `.config/opencode/commands/feature-v2.md`**

```markdown
---
description: Plan and implement a non-trivial feature through the v2 planner
agent: planner_v2
---

Plan and implement the following feature with compact v2 delegation.

Feature:
$ARGUMENTS

Rules:
- Clarify requirements only if necessary.
- Use @explorer_v2 before reading many files.
- Delegate implementation to @implementer_v2.
- Use @reviewer_v2 for meaningful behavior changes.
- Ask before invoking @arbiter_v2.
- Keep reports compact.
```

- [ ] **Step 2: Create `.config/opencode/commands/plan-v2.md`**

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

- [ ] **Step 3: Create `.config/opencode/commands/adr-v2.md`**

```markdown
---
description: Write or update an ADR through the v2 planner
agent: planner_v2
---

Write or update an ADR for the following decision:
$ARGUMENTS

Rules:
- Use existing ADR format if present in the repo.
- Include: status, context, decision, alternatives considered, consequences, reversibility, review conditions.
- Do not edit source code.
- After saving, request /review-adr-v2 for the new file.
```

- [ ] **Step 4: Create `.config/opencode/commands/quick-fix-v2.md`**

```markdown
---
description: Small focused fix through the v2 implementer
agent: implementer_v2
---

Apply a small focused fix.

Task:
$ARGUMENTS

Rules:
- Make the smallest coherent change.
- Do not refactor unrelated code.
- Run the relevant check if obvious.
- Report files changed, commands run, test result, and risks.
```

- [ ] **Step 5: Create `.config/opencode/commands/explore-v2.md`**

```markdown
---
description: Read-only deep repository exploration through v2 explorer
agent: explorer_v2
---

Explore the following question or scope:
$ARGUMENTS

Rules:
- Use progressive deepening (discovery -> structural -> behavioral pass).
- Avoid generated files, lock files, vendored deps.
- Output: Summary Report (under 1500 tokens) + Exploration Log when useful.
- If more context is needed, return a request for a narrower follow-up.
```

- [ ] **Step 6: Create v2 review commands**

Create `.config/opencode/commands/review-plan-v2.md`:

```markdown
---
description: Critically review a Superpowers plan through v2 reviewer
agent: reviewer_v2
---

ARTIFACT_TYPE: plan

Target plan:
$ARGUMENTS

Apply only the plan review framework. Generate critical thinking findings before forming the verdict.

List individual issues under Critical issues / Non-blocking suggestions using the Finding format defined in reviewer_v2.md.
```

Create `.config/opencode/commands/review-impl-v2.md`:

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

Create `.config/opencode/commands/review-adr-v2.md`:

```markdown
---
description: Critically review an ADR through v2 reviewer
agent: reviewer_v2
---

ARTIFACT_TYPE: adr

Target ADR:
$ARGUMENTS

Apply only the ADR review framework.

List individual issues under Critical issues / Non-blocking suggestions using the Finding format defined in reviewer_v2.md.
```

Create `.config/opencode/commands/review-docs-v2.md`:

```markdown
---
description: Critically review README or documentation changes through v2 reviewer
agent: reviewer_v2
---

ARTIFACT_TYPE: docs

Target:
$ARGUMENTS

Apply only the README/docs review framework.

List individual issues under Critical issues / Non-blocking suggestions using the Finding format defined in reviewer_v2.md.
```

- [ ] **Step 7: Verify v1 commands were not modified**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
git diff -- .config/opencode/commands/feature.md .config/opencode/commands/plan.md .config/opencode/commands/adr.md .config/opencode/commands/quick-fix.md .config/opencode/commands/explore.md .config/opencode/commands/review-plan.md .config/opencode/commands/review-impl.md .config/opencode/commands/review-adr.md .config/opencode/commands/review-docs.md
```

Expected: no output.

- [ ] **Step 8: Verify v2 command routes**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
for f in .config/opencode/commands/*-v2.md; do printf '%s ' "$f"; rg '^agent:' "$f"; done
```

Expected routes:

```text
.config/opencode/commands/adr-v2.md agent: planner_v2
.config/opencode/commands/explore-v2.md agent: explorer_v2
.config/opencode/commands/feature-v2.md agent: planner_v2
.config/opencode/commands/plan-v2.md agent: planner_v2
.config/opencode/commands/quick-fix-v2.md agent: implementer_v2
.config/opencode/commands/review-adr-v2.md agent: reviewer_v2
.config/opencode/commands/review-docs-v2.md agent: reviewer_v2
.config/opencode/commands/review-impl-v2.md agent: reviewer_v2
.config/opencode/commands/review-plan-v2.md agent: reviewer_v2
```

## Task 5: Update Shared AGENTS.md Documentation

**Files:**
- Modify: `.agents/AGENTS.md`

- [ ] **Step 1: Update only the OpenCode Balanced Workflow section**

Replace the current `## OpenCode Balanced Workflow` section with:

```markdown
## OpenCode Balanced Workflow

OpenCode の通常入口は試験運用中の `dispatcher_v2` を使う。`dispatcher_v2` はルーティング専用 agent で、判断を伴う依頼は `planner_v2` に委譲する。

既存の v1 agent 群（`orchestrator`, `implementer`, `explorer`, `reviewer`, `arbiter`）と既存 command は fallback として残す。`dispatcher_v2` の性能が悪い場合は `opencode.json` の `default_agent` を `orchestrator` に戻して従来運用へ戻す。

**v2 ルーティング方針（dispatcher_v2 が判断）:**
- typo・1行修正・README 小修正 → `@implementer_v2` 直行
- 探索のみが目的 → `@explorer_v2`
- 中規模以上の機能、plan / ADR / README / docs 作成、設計判断、API・schema・security・IAM・データモデル関連、曖昧なスコープ → `@planner_v2`
- 失敗ループ検出時は `@planner_v2` にエスカレーション
- 迷ったら `@planner_v2`

**v2 コマンド経路:**
- `/quick-fix-v2` → `@implementer_v2` 直行
- `/feature-v2` / `/plan-v2` / `/adr-v2` → `@planner_v2` 直行
- `/explore-v2` → `@explorer_v2` 直行
- `/review-plan-v2` / `/review-impl-v2` / `/review-adr-v2` / `/review-docs-v2` → `@reviewer_v2` 直接呼び出し（inline findings のみ、plan 自動転記なし）

**v1 fallback:**
- `default_agent` を `orchestrator` に戻すと従来運用に戻る
- 既存 `/feature` / `/plan` / `/adr` / `/quick-fix` / `/explore` / `/review-*` は v1 のまま残す

**Reviewer findings の取り扱い:**
- v2 では `@reviewer_v2` は構造化 findings を inline で返すのみ。plan には書き込まない（**単一書き込み主体: planner_v2 のみ**）。
- `@planner_v2` は workflow 内で `@reviewer_v2` を呼んだ場合、受け取った findings を verbatim で plan の `Review Findings > Reviewer Raw Findings` に転記する。
- 続けて `@planner_v2` は raw findings を `ACCEPT / REJECT / DEFER / NEEDS_CONTEXT / ESCALATE` に分類し、採否を `Review Findings > Planner V2 Adjudication` に表形式（| ID | Severity | Decision | Reason | Action |）で記録する。
- v1 fallback では従来通り `@orchestrator` と `Review Findings > Orchestrator Adjudication` を使う。
- raw findings はレビュー入力（監査履歴）であり、そのまま実装指示として扱わない。
- DEFER は plan の Open Questions セクションにも転記して追跡する。
- `@implementer_v2` には ACCEPT 分のみを渡す。
- ESCALATE は `@arbiter_v2` 呼び出し前に必ずユーザーに確認する。
- `/review-*-v2` 直接呼び出しは reviewer_v2 が inline で findings を返すだけ。plan 自動保存は行わない（user が必要なら手で転記する）。

**Plan as source of truth:**
- plan ファイルが存在する場合、plan ファイルを実装・レビューの基準にする。
- chat 履歴だけに依存しない。
- plan には実装ログ・レビュー所見・逸脱記録・未解決事項のセクションを設けて状態を引き継ぐ。

**`@arbiter_v2` の使用条件:**
- `@implementer_v2` が同種の失敗を2回繰り返した
- `@reviewer_v2` が ESCALATE を返した
- 設計判断が割れた
- API 境界・state schema・IAM・データモデル・セキュリティに影響する変更

**`@arbiter_v2` は常用しない。** 同じ問題で2回相談しても解決しない場合は、人間にエスカレートする。
```

- [ ] **Step 2: Verify documentation mentions fallback clearly**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
rg -n 'dispatcher_v2|planner_v2|orchestrator|fallback|Planner V2 Adjudication|Orchestrator Adjudication' .agents/AGENTS.md
```

Expected: output mentions `dispatcher_v2`, `planner_v2`, and fallback to `orchestrator`.

## Task 6: Verify Isolation And Runtime Behavior

**Files:**
- Verify: `.config/opencode/opencode.json`
- Verify: `.config/opencode/prompts/*_v2.md`
- Verify: `.config/opencode/commands/*-v2.md`
- Verify: `.agents/AGENTS.md`

- [ ] **Step 1: Verify existing v1 files have no diff**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
git diff -- .config/opencode/prompts/orchestrator.md .config/opencode/prompts/implementer.md .config/opencode/prompts/explorer.md .config/opencode/prompts/reviewer.md .config/opencode/prompts/arbiter.md .config/opencode/commands/feature.md .config/opencode/commands/plan.md .config/opencode/commands/adr.md .config/opencode/commands/quick-fix.md .config/opencode/commands/explore.md .config/opencode/commands/review-plan.md .config/opencode/commands/review-impl.md .config/opencode/commands/review-adr.md .config/opencode/commands/review-docs.md
```

Expected: no output.

- [ ] **Step 2: Verify default and fallback agents**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
rg -n '"default_agent": "dispatcher_v2"|"dispatcher_v2":|"planner_v2":|"orchestrator":' .config/opencode/opencode.json
```

Expected output includes:

```text
"default_agent": "dispatcher_v2"
"dispatcher_v2": {
"orchestrator": {
"planner_v2": {
```

- [ ] **Step 3: Verify OpenCode registers v1 and v2 agents**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
mise exec -- opencode agent list | rg '^(dispatcher_v2|planner_v2|implementer_v2|explorer_v2|reviewer_v2|arbiter_v2|orchestrator|implementer|explorer|reviewer|arbiter) \\('
```

Expected: all v1 and v2 agents are listed.

- [ ] **Step 4: Run no-edit dispatcher_v2 smoke test**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
mise exec -- opencode run \
  --agent dispatcher_v2 \
  --model opencode-go/deepseek-v4-pro \
  --format json \
  --dir "$PWD" \
  "Route this request only: I want to fix a one-character typo in README.md. Do not edit files. Return the target agent name and one-sentence brief."
```

Expected behavior: assistant routes to `@implementer_v2` and does not edit files.

- [ ] **Step 5: Run no-edit planner_v2 smoke test**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
mise exec -- opencode run \
  --agent planner_v2 \
  --model openai/gpt-5.5 \
  --format json \
  --dir "$PWD" \
  "Reply with exactly: planner_v2 available. Do not edit files."
```

Expected assistant text:

```text
planner_v2 available.
```

- [ ] **Step 6: Verify fallback is one config line**

Do not edit files in this step. Confirm fallback would be changing only:

```json
"default_agent": "orchestrator",
```

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
rg -n '"default_agent": "dispatcher_v2"|"orchestrator":|"prompt": "\\{file:~/.config/opencode/prompts/orchestrator.md\\}"' .config/opencode/opencode.json
```

Expected: `default_agent` is `dispatcher_v2`, and the preserved `orchestrator` block still points at `orchestrator.md`.

- [ ] **Step 7: Review final diff**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
git diff -- .config/opencode/opencode.json .config/opencode/prompts .config/opencode/commands .agents/AGENTS.md
```

Expected:

- Existing v1 prompts and commands have no diff.
- New `_v2.md` prompts are added.
- New `*-v2.md` commands are added.
- `opencode.json` keeps every v1 agent and adds every v2 agent.
- Only `default_agent` changes from `orchestrator` to `dispatcher_v2`.
- `.agents/AGENTS.md` documents v2 trial and v1 fallback.

## Rollback Procedure

If dispatcher_v2 behavior is poor, perform the minimal fallback:

```bash
cd /Users/haru256/Documents/projects/dotfiles
```

Change `.config/opencode/opencode.json`:

```json
"default_agent": "orchestrator",
```

Then verify:

```bash
mise exec -- opencode agent list | rg '^(orchestrator|dispatcher_v2|planner_v2) \\('
rg -n '"default_agent": "orchestrator"|"orchestrator":|"dispatcher_v2":|"planner_v2":' .config/opencode/opencode.json
```

This keeps the v2 agent island available for later tuning while returning the normal entrypoint to the preserved GPT-5.5 orchestrator.

## Self-Review Notes

- Spec coverage: The plan now uses an isolated v2 agent group, keeps all existing v1 agents/prompts/commands unchanged, uses `deepseek-v4-pro` for `dispatcher_v2`, keeps GPT-5.5 medium for `planner_v2`, and provides one-line fallback to `orchestrator`.
- Placeholder scan: No placeholder markers are present. The plan uses exact file paths, agent names, command routes, and verification commands.
- Name consistency: v2 names consistently use `_v2` for agents and prompts, and `-v2` for commands. The existing `orchestrator` remains the fallback default.

## Implementation Log

<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N -> STATUS | commit-or-failure-signature -->

## Review Findings

### Reviewer Raw Findings

<!-- planner_v2 or orchestrator copies structured reviewer findings verbatim here when invoking a reviewer during a workflow. Direct review commands do not write here. Raw findings are review input, not implementation instructions. -->

### Planner V2 Adjudication

<!-- planner_v2 appends adjudication tables for v2 workflow reviews. Only ACCEPT rows are implementation instructions: | ID | Severity | Decision | Reason | Action | -->

### Orchestrator Adjudication

<!-- Preserved fallback orchestrator may use this section when default_agent is restored to orchestrator. -->

## Deviations from Plan

<!-- Implementer documents intentional deviations and reasons. -->

## Open Questions

<!-- Any agent adds questions for planner_v2, orchestrator, arbiter_v2, arbiter, or the user. -->
