# Opencode Agent Terminology Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove version-label wording from opencode descriptions and prompt/command prose while keeping existing agent names, file names, command names, and routing identifiers unchanged.

**Architecture:** Make text-only edits in the active opencode configuration surface. Treat `*_v2` and `*-v2` as stable identifiers when they are agent names, file names, slash-command names, `agent:` frontmatter targets, prompt file references, task permission keys, or `default_agent` values; remove the version label only when it is descriptive prose consumed by agents.

**Tech Stack:** opencode JSON config, opencode agent prompt markdown files, opencode command markdown files, targeted ripgrep verification.

---

## Scope and Decisions

### New user constraint

The user said: `agent名だけはv2をつけていていいよ` — it is fine to keep the suffix in agent names.

Keep these identifiers exactly as they are:

- Agent keys and task targets: `dispatcher_v2`, `planner_v2`, `implementer_v2`, `explorer_v2`, `reviewer_v2`, `oracle_v2`.
- Agent prompt file names: `dispatcher_v2.md`, `planner_v2.md`, `implementer_v2.md`, `explorer_v2.md`, `reviewer_v2.md`, `oracle_v2.md`.
- Command file names and slash-command references: `*-v2.md`, `/feature-v2`, `/review-*-v2`, etc.
- Command frontmatter `agent:` values such as `agent: planner_v2`.
- `.config/opencode/opencode.json` `default_agent` value when it is `dispatcher_v2`.
- Prompt file references such as `{file:~/.config/opencode/prompts/planner_v2.md}`.

Remove version-label wording only from fields and prose the agents consume, including:

- opencode JSON `description` values.
- Agent prompt role statements, workflow wording, and explanatory text.
- Command frontmatter `description` values.
- Command body prose.
- This plan's template comments where they are copied into future plans.

### In scope

- `.config/opencode/opencode.json`
- `.config/opencode/prompts/dispatcher_v2.md`
- `.config/opencode/prompts/planner_v2.md`
- `.config/opencode/prompts/implementer_v2.md`
- `.config/opencode/prompts/explorer_v2.md`
- `.config/opencode/prompts/reviewer_v2.md`
- `.config/opencode/prompts/oracle_v2.md`
- `.config/opencode/commands/adr-v2.md`
- `.config/opencode/commands/explore-v2.md`
- `.config/opencode/commands/feature-v2.md`
- `.config/opencode/commands/plan-v2.md`
- `.config/opencode/commands/quick-fix-v2.md`
- `.config/opencode/commands/review-adr-v2.md`
- `.config/opencode/commands/review-docs-v2.md`
- `.config/opencode/commands/review-impl-v2.md`
- `.config/opencode/commands/review-plan-v2.md`
- `.config/opencode/commands/review-readme-v2.md`

### Out of scope

- Renaming any agent key, prompt file, command file, slash command, task permission key, or `default_agent` value.
- Renaming non-versioned agents or commands such as `orchestrator`, `implementer`, `explorer`, `reviewer`, `oracle`, `feature.md`, `plan.md`, or `review-*.md`.
- Creating `*_legacy` agents or `*-legacy` commands.
- Built-in opencode agent definitions shipped by opencode.
- Source code and tests.

### Verified current configuration facts

- All listed in-scope files exist.
- `.config/opencode/opencode.json` currently has `"default_agent": "dispatcher_v2"`; keep it.
- Active agent keys currently include `dispatcher_v2`, `planner_v2`, `implementer_v2`, `explorer_v2`, `reviewer_v2`, and `oracle_v2`; keep them.
- Active command frontmatter currently targets `planner_v2`, `explorer_v2`, `implementer_v2`, or `reviewer_v2`; keep these values.
- Non-versioned `orchestrator` and the older non-versioned subagents are not part of this cleanup.

## File Structure

### Modify

- `.config/opencode/opencode.json` — remove version-label wording from active agent `description` values only.
- `.config/opencode/prompts/*_v2.md` — remove descriptive version-label wording from prompt bodies while preserving agent-name and path references.
- `.config/opencode/commands/*-v2.md` — remove descriptive version-label wording from command descriptions and command body prose while preserving command names and `agent:` targets.
- `docs/superpowers/plans/2026-05-23-opencode-agent-v2-terminology-removal.md` — keep the narrowed scope and clean reusable template wording.

### Do not rename

No file moves are part of this plan.

## Tasks

### Task 1: Update opencode JSON descriptions only

**Files:**
- Modify: `.config/opencode/opencode.json`

- [ ] **Step 1: Preserve structural identifiers**

Before editing, confirm these values remain unchanged in the final diff:

```text
"default_agent": "dispatcher_v2"
"dispatcher_v2"
"planner_v2"
"implementer_v2"
"explorer_v2"
"reviewer_v2"
"oracle_v2"
{file:~/.config/opencode/prompts/*_v2.md}
task permission keys ending in _v2
```

- [ ] **Step 2: Remove version-label wording from active agent descriptions**

Apply only these description edits:

```text
Delegates user requests to v2 implementer, explorer, or planner.
→ Delegates user requests to implementer_v2, explorer_v2, or planner_v2.

V2 planning subagent.
→ Planning subagent.

V2 implementation subagent.
→ Implementation subagent.

V2 read-only deep repository exploration subagent.
→ Read-only deep repository exploration subagent.

V2 read-only multi-artifact review subagent.
→ Read-only multi-artifact review subagent.

V2 hidden high-context decision-consistency consultation subagent.
→ Hidden high-context decision-consistency consultation subagent.
```

Expected: no `description` value contains the standalone word `v2` or `V2`, but identifier text such as `reviewer_v2` may remain when it names an agent.

- [ ] **Step 3: Validate JSONC syntax**

Run:
```bash
node -e "const fs=require('fs'); const s=fs.readFileSync('.config/opencode/opencode.json','utf8'); JSON.parse(s.replace(/^\s*\/\/.*$/gm,'')); console.log('valid')"
```

Expected: output is `valid` and exit code is `0`.

### Task 2: Update active prompt prose without changing agent references

**Files:**
- Modify: `.config/opencode/prompts/dispatcher_v2.md`
- Modify: `.config/opencode/prompts/planner_v2.md`
- Modify: `.config/opencode/prompts/implementer_v2.md`
- Modify: `.config/opencode/prompts/explorer_v2.md`
- Modify: `.config/opencode/prompts/reviewer_v2.md`
- Modify: `.config/opencode/prompts/oracle_v2.md`

- [ ] **Step 1: Preserve identifier references**

Do not change any agent references such as:

```text
@dispatcher_v2
@planner_v2
@implementer_v2
@explorer_v2
@reviewer_v2
@oracle_v2
planner_v2 returns its own final status
[oracle_v2] [YYYY-MM-DD]
reviewer_v2.md
commands/plan-v2.md
/review-*-v2
/feature-v2
```

- [ ] **Step 2: Remove descriptive version wording**

Apply these prompt-body edits where present:

```text
You are the v2 routing dispatcher → You are the routing dispatcher
Route work to v2 subagents (`@implementer_v2`, `@explorer_v2`, `@planner_v2`)
→ Route work to configured subagents (`@implementer_v2`, `@explorer_v2`, `@planner_v2`)
legacy v1 agents → older agents
meta questions about the v2 agent system → meta questions about the agent system
You are the v2 planning agent → You are the planning agent
You are part of the v2 agent island → You are part of the agent system
Use only v2 subagents → Use only configured subagents
Planner V2 → Planner
v2 workflow reviews → workflow reviews
You are the v2 implementation agent → You are the implementation agent
You are the v2 read-only deep exploration agent → You are the read-only deep exploration agent
You are the v2 read-only critical reviewer → You are the read-only critical reviewer
v2 review persistence → review persistence
```

Keep `You are oracle_v2: ...` because `oracle_v2` is the agent name.

- [ ] **Step 3: Remove stale dispatcher `arbiter` text**

In `.config/opencode/prompts/dispatcher_v2.md`, remove the non-existent `arbiter` from role and older-agent lists. For example:

```text
implementer, planner, explorer, reviewer, or arbiter
→ implementer, planner, explorer, or reviewer
```

Expected: the dispatcher prompt does not mention `arbiter`.

### Task 3: Update command descriptions and command prose only

**Files:**
- Modify: `.config/opencode/commands/adr-v2.md`
- Modify: `.config/opencode/commands/explore-v2.md`
- Modify: `.config/opencode/commands/feature-v2.md`
- Modify: `.config/opencode/commands/plan-v2.md`
- Modify: `.config/opencode/commands/quick-fix-v2.md`
- Modify: `.config/opencode/commands/review-adr-v2.md`
- Modify: `.config/opencode/commands/review-docs-v2.md`
- Modify: `.config/opencode/commands/review-impl-v2.md`
- Modify: `.config/opencode/commands/review-plan-v2.md`
- Modify: `.config/opencode/commands/review-readme-v2.md`

- [ ] **Step 1: Preserve command identifiers and frontmatter targets**

Do not rename command files and do not change frontmatter `agent:` values:

```text
agent: planner_v2
agent: explorer_v2
agent: implementer_v2
agent: reviewer_v2
```

Also keep body references to command names and agent names, such as `/feature-v2`, `/review-adr-v2`, `@planner_v2`, `@explorer_v2`, `@implementer_v2`, `@reviewer_v2`, and `@oracle_v2`.

- [ ] **Step 2: Remove version wording from command descriptions**

Apply these frontmatter `description:` edits:

```text
through the v2 planner → through the planner
through v2 explorer → through explorer
through the v2 implementer → through the implementer
through v2 reviewer → through reviewer
```

- [ ] **Step 3: Remove version wording from command bodies**

Apply these body-prose edits:

```text
Plan and implement the following feature with compact v2 delegation.
→ Plan and implement the following feature with compact delegation.

v2 workflow reviews
→ workflow reviews

Planner V2
→ Planner
```

Do not change `prompts/planner_v2.md`, `/review-*-v2`, or agent-name text like `planner_v2` in template examples.

### Task 4: Verify narrowed cleanup

**Files:**
- Verify: `.config/opencode/opencode.json`
- Verify: `.config/opencode/prompts/*_v2.md`
- Verify: `.config/opencode/commands/*-v2.md`

- [ ] **Step 1: Verify JSON descriptions are clean**

Run:
```bash
rg '"description":.*\b[Vv]2\b' .config/opencode/opencode.json
```

Expected: no output.

- [ ] **Step 2: Verify structural names are still present in JSON**

Run:
```bash
rg '"default_agent": "dispatcher_v2"|"dispatcher_v2"|"planner_v2"|"implementer_v2"|"explorer_v2"|"reviewer_v2"|"oracle_v2"' .config/opencode/opencode.json
```

Expected: output is present for the default agent, active agent keys, prompt references, and task permissions.

- [ ] **Step 3: Verify prompt prose has no standalone version wording**

Run:
```bash
rg -n '\bv2\b|\bV2\b' .config/opencode/prompts/ --glob '*_v2.md' | rg -v '@\w+_v2' | rg -v '\b\w+_v2\b' | rg -v '\.md' | rg -v '/review-.*-v2' | rg -v '/feature-v2' | rg -v 'commands/plan-v2'
```

Expected: no output.

- [ ] **Step 4: Verify command descriptions are clean**

Run:
```bash
rg 'description:.*\b[Vv]2\b' .config/opencode/commands/ --glob '*-v2.md'
```

Expected: no output.

- [ ] **Step 5: Verify command frontmatter targets still point to versioned agent names**

Run:
```bash
rg '^agent: .*_v2$' .config/opencode/commands/ --glob '*-v2.md'
```

Expected: one line for each active `*-v2.md` command file.

- [ ] **Step 6: Verify command body prose has no standalone version wording**

Run:
```bash
rg -n '\bv2\b|\bV2\b' .config/opencode/commands/ --glob '*-v2.md' | rg -v '^.*agent: .*_v2$' | rg -v '@\w+_v2' | rg -v '\b\w+_v2\b' | rg -v '\.md' | rg -v '/review-.*-v2' | rg -v '/feature-v2' | rg -v '/plan-v2' | rg -v 'commands/plan-v2'
```

Expected: no output.

- [ ] **Step 7: Verify stale dispatcher `arbiter` reference is gone**

Run:
```bash
rg 'arbiter' .config/opencode/prompts/dispatcher_v2.md
```

Expected: no output.

- [ ] **Step 8: Inspect final diff**

Run:
```bash
git diff -- .config/opencode/opencode.json .config/opencode/prompts .config/opencode/commands docs/superpowers/plans/2026-05-23-opencode-agent-v2-terminology-removal.md
```

Expected: changes are limited to description/prose cleanup and this plan update. There are no file renames, no agent-key renames, no command filename renames, no `agent:` frontmatter retargeting, and no `default_agent` change.

### Task 5: User handoff

**Files:**
- No file edits.

- [ ] **Step 1: Tell the user to restart opencode**

Report:
```text
opencode loads config at startup. Quit and restart opencode for these agent and command changes to take effect.
```

- [ ] **Step 2: Summarize intentional leftovers**

Report that `*_v2` and `*-v2` intentionally remain where they are identifiers: agent names, prompt file names, command file names, slash-command references, task permission keys, `agent:` frontmatter targets, prompt references, and `default_agent`.

## Acceptance Criteria

- `.config/opencode/opencode.json` keeps `default_agent: dispatcher_v2`, active `*_v2` agent keys, prompt file references, and task permission references.
- `.config/opencode/opencode.json` active `description` values no longer use standalone version-label wording.
- Active prompt file names remain `*_v2.md`.
- Active command file names remain `*-v2.md`.
- Active command frontmatter `agent:` values remain `planner_v2`, `explorer_v2`, `implementer_v2`, or `reviewer_v2`.
- Active prompt and command prose no longer uses standalone descriptive version-label wording.
- Agent-name, command-name, path, and frontmatter-target references containing the suffix remain intact.
- No legacy files or renamed agents are created.
- JSONC syntax validation succeeds.
- User is told to restart opencode.

## Self-Review

- Spec coverage: the plan now matches the user's narrowed constraint: keep the suffix in agent names and filenames, remove it only from descriptions and prose.
- Placeholder scan: no unresolved placeholders are present.
- Scope control: no source code, tests, file renames, legacy preservation, or non-versioned agent/command rewiring are in scope.

## Implementation Log
<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N -> STATUS | commit-or-failure-signature -->
[2026-05-23] attempt #1 -> DONE | no commit (working tree changes)

## Review Findings
<!-- This template is also defined in commands/plan-v2.md. Keep them in sync on every edit. -->

### Reviewer Raw Findings
<!-- Planner copies @reviewer_v2's structured findings verbatim here when invoking @reviewer_v2 during a workflow. Direct /review-*-v2 calls do not write here. Raw findings are review input, not implementation instructions. -->

#### 2026-05-23 plan -> REQUEST_CHANGES
Critical issues:
- F1: Severity BLOCKER, confidence HIGH, category plan / correctness. Evidence: `.config/opencode/opencode.json` lines 74–80. The `orchestrator` agent (a `mode: "primary"` agent with its own prompt file at `.config/opencode/prompts/orchestrator.md`) has `task` permissions referencing `"implementer": "allow"`, `"explorer": "allow"`, `"reviewer": "allow"`, `"oracle": "ask"`. The plan renames the old agents `implementer`/`explorer`/`reviewer`/`oracle` to `*_legacy` and promotes the v2 agents `implementer_v2`/`explorer_v2`/`reviewer_v2`/`oracle_v2` to those bare names. The orchestrator's task permissions are never mentioned in any task, so after the rename they will silently resolve to the promoted v2 agents instead of the preserved legacy agents. The plan never references the `orchestrator` agent at all. Why it matters: This changes the dispatch targets of an active primary agent without acknowledgment, meaning any user or workflow invoking the orchestrator would experience different agent behavior with different prompts, delegation chains, and output formats. Recommended action: Add a new step in Task 3 to explicitly address the orchestrator's task permissions. Either update them to `*_legacy` names to preserve original orchestrator behavior, or add an explicit decision note stating that the orchestrator is intentionally being upgraded to dispatch to promoted v2 agents with a brief justification. Must fix before merge: yes.
- F2: Severity MAJOR, confidence HIGH, category plan / correctness. Evidence: older command files `.config/opencode/commands/explore.md`, `quick-fix.md`, `review-adr.md`, `review-docs.md`, `review-impl.md`, and `review-plan.md` have frontmatter values `agent: explorer`, `agent: implementer`, or `agent: reviewer`. These are older command files that the plan renames to `*-legacy.md`. After the agent rename, the bare names `explorer`, `implementer`, `reviewer` will resolve to promoted v2 agents, not preserved legacy agents. Task 5 only covers promoted v2 command files and does not address legacy command frontmatter. Why it matters: users invoking legacy slash commands would silently get promoted agent behavior. Recommended action: update legacy command frontmatter to `agent: explorer_legacy`, `agent: implementer_legacy`, or `agent: reviewer_legacy`, or document intentional rewiring. Must fix before merge: yes.
Non-blocking suggestions:
- S1: Severity MAJOR, confidence HIGH, category correctness. Evidence: Task 3 Step 5 uses `python -m json.tool .config/opencode/opencode.json >/dev/null`, but `.config/opencode/opencode.json` contains `//` comments and is JSONC-format. Standard `json.tool` will fail even if no edit introduced an error. Recommended action: replace with a JSONC-aware validation command such as a Node command that strips line comments before `JSON.parse`, or provide another JSONC-aware validator. Must fix before merge: no.
- S2: Severity MAJOR, confidence HIGH, category correctness. Evidence: `.config/opencode/opencode.json` line 324 — the old `oracle` agent's `task` permission contains `"explorer_v2": "allow"`. The plan left the choice between `explorer` and `explorer_legacy` to implementer judgment. Recommended action: make the decision explicit; since the preserved legacy oracle is being kept as fallback, update `explorer_v2` to `explorer_legacy` so it remains self-contained. Must fix before merge: no.
- S3: Severity MAJOR, confidence HIGH, category correctness. Evidence: `.config/opencode/opencode.json` line 262 — the old `reviewer` agent's `task` permission references `"oracle": "ask"`. After renaming old `reviewer` to `reviewer_legacy` and old `oracle` to `oracle_legacy`, this would resolve to promoted `oracle` unless handled. Recommended action: explicitly decide and document whether `reviewer_legacy` should reference `oracle` or `oracle_legacy`; apply same logic as S2. Must fix before merge: no.
- S4: Severity MINOR, confidence HIGH, category maintainability. Evidence: `.config/opencode/prompts/dispatcher_v2.md` lines 8 and 27 reference `arbiter`, but there is no `arbiter` agent in `.config/opencode/opencode.json`. Recommended action: add `arbiter` removal to Task 4 Step 2 replacements. Must fix before merge: no.
- S5: Severity MINOR, confidence MEDIUM, category maintainability. Evidence: Task 1 and Task 2 run multiple sequential `mv` commands without a checkpoint. Recommended action: add a note recommending safety commit or stash before renames. Must fix before merge: no.
- S6: Severity NIT, confidence HIGH, category docs. Evidence: the plan file itself contains v2 references in historical/audit sections and template comments. Recommended action: none required; optionally note in handoff that the plan file itself contains historical references. Must fix before merge: no.

### Planner Adjudication
<!-- Planner appends adjudication tables for workflow reviews. Only ACCEPT rows are implementation instructions: | ID | Severity | Decision | Reason | Action | -->

#### 2026-05-23 plan -> REQUEST_CHANGES

| ID | Severity | Decision | Reason | Action |
|----|----------|----------|--------|--------|
| F1 | BLOCKER | SUPERSEDED | User narrowed scope: no agent renames or legacy preservation will occur. | No action under revised scope. |
| F2 | MAJOR | SUPERSEDED | User narrowed scope: no command renames or legacy command retargeting will occur. | No action under revised scope. |
| S1 | MAJOR | ACCEPT | JSONC validation remains relevant for the narrowed plan. | Keep JSONC-tolerant Node validation command. |
| S2 | MAJOR | SUPERSEDED | User narrowed scope: old `oracle` task wiring is not changed. | No action under revised scope. |
| S3 | MAJOR | SUPERSEDED | User narrowed scope: old `reviewer` task wiring is not changed. | No action under revised scope. |
| S4 | MINOR | ACCEPT | Stale non-existent `arbiter` reference is agent-visible prompt noise independent of renaming. | Keep dispatcher prompt cleanup instruction. |
| S5 | MINOR | SUPERSEDED | User narrowed scope: no rename sequence remains. | No action under revised scope. |
| S6 | NIT | ACCEPT | Reusable plan template comments should not reintroduce descriptive version wording. | Updated live template comments in this plan; historical raw findings preserved as audit. |

#### 2026-05-23 plan -> APPROVE
[2026-05-23] plan -> APPROVE | no findings

#### 2026-05-23 plan -> APPROVE
[2026-05-23] plan -> APPROVE | no findings

## Deviations from Plan
<!-- Implementer documents intentional deviations and reasons. -->

## Open Questions
- [resolved] Should preserved older agents and commands remain available as `*_legacy` / `*-legacy`, or should they be removed entirely after the active system is promoted? User narrowed the scope: do not promote, rename, or preserve-as-legacy; keep versioned agent and command identifiers as-is.
