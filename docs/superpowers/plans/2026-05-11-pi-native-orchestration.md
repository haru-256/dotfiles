# Pi Native Orchestration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure Pi Coding Agent in this dotfiles repo to use Pi-native subagent orchestration that mirrors the useful parts of the previous OpenCode Superpowers + orchestrator workflow.

**Architecture:** Keep global Pi settings reusable: packages, the parent session default model, and persistent built-in subagent model routing live in `~/.pi/agent/settings.json`. Add reusable `.chain.md` workflows under `.pi/agent/chains/` so the same orchestration shortcuts are global rather than repo-specific. The parent Pi session remains the orchestrator on `gpt-5.5`; `oracle` also uses `gpt-5.5`; routine subagents use `opencode-go` models through `subagents.agentOverrides`.

**Tech Stack:** Pi Coding Agent JSON settings, global `pi-subagents` chain files, `pi-intercom`, `pi-superpowers`, Markdown AGENTS instructions, shell/JQ validation.

---

## Background

Pi Coding Agent reads global settings from `~/.pi/agent/settings.json` and project settings from `.pi/settings.json`. For this setup, do not use repo-specific Pi settings; keep the orchestrator defaults global so every repository gets the same workflow. This repo already manages the global settings through:

```text
/Users/haru256/.pi/agent/settings.json -> /Users/haru256/Documents/projects/dotfiles/.pi/agent/settings.json
```

The global settings already include:

```json
{
  "packages": [
    "git:github.com/otahontas/pi-coding-agent-catppuccin",
    "npm:pi-subagents",
    "git:github.com/coctostan/pi-superpowers",
    "npm:pi-intercom"
  ]
}
```

The implementation should not recreate OpenCode custom agents in Pi. It should use Pi-native subagents and chains:

- `scout`: local codebase reconnaissance, routed to `opencode-go/deepseek-v4-flash`
- `planner`: implementation planning, routed to `opencode-go/deepseek-v4-pro`
- `worker`: scoped code changes, routed to `opencode-go/kimi-k2.6`
- `reviewer`: review, preferably fresh context and separated by concern, routed to `opencode-go/deepseek-v4-pro`
- `oracle`: second opinion / escalation before risky decisions, routed to `openai-codex/gpt-5.5`

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `/Users/haru256/Documents/projects/dotfiles/.pi/agent/settings.json` | Modify | Keep global Pi packages, parent-session default model, and persistent subagent model overrides. |
| `/Users/haru256/Documents/projects/dotfiles/.pi/agent/chains/context-plan.chain.md` | Create | Reusable `scout -> planner` chain for discovery and planning. |
| `/Users/haru256/.pi/agent/chains` | Symlink | Point Pi's user-scope chain directory at the dotfiles-managed chain directory. |
| `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md` | Modify | Add Pi-native orchestration rules without disturbing existing OpenCode rules. |

## Non-Goals

- Do not port `.config/opencode/prompts/*.md` into Pi custom agents.
- Do not remove the existing OpenCode configuration.
- Do not add API keys, tokens, auth files, or provider credentials to dotfiles.
- Do not commit, push, tag, release, merge, rebase, reset, or revert unrelated user changes unless explicitly requested.
- Do not introduce unverified Pi extension settings beyond documented settings and chain files.
- Do not create `.pi/settings.json`; this setup should be global and reusable across repositories.
- Do not override `researcher` unless `pi-web-access` is also installed and configured; this plan does not add web research support.

## Pre-flight

- [ ] **Step 1: Confirm working tree state**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles
git status --short
```

Expected: Existing unrelated dirty files may be present, including files outside `.pi/` and `docs/superpowers/plans/`. Do not revert them.

- [ ] **Step 2: Confirm global Pi settings are managed by dotfiles**

Run:

```bash
readlink /Users/haru256/.pi/agent/settings.json
```

Expected:

```text
/Users/haru256/Documents/projects/dotfiles/.pi/agent/settings.json
```

- [ ] **Step 3: Confirm current Pi settings parse**

Run:

```bash
jq empty /Users/haru256/Documents/projects/dotfiles/.pi/agent/settings.json
```

Expected: Exit code 0.

- [ ] **Step 4: Confirm no secrets in existing Pi settings**

Run:

```bash
rg -n --hidden --no-ignore -i 'api[_-]?key|secret|token|password|bearer|sk-[A-Za-z0-9]|ghp_|github_pat_|AKIA|ANTHROPIC|GEMINI|GOOGLE_API' \
  /Users/haru256/Documents/projects/dotfiles/.pi/agent/settings.json
```

Expected: Either no output and exit code 1, or only non-secret provider names. If an actual credential appears, stop and report `BLOCKED` with `failure_signature: secret/pi-settings/credential-present`.

---

### Task 1: Configure Global Pi Settings And Subagent Routing

**Files:**
- Modify: `/Users/haru256/Documents/projects/dotfiles/.pi/agent/settings.json`

**Why:** Keep user-wide Pi defaults, package loading, and generic subagent model routing in one symlink-managed file. Token cost is controlled by using `gpt-5.5` only for the parent orchestrator and `oracle`; routine subagents use `opencode-go` models.

- [ ] **Step 1: Read current file**

Run:

```bash
sed -n '1,220p' /Users/haru256/Documents/projects/dotfiles/.pi/agent/settings.json
```

Expected current content may look like:

```json
{
  "lastChangelogVersion": "0.74.0",
  "packages": [
    "git:github.com/otahontas/pi-coding-agent-catppuccin",
    "npm:pi-subagents",
    "git:github.com/coctostan/pi-superpowers",
    "npm:pi-intercom"
  ],
  "theme": "catppuccin-latte",
  "compaction": {
    "enabled": true
  },
  "defaultProvider": "openai-codex",
  "defaultModel": "gpt-5.5",
  "defaultThinkingLevel": "medium"
}
```

If the content differs only by harmless formatting, `lastChangelogVersion`, or already-present `subagents.agentOverrides`, continue. If required packages are missing, restore them in the next step.

- [ ] **Step 2: Write normalized global settings with model routing**

Replace `/Users/haru256/Documents/projects/dotfiles/.pi/agent/settings.json` with:

```json
{
  "lastChangelogVersion": "0.74.0",
  "packages": [
    "git:github.com/otahontas/pi-coding-agent-catppuccin",
    "npm:pi-subagents",
    "git:github.com/coctostan/pi-superpowers",
    "npm:pi-intercom"
  ],
  "theme": "catppuccin-latte",
  "compaction": {
    "enabled": true
  },
  "defaultProvider": "openai-codex",
  "defaultModel": "gpt-5.5",
  "defaultThinkingLevel": "medium",
  "subagents": {
    "agentOverrides": {
      "scout": {
        "model": "opencode-go/deepseek-v4-flash",
        "thinking": "low",
        "fallbackModels": [
          "opencode-go/deepseek-v4-pro"
        ]
      },
      "planner": {
        "model": "opencode-go/deepseek-v4-pro",
        "thinking": "medium",
        "fallbackModels": [
          "opencode-go/kimi-k2.6"
        ]
      },
      "context-builder": {
        "model": "opencode-go/deepseek-v4-pro",
        "thinking": "medium",
        "fallbackModels": [
          "opencode-go/deepseek-v4-flash"
        ]
      },
      "worker": {
        "model": "opencode-go/kimi-k2.6",
        "thinking": "medium",
        "fallbackModels": [
          "opencode-go/deepseek-v4-pro"
        ]
      },
      "reviewer": {
        "model": "opencode-go/deepseek-v4-pro",
        "thinking": "high",
        "fallbackModels": [
          "opencode-go/kimi-k2.6"
        ]
      },
      "delegate": {
        "model": "opencode-go/deepseek-v4-pro",
        "thinking": "medium",
        "fallbackModels": [
          "opencode-go/deepseek-v4-flash"
        ]
      },
      "oracle": {
        "model": "openai-codex/gpt-5.5",
        "thinking": "high"
      }
    }
  }
}
```

Routing policy:

| Scope | Model | Thinking | Reason |
|---|---|---|---|
| parent session / orchestrator | `openai-codex/gpt-5.5` via `defaultProvider` + `defaultModel` | `medium` | Highest-quality coordination, user intent, and adjudication. |
| `scout` | `opencode-go/deepseek-v4-flash` | `low` | Cheap large-context reconnaissance; fallback to Pro if Flash is insufficient or unavailable. |
| `planner` | `opencode-go/deepseek-v4-pro` | `medium` | Better fit than Kimi for architecture, tradeoff analysis, and implementation planning. |
| `context-builder` | `opencode-go/deepseek-v4-pro` | `medium` | Planning handoff context needs broad repo synthesis. |
| `worker` | `opencode-go/kimi-k2.6` | `medium` | Kimi is the coding-focused default for implementation. |
| `reviewer` | `opencode-go/deepseek-v4-pro` | `high` | Review benefits from impact analysis and broad context. |
| `delegate` | `opencode-go/deepseek-v4-pro` | `medium` | General delegation should avoid `gpt-5.5` while staying capable. |
| `oracle` | `openai-codex/gpt-5.5` | `high` | Rare escalation path where judgment matters most. |

- [ ] **Step 3: Validate JSON**

Run:

```bash
jq empty /Users/haru256/Documents/projects/dotfiles/.pi/agent/settings.json
```

Expected: Exit code 0.

- [ ] **Step 4: Commit task**

Run:

```bash
git add /Users/haru256/Documents/projects/dotfiles/.pi/agent/settings.json
git commit -m "chore(pi): configure global agent routing"
```

Expected: Commit succeeds if the user has requested commits for this implementation run. If commits were not requested, skip this step and record it in the implementation report.

---

### Task 2: Verify No Repo-Specific Pi Settings Are Added

**Files:**
- Read: `/Users/haru256/Documents/projects/dotfiles/.pi/settings.json`

**Why:** The orchestrator defaults and subagent routing should be global. This task prevents accidentally adding repo-specific Pi overrides.

- [ ] **Step 1: Confirm `.pi/settings.json` is absent**

Run:

```bash
test ! -e /Users/haru256/Documents/projects/dotfiles/.pi/settings.json
```

Expected: Exit code 0. If the file exists, remove it only if it was created by this implementation attempt. If it existed before the attempt, stop and report `NEEDS_CONTEXT`.

- [ ] **Step 2: Confirm no project settings are staged**

```bash
git status --short /Users/haru256/Documents/projects/dotfiles/.pi/settings.json
```

Expected: No output.

---

### Task 3: Add Global Chain Directory And Symlink

**Files:**
- Create: `/Users/haru256/Documents/projects/dotfiles/.pi/agent/chains/`
- Symlink: `/Users/haru256/.pi/agent/chains`

**Why:** Pi discovers user-scope chains from `~/.pi/agent/chains/**/*.chain.md`. The repo should manage those chain files in dotfiles, with only the `~/.pi/agent/chains` path symlinked into place.

- [ ] **Step 1: Create chain directory**

Run:

```bash
mkdir -p /Users/haru256/Documents/projects/dotfiles/.pi/agent/chains
```

Expected: Directory exists.

- [ ] **Step 2: Create or verify symlink**

Run:

```bash
if [ -e /Users/haru256/.pi/agent/chains ] && [ ! -L /Users/haru256/.pi/agent/chains ]; then
  echo "BLOCKED: /Users/haru256/.pi/agent/chains exists and is not a symlink"
  exit 2
fi
ln -sfn /Users/haru256/Documents/projects/dotfiles/.pi/agent/chains /Users/haru256/.pi/agent/chains
readlink /Users/haru256/.pi/agent/chains
```

Expected:

```text
/Users/haru256/Documents/projects/dotfiles/.pi/agent/chains
```

If the command prints `BLOCKED`, stop and report `NEEDS_CONTEXT`; do not overwrite a real directory that may contain user-managed chains.

---

### Task 4: Add Context And Planning Chain

**Files:**
- Create: `/Users/haru256/Documents/projects/dotfiles/.pi/agent/chains/context-plan.chain.md`

**Why:** Reusable `scout -> planner` flow for requests where the implementation scope is not obvious.

- [ ] **Step 1: Create `context-plan.chain.md`**

Create `/Users/haru256/Documents/projects/dotfiles/.pi/agent/chains/context-plan.chain.md` with:

```markdown
---
name: context-plan
description: Gather local code context, then produce an implementation plan.
---

## scout
output: context.md
outputMode: file-only
progress: true

Inspect the current repository for this task:

{task}

Return a compact context report with:
- relevant files and directories
- existing patterns to follow
- likely change boundaries
- risks or ambiguous requirements
- recommended starting point for planning

Do not edit files.

## planner
reads: context.md
output: plan.md
outputMode: inline
progress: true

Create a concrete implementation plan for:

{task}

Use the scout report from `context.md`.

The plan must include:
- exact files to create or modify
- validation commands
- risks and non-goals
- a recommendation on whether implementation should be done inline, by one worker, or by multiple workers

Do not edit source files.
```

- [ ] **Step 2: Validate file exists**

Run:

```bash
test -f /Users/haru256/Documents/projects/dotfiles/.pi/agent/chains/context-plan.chain.md
```

Expected: Exit code 0.

- [ ] **Step 3: Commit task**

Run:

```bash
git add /Users/haru256/Documents/projects/dotfiles/.pi/agent/chains/context-plan.chain.md
git commit -m "chore(pi): add context planning chain"
```

Expected: Commit succeeds if commits were requested. If commits were not requested, skip this step and record it in the implementation report.

---

### Task 5: Document Pi Review And Implementation Shortcuts

**Files:**
- Read: `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md`

**Why:** Pi already provides recommended orchestration shortcuts such as `/parallel-review`. Do not replace fresh parallel reviewers with a custom sequential review chain. The parent session should approve planner output before launching `worker`.

- [ ] **Step 1: Confirm packaged shortcuts are available**

Run inside Pi after settings are loaded:

```text
/subagents-doctor
```

Expected:
- `pi-subagents` is loaded
- built-in agents are available
- packaged prompt shortcuts such as `/parallel-review` are available

- [ ] **Step 2: Use this standard execution pattern**

For medium or larger implementation work, use this parent-session flow:

```text
1. Clarify the goal, constraints, non-goals, and acceptance criteria.
2. Run `/run-chain context-plan -- <task>` or ask `scout` and `planner` in plain language.
3. Parent session reviews and approves or revises the plan.
4. Run `worker` on the approved plan.
5. Run `/parallel-review` on the resulting diff.
6. Parent session adjudicates findings into ACCEPT / REJECT / DEFER / NEEDS_CONTEXT / ESCALATE.
7. Run `worker` only on ACCEPT findings.
```

Expected: There is no saved chain that jumps directly from planner to worker without parent approval.

---

### Task 6: Add Pi Workflow Rules To AGENTS

**Files:**
- Modify: `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md`

**Why:** Make the parent Pi session behave like the old OpenCode orchestrator without copying OpenCode-specific prompt files. These instructions are durable and visible to any agent reading the repo guidance.

- [ ] **Step 1: Find insertion point**

Run:

```bash
rg -n 'OpenCode Balanced Workflow|Git 運用' /Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md
```

Expected: Both headings exist. Insert the new section after the OpenCode Balanced Workflow section and before `## Git 運用`.

- [ ] **Step 2: Insert Pi-native section**

Insert the following Markdown before `## Git 運用` in `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md`:

```markdown
## Pi Native Orchestration Workflow

Pi Coding Agent では、親セッションを orchestrator として扱い、`pi-subagents` の built-in agents を使って作業を分担する。

**基本方針:**
- typo・1行修正・README 小修正 → 親セッションで直接対応するか、`worker` に短く依頼する
- どこを触るか不明 → `scout` で調査してから判断する
- 中規模以上の機能 → `clarify -> scout/planner -> parent approval -> worker -> /parallel-review -> parent adjudication -> worker` の順で進める
- 実装前に計画が必要な場合 → `/run-chain context-plan -- <task>` を使う
- planner の出力は親セッションが確認・修正・承認してから `worker` に渡す
- 実装からレビューまでを親承認なしで一括実行する saved chain は使わない
- 既存 diff や成果物のレビュー → Pi 付属の `/parallel-review` を使う
- 判断が割れる、または設計・API・state schema・IAM・データモデル・セキュリティに影響する → `oracle` に相談する

**親セッションの責務:**
- ゴール、制約、非ゴール、受け入れ条件を明確にする
- subagent の出力をそのまま実装指示にせず、採否を判断する
- reviewer findings は `ACCEPT / REJECT / DEFER / NEEDS_CONTEXT / ESCALATE` に分類する
- `ACCEPT` した指摘だけを `worker` に渡す
- `DEFER` は follow-up として記録する
- `ESCALATE` は `oracle` に相談する前にユーザーへ確認する

**子 subagent の境界:**
- 子 subagent はさらに subagent を起動しない
- `scout` と `reviewer` は原則 read-only とする
- `worker` は指定された計画・範囲・受け入れ条件に沿って最小変更を行う
- API 境界、永続データ、IAM、セキュリティ、外部依存の判断が必要な場合、`worker` は推測せず `NEEDS_CONTEXT` を返す

**pi-intercom:**
- 複数 Pi セッションで同じコードベースを扱う場合だけ使う
- 進捗通知は `send`、作業を止める判断待ちは `ask` を優先する
- 無関係なコードベースや些細な作業では使わない
```

- [ ] **Step 3: Verify section exists once**

Run:

```bash
rg -n 'Pi Native Orchestration Workflow|/parallel-review|ACCEPT / REJECT / DEFER' \
  /Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md
```

Expected: The inserted heading and key lines appear once.

- [ ] **Step 4: Commit task**

Run:

```bash
git add /Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md
git commit -m "docs(agents): document pi orchestration workflow"
```

Expected: Commit succeeds if commits were requested. If commits were not requested, skip this step and record it in the implementation report.

---

### Task 7: Validate Pi Configuration

**Files:**
- Read: `/Users/haru256/Documents/projects/dotfiles/.pi/agent/settings.json`
- Read: `/Users/haru256/Documents/projects/dotfiles/.pi/agent/chains/context-plan.chain.md`
- Read: `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md`

- [ ] **Step 1: Validate JSON files**

Run:

```bash
jq empty \
  /Users/haru256/Documents/projects/dotfiles/.pi/agent/settings.json
```

Expected: Exit code 0.

- [ ] **Step 2: Verify required packages remain in global settings**

Run:

```bash
jq -r '.packages[]' /Users/haru256/Documents/projects/dotfiles/.pi/agent/settings.json | sort
```

Expected:

```text
git:github.com/coctostan/pi-superpowers
git:github.com/otahontas/pi-coding-agent-catppuccin
npm:pi-intercom
npm:pi-subagents
```

- [ ] **Step 3: Verify chain files exist**

Run:

```bash
find /Users/haru256/Documents/projects/dotfiles/.pi/agent/chains -maxdepth 1 -name '*.chain.md' -print | sort
```

Expected:

```text
/Users/haru256/Documents/projects/dotfiles/.pi/agent/chains/context-plan.chain.md
```

- [ ] **Step 4: Check tracked Pi files for secret-like strings**

Run:

```bash
rg -n --hidden --no-ignore -i 'api[_-]?key|secret|token|password|bearer|sk-[A-Za-z0-9]|ghp_|github_pat_|AKIA|ANTHROPIC|GEMINI|GOOGLE_API' \
  /Users/haru256/Documents/projects/dotfiles/.pi \
  /Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md
```

Expected: No actual credentials. Matches in prose such as `api[_-]?key` only appear if the command itself was copied into a plan; `.pi/` and `.agents/AGENTS.md` should have no secret values.

- [ ] **Step 5: Verify symlinks still point to dotfiles**

Run:

```bash
readlink /Users/haru256/.pi/agent/settings.json
readlink /Users/haru256/.pi/agent/chains
```

Expected:

```text
/Users/haru256/Documents/projects/dotfiles/.pi/agent/settings.json
/Users/haru256/Documents/projects/dotfiles/.pi/agent/chains
```

- [ ] **Step 6: Run Pi diagnostics manually**

Run inside Pi, not as a shell command:

```text
/subagents-doctor
```

Expected:
- `pi-subagents` is loaded
- built-in agents are available
- no missing required package errors

- [ ] **Step 7: Verify global chain discovery manually**

Run inside Pi from `/Users/haru256/Documents/projects/dotfiles`:

```text
/run-chain context-plan -- この dotfiles repo の Pi 設定を確認して、次の一手を提案して
```

Expected:
- `scout` runs first
- `planner` runs after `scout`
- output references the current repository
- no file edits occur

- [ ] **Step 8: Verify packaged review shortcut manually**

Run inside Pi from `/Users/haru256/Documents/projects/dotfiles` after creating a harmless local diff or on an existing diff:

```text
/parallel-review
```

Expected:
- fresh-context reviewers run with distinct angles
- parent session receives synthesized review output
- no automatic fixes are applied unless explicitly requested

- [ ] **Step 9: Final git diff review**

Run:

```bash
git diff --stat
git diff -- /Users/haru256/Documents/projects/dotfiles/.pi /Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md
```

Expected:
- Diff contains only Pi settings, chain files, and AGENTS Pi workflow instructions.
- No `auth.json`, session files, broker files, API keys, tokens, or credentials are present.

---

## Implementation Log

<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N -> STATUS | commit-or-failure-signature -->

## Review Findings

<!-- Parent/orchestrator copies structured reviewer findings here when invoking reviewers during this workflow. Raw findings are review input (audit history), not implementation instructions. -->

### Reviewer Raw Findings

<!-- Structured findings go here verbatim. -->

### Orchestrator Adjudication

<!-- Parent/orchestrator appends adjudication tables here. Only ACCEPT rows are implementation instructions:
     | ID | Severity | Decision | Reason | Action | -->

## Deviations from Plan

<!-- Implementer documents intentional deviations and reasons. -->

## Open Questions

<!-- Any agent adds questions for parent/orchestrator or oracle. -->
