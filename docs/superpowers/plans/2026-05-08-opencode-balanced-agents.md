# OpenCode Balanced Agents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure OpenCode for the balanced workflow: a primary orchestrator, DeepSeek explorer, Kimi implementer, GPT reviewer, and hidden GPT arbiter.

**Architecture:** Keep OpenCode as the single harness. Store role behavior in prompt files, keep model choices in `opencode.json`, and make `orchestrator` the single default entrypoint. Worker agents remain subagents so normal work flows through the orchestrator while still allowing explicit `@agent` delegation.

**Tech Stack:** OpenCode config JSONC, OpenCode custom agents, OpenCode custom commands, Superpowers plugin, mise-managed `opencode` CLI.

---

## File Structure

- Modify: `/Users/haru256/.config/opencode/opencode.json`
  - Set `default_agent` to `orchestrator`.
  - Keep `orchestrator` as `primary` using `openai/gpt-5.5`.
  - Replace `codebase-researcher` with `explorer` using `opencode-go/deepseek-v4-pro`.
  - Keep `implementer` using `opencode-go/kimi-k2.6`.
  - Add `reviewer` using `openai/gpt-5.4`.
  - Add hidden `arbiter` using `openai/gpt-5.5`.
  - Remove obsolete agents that overlap with the B workflow unless explicitly needed: `test-fixer`, `diff-summarizer`, `refactor-worker`, `docs-worker`.
  - Point each agent prompt to a file under `/Users/haru256/.config/opencode/prompts/`.
- Create: `/Users/haru256/.config/opencode/prompts/orchestrator.md`
  - Defines orchestration, routing, token policy, and delegation format.
- Create: `/Users/haru256/.config/opencode/prompts/implementer.md`
  - Defines scoped implementation behavior and compact report format.
- Create: `/Users/haru256/.config/opencode/prompts/explorer.md`
  - Defines read-only deep repository exploration and a 1800-token report budget.
- Create: `/Users/haru256/.config/opencode/prompts/reviewer.md`
  - Defines diff-first read-only review behavior.
- Create: `/Users/haru256/.config/opencode/prompts/arbiter.md`
  - Defines hidden last-resort consultation behavior.
- Create: `/Users/haru256/.config/opencode/commands/quick-fix.md`
  - Routes small focused fixes to `implementer`.
- Create: `/Users/haru256/.config/opencode/commands/feature.md`
  - Routes non-trivial features through `orchestrator`.
- Optional modify after verification: `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md`
  - Add a short note that OpenCode default workflow is `orchestrator -> explorer/implementer/reviewer/arbiter`.

## Task 1: Baseline And Model Availability

**Files:**
- Read: `/Users/haru256/.config/opencode/opencode.json`
- Read: `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md`

- [ ] **Step 1: Capture current git state**

Run:

```bash
git -C /Users/haru256/Documents/projects/dotfiles status --short
```

Expected: Existing unrelated dirty files may be present. Do not revert them.

- [ ] **Step 2: Capture current OpenCode agent config**

Run:

```bash
sed -n '1,260p' /Users/haru256/.config/opencode/opencode.json
```

Expected: The file contains the current `orchestrator`, Kimi subagents, global permissions, MCP config, and Superpowers plugin.

- [ ] **Step 3: Verify required models are available**

Run:

```bash
mise exec -- opencode models openai | rg '^openai/gpt-5\.(4|5)$'
mise exec -- opencode models opencode-go | rg '^opencode-go/(kimi-k2\.6|deepseek-v4-pro)$'
```

Expected:

```text
openai/gpt-5.4
openai/gpt-5.5
opencode-go/deepseek-v4-pro
opencode-go/kimi-k2.6
```

- [ ] **Step 4: Back up the current OpenCode config**

Run:

```bash
cp /Users/haru256/.config/opencode/opencode.json /Users/haru256/.config/opencode/opencode.json.before-balanced-agents
```

Expected: Backup file exists.

Run:

```bash
test -f /Users/haru256/.config/opencode/opencode.json.before-balanced-agents
```

Expected: Exit code 0.

## Task 2: Create Prompt Files

**Files:**
- Create: `/Users/haru256/.config/opencode/prompts/orchestrator.md`
- Create: `/Users/haru256/.config/opencode/prompts/implementer.md`
- Create: `/Users/haru256/.config/opencode/prompts/explorer.md`
- Create: `/Users/haru256/.config/opencode/prompts/reviewer.md`
- Create: `/Users/haru256/.config/opencode/prompts/arbiter.md`

- [ ] **Step 1: Ensure prompt directory exists**

Run:

```bash
mkdir -p /Users/haru256/.config/opencode/prompts
```

Expected: Directory exists.

Run:

```bash
test -d /Users/haru256/.config/opencode/prompts
```

Expected: Exit code 0.

- [ ] **Step 2: Create orchestrator prompt**

Create `/Users/haru256/.config/opencode/prompts/orchestrator.md` with:

```md
# Role

You are the primary orchestration agent.

Your job is to:
- clarify the task only when required
- decide whether the task is trivial or non-trivial
- delegate repository exploration to @explorer when scope is unclear
- delegate implementation to @implementer
- request @reviewer for meaningful or risky diffs
- ask before invoking @arbiter
- keep expensive reasoning focused on planning, review, and escalation

You must not edit files unless explicitly asked.

# Token Policy

Prefer compact summaries, git diff, failing test excerpts, and file paths.
Do not read large files unless necessary.
Do not pass full file contents to subagents unless required.
Ask subagents for compact reports instead of long transcripts.

# Delegation Format

When delegating, include:

1. Goal
2. Relevant files or search targets
3. Constraints
4. Acceptance criteria
5. Commands to run
6. Expected report format

# Routing

- Trivial typo or small documentation fix: delegate directly to @implementer.
- Feature or behavior change: use @explorer if scope is unclear, then delegate to @implementer.
- Design-sensitive change: plan first, then delegate.
- Risky change: run @reviewer after implementation.
- If @implementer fails twice with the same error class, stop and ask before invoking @arbiter.

# Safety

Never commit, push, tag, release, merge, rebase, reset, or revert user work without an explicit request.
Preserve unrelated dirty work.
After each implementation result, inspect git status and git diff before deciding the next action.
```

- [ ] **Step 3: Create implementer prompt**

Create `/Users/haru256/.config/opencode/prompts/implementer.md` with:

```md
# Role

You are the implementation agent.

You make scoped code changes based on a concrete task brief.
Prefer the smallest coherent change that satisfies the acceptance criteria.

# Rules

- Do not change unrelated files.
- Do not perform broad refactoring unless explicitly requested.
- Preserve existing style, naming, and architecture.
- Run the requested checks when possible.
- If tests fail, fix the failure when the cause is clear and in scope.
- If the same class of failure happens twice, stop and report BLOCKED.
- Do not delegate to other agents.
- Never commit, push, tag, release, merge, rebase, reset, or revert user work.

# Report Format

Always end with:

1. Status: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
2. Files changed
3. Summary of changes
4. Commands run
5. Test result
6. Remaining risks
7. Suggested next action
```

- [ ] **Step 4: Create explorer prompt**

Create `/Users/haru256/.config/opencode/prompts/explorer.md` with:

```md
# Role

You are a read-only deep repository exploration agent.

Your job is to understand relevant files, cross-file relationships, architecture boundaries, data flow, and likely impact radius.

You must not edit files.

# Rules

- Prefer targeted reads.
- Use rg, git grep, git ls-files, and focused file reads.
- Avoid generated files, lock files, cache directories, and vendored dependencies.
- Do not propose broad refactors unless the current architecture requires it.
- Keep the report compact.
- Do not implement.
- Do not delegate to other agents.

# Report Format

Return under 1800 tokens:

1. Relevant files
2. Relevant functions/classes/resources
3. Cross-file relationships
4. Data/control flow
5. Existing architectural pattern
6. Likely change points
7. Risks and hidden coupling
8. Suggested implementation slice
9. What @implementer should avoid
```

- [ ] **Step 5: Create reviewer prompt**

Create `/Users/haru256/.config/opencode/prompts/reviewer.md` with:

```md
# Role

You are a read-only diff reviewer.

Review the diff first.
Request additional context only when the diff is insufficient.

# Review Criteria

Check:
- correctness
- spec compliance
- security
- backward compatibility
- test coverage
- maintainability
- over-engineering

# Rules

- Do not edit files.
- Do not ask to read entire files unless necessary.
- Prefer specific comments tied to concrete files or diff hunks.
- Separate blocking issues from non-blocking suggestions.
- Do not delegate to other agents.

# Output Format

1. Verdict: APPROVE / REQUEST_CHANGES / NEEDS_CONTEXT
2. Blocking issues
3. Non-blocking suggestions
4. Missing tests
5. Risk assessment
```

- [ ] **Step 6: Create arbiter prompt**

Create `/Users/haru256/.config/opencode/prompts/arbiter.md` with:

```md
# Role

You are the last-resort consultation agent.

Your job is to help when implementation is blocked, design direction is unclear, or repeated failures indicate a bad approach.

You must not edit files.
You must not run broad repository exploration.
You must return a compact decision.

# Input You Should Expect

You should mainly rely on:

- task brief
- compact explorer report
- implementer report
- failing test excerpt
- git diff
- relevant file paths

Do not request full file contents unless strictly necessary.

# When To Intervene

Intervene only when:

- the implementer failed twice with the same error class
- the current approach appears architecturally wrong
- the change affects API boundaries, state schema, IAM, data model, or security
- the reviewer cannot decide from the diff alone

# Output Format

1. Diagnosis
2. Likely root cause
3. Recommended next approach
4. What to ask @implementer to do
5. What not to do
6. Risks
7. Whether @reviewer is required after the next implementation
```

- [ ] **Step 7: Inspect prompt files**

Run:

```bash
for file in /Users/haru256/.config/opencode/prompts/{orchestrator,implementer,explorer,reviewer,arbiter}.md; do
  test -s "$file" || exit 1
  sed -n '1,24p' "$file" >/dev/null
done
```

Expected: Exit code 0.

## Task 3: Replace Agent Configuration With B Workflow

**Files:**
- Modify: `/Users/haru256/.config/opencode/opencode.json`

- [ ] **Step 1: Replace the top-level agent configuration**

Modify `/Users/haru256/.config/opencode/opencode.json` so the top-level shape starts with this exact `default_agent` and `agent` block while preserving the existing global `permission`, `mcp`, and `plugin` blocks after `agent`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "default_agent": "orchestrator",
  // エージェント別のツール制御
  "agent": {
    "orchestrator": {
      "description": "Primary orchestration agent. Plans, delegates, reviews compact reports, and uses Superpowers when appropriate. It does not edit files.",
      "mode": "primary",
      "model": "openai/gpt-5.5",
      "reasoningEffort": "medium",
      "textVerbosity": "low",
      "temperature": 0.1,
      "steps": 8,
      "prompt": "{file:/Users/haru256/.config/opencode/prompts/orchestrator.md}",
      "permission": {
        "edit": "deny",
        "read": "allow",
        "bash": "allow",
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
          "implementer": "allow",
          "explorer": "allow",
          "reviewer": "ask",
          "arbiter": "ask"
        },
        "glob": "allow",
        "list": "allow"
      }
    },
    "implementer": {
      "description": "Implementation subagent. Makes scoped code changes, runs checks, fixes failures, and reports compact results.",
      "mode": "subagent",
      "model": "opencode-go/kimi-k2.6",
      "temperature": 0.1,
      "steps": 20,
      "prompt": "{file:/Users/haru256/.config/opencode/prompts/implementer.md}",
      "permission": {
        "edit": "allow",
        "read": "allow",
        "bash": "allow",
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
    "explorer": {
      "description": "Read-only deep repository exploration subagent. Finds relevant files, dependencies, data/control flow, and likely impact radius. Returns compact reports.",
      "mode": "subagent",
      "model": "opencode-go/deepseek-v4-pro",
      "temperature": 0.1,
      "steps": 12,
      "prompt": "{file:/Users/haru256/.config/opencode/prompts/explorer.md}",
      "permission": {
        "edit": "deny",
        "read": "allow",
        "bash": "allow",
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
    "reviewer": {
      "description": "Read-only diff review subagent. Checks correctness, spec compliance, security, tests, maintainability, and over-engineering.",
      "mode": "subagent",
      "model": "openai/gpt-5.4",
      "reasoningEffort": "medium",
      "textVerbosity": "low",
      "temperature": 0.1,
      "steps": 6,
      "prompt": "{file:/Users/haru256/.config/opencode/prompts/reviewer.md}",
      "permission": {
        "edit": "deny",
        "read": "allow",
        "bash": "allow",
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
    "arbiter": {
      "description": "Hidden last-resort consultation subagent. Diagnoses blocked tasks, redesigns approach, and returns a compact decision. It never edits files.",
      "mode": "subagent",
      "hidden": true,
      "model": "openai/gpt-5.5",
      "reasoningEffort": "high",
      "textVerbosity": "low",
      "temperature": 0.1,
      "steps": 6,
      "prompt": "{file:/Users/haru256/.config/opencode/prompts/arbiter.md}",
      "permission": {
        "edit": "deny",
        "read": "allow",
        "bash": "allow",
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
  }
}
```

Keep the existing global blocks below `agent`, especially:

```jsonc
"permission": { ... },
"mcp": { ... },
"plugin": [
  "superpowers@git+https://github.com/obra/superpowers.git"
]
```

- [ ] **Step 2: Ensure obsolete B-predecessor agents are gone**

Run:

```bash
rg -n '"codebase-researcher"|"test-fixer"|"diff-summarizer"|"refactor-worker"|"docs-worker"' /Users/haru256/.config/opencode/opencode.json
```

Expected: No output and exit code 1.

- [ ] **Step 3: Ensure B workflow agents are present**

Run:

```bash
rg -n '"orchestrator"|"implementer"|"explorer"|"reviewer"|"arbiter"|"default_agent"' /Users/haru256/.config/opencode/opencode.json
```

Expected: Output includes all five agent names and `default_agent`.

## Task 4: Create Slash Commands

**Files:**
- Create: `/Users/haru256/.config/opencode/commands/quick-fix.md`
- Create: `/Users/haru256/.config/opencode/commands/feature.md`

- [ ] **Step 1: Ensure command directory exists**

Run:

```bash
mkdir -p /Users/haru256/.config/opencode/commands
```

Expected: Directory exists.

Run:

```bash
test -d /Users/haru256/.config/opencode/commands
```

Expected: Exit code 0.

- [ ] **Step 2: Create quick-fix command**

Create `/Users/haru256/.config/opencode/commands/quick-fix.md` with:

```md
---
description: Small focused fix without full planning
agent: implementer
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

- [ ] **Step 3: Create feature command**

Create `/Users/haru256/.config/opencode/commands/feature.md` with:

```md
---
description: Plan and implement a non-trivial feature
agent: orchestrator
---

Plan and implement the following feature with compact delegation.

Feature:
$ARGUMENTS

Rules:
- Clarify requirements only if necessary.
- Use @explorer before reading many files.
- Delegate implementation to @implementer.
- Use @reviewer for meaningful behavior changes.
- Ask before invoking @arbiter.
- Keep reports compact.
```

- [ ] **Step 4: Inspect command files**

Run:

```bash
for file in /Users/haru256/.config/opencode/commands/{quick-fix,feature}.md; do
  test -s "$file" || exit 1
  sed -n '1,24p' "$file" >/dev/null
done
```

Expected: Exit code 0.

## Task 5: Validate OpenCode Loads The B Configuration

**Files:**
- Read: `/Users/haru256/.config/opencode/opencode.json`
- Read: `/Users/haru256/.config/opencode/prompts/*.md`
- Read: `/Users/haru256/.config/opencode/commands/*.md`

- [ ] **Step 1: List agents with plugins disabled**

Run:

```bash
mise exec -- opencode --pure agent list | rg 'orchestrator \(primary\)|implementer \(subagent\)|explorer \(subagent\)|reviewer \(subagent\)|arbiter \(subagent\)'
```

Expected:

```text
arbiter (subagent)
explorer (subagent)
implementer (subagent)
orchestrator (primary)
reviewer (subagent)
```

Order may differ.

- [ ] **Step 2: Confirm hidden arbiter does not appear in normal interactive selection if OpenCode hides it**

Run:

```bash
mise exec -- opencode --pure agent list | rg 'arbiter \(subagent\)'
```

Expected: `agent list` may still show hidden agents because it is an admin listing. Hidden behavior is considered acceptable if the config loads and `hidden: true` is present in the file.

Run:

```bash
rg -n '"arbiter"|"hidden": true' /Users/haru256/.config/opencode/opencode.json
```

Expected: Output includes both `arbiter` and `"hidden": true`.

- [ ] **Step 3: Smoke test primary orchestrator**

Run:

```bash
mise exec -- opencode run --agent orchestrator --format json --dir /Users/haru256/Documents/projects/dotfiles "Reply with exactly: balanced orchestrator available. Do not edit files." > /tmp/opencode-balanced-orchestrator-smoke.jsonl
tail -n 20 /tmp/opencode-balanced-orchestrator-smoke.jsonl
```

Expected: Output contains:

```text
balanced orchestrator available.
```

- [ ] **Step 4: Verify no files were edited by smoke test**

Run:

```bash
git -C /Users/haru256/Documents/projects/dotfiles status --short
```

Expected: No new changes caused by the smoke test. Pre-existing dirty files may remain.

## Task 6: Optional Dotfiles Documentation

**Files:**
- Optional modify: `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md`

- [ ] **Step 1: Decide whether repository guidance needs an OpenCode B workflow note**

Read the relevant section:

```bash
rg -n 'OpenCode|orchestrator|subagent|委譲' /Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md
```

Expected: Existing OpenCode guidance may already exist from earlier work.

- [ ] **Step 2: If the existing guidance still describes Codex-to-OpenCode wrapper operation as primary, update it**

Add this concise note to `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md` only if it clarifies current operation:

```md
## OpenCode Balanced Workflow

- OpenCode の通常入口は `orchestrator` を使う。
- `orchestrator` は設計・分解・委譲・レビュー判断を担当し、原則として直接編集しない。
- 実装は `@implementer`、探索は `@explorer`、diff レビューは `@reviewer`、詰まり時の相談は `@arbiter` に委譲する。
- `@arbiter` は常用せず、同種の失敗が繰り返される場合や設計判断が必要な場合だけ使う。
```

- [ ] **Step 3: If the existing guidance is already accurate, leave it unchanged**

Run:

```bash
git -C /Users/haru256/Documents/projects/dotfiles diff -- .agents/AGENTS.md
```

Expected: Either no additional diff for this task or only the concise OpenCode B workflow note.

## Task 7: Final Verification And Handoff

**Files:**
- Read: `/Users/haru256/.config/opencode/opencode.json`
- Read: `/Users/haru256/.config/opencode/prompts/*.md`
- Read: `/Users/haru256/.config/opencode/commands/*.md`

- [ ] **Step 1: Verify model fields are only in config, not role names**

Run:

```bash
rg -n 'gpt55|GPT-5\.5|Kimi|kimi|DeepSeek|deepseek' /Users/haru256/.config/opencode/opencode.json /Users/haru256/.config/opencode/prompts
```

Expected: Model names may appear only in `model` values in `opencode.json`. Prompt files and agent names should not contain provider or model branding.

- [ ] **Step 2: Verify configured models**

Run:

```bash
rg -n '"model": "openai/gpt-5\.5"|"model": "openai/gpt-5\.4"|"model": "opencode-go/kimi-k2\.6"|"model": "opencode-go/deepseek-v4-pro"' /Users/haru256/.config/opencode/opencode.json
```

Expected:

```text
"model": "openai/gpt-5.5"
"model": "opencode-go/kimi-k2.6"
"model": "opencode-go/deepseek-v4-pro"
"model": "openai/gpt-5.4"
"model": "openai/gpt-5.5"
```

- [ ] **Step 3: Verify command entrypoints are present**

Run:

```bash
rg -n '^agent: (implementer|orchestrator)$|^description:' /Users/haru256/.config/opencode/commands/quick-fix.md /Users/haru256/.config/opencode/commands/feature.md
```

Expected: `quick-fix.md` routes to `implementer`; `feature.md` routes to `orchestrator`.

- [ ] **Step 4: Record final status**

Run:

```bash
git -C /Users/haru256/Documents/projects/dotfiles status --short
```

Expected: The plan document is present in `docs/superpowers/plans/`. OpenCode config changes live under `/Users/haru256/.config/opencode/` unless dotfiles management is added later.

## Self-Review

- Spec coverage: The plan covers the B workflow agents, prompt externalization, slash commands, model availability checks, OpenCode load checks, and final smoke test.
- Placeholder scan: No steps use TBD/TODO/fill-in instructions. Optional documentation is bounded and includes exact text if needed.
- Type consistency: Agent names are consistently `orchestrator`, `implementer`, `explorer`, `reviewer`, and `arbiter`. Prompt file paths and command paths are absolute and match the config references.
- Scope check: This plan intentionally configures the OpenCode runtime first. It does not migrate every OpenCode file into dotfiles-managed symlinks; that can be a separate plan if desired.
