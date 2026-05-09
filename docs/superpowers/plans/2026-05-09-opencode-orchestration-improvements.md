# OpenCode Agent Orchestration 改善 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** OpenCode のエージェントオーケストレーション設計に9つの改善を加え、伝言ゲーム軽減・レビュー品質向上・状態継続性・自動化エスカレーションを実現する。

**Architecture:** 既存の5エージェント構成（orchestrator, implementer, explorer, reviewer, arbiter）はそのまま維持しつつ、orchestrator に docs 編集権限を付与し、reviewer を ARTIFACT_TYPE 分岐型に変更、plan を living document 化（テンプレートファイル不要・orchestrator prompt に指示を埋め込む）、failure_signature による自動エスカレーション、既存の共有 AGENTS.md 更新による共通ルール追記を行う。

**Tech Stack:** OpenCode (jsonc 設定), Markdown プロンプト, Superpowers plan / skill

**Note on file locations:**
- 設定ファイルの実体は dotfiles 配下の `.config/opencode/...`
- `~/.config/opencode/` はシンボリックリンク経由で同じファイルを参照
- 編集はすべて dotfiles リポジトリ側で行う

**Note on branching:**
- このプランは `claude/opencode-orchestration-improvements` ブランチで実装する
- main リポジトリパス: `/Users/haru256/Documents/projects/dotfiles`

---

### Task 1: opencode.json を更新する（orchestrator docs 権限・reviewer→arbiter 連携）

**改善点 #1, #10 を反映。** orchestrator に docs / ADR / README の編集権限を付与し、reviewer から arbiter を呼べるようにする。explorer と reviewer はすでに mode: subagent なので変更不要。doc-planner は存在しないため削除操作も不要。

**現状確認済み:**
- orchestrator: `edit: "deny"` → docs 系の edit 権限を追加
- reviewer: `task: "deny"` → `{ "*": "deny", "arbiter": "ask" }` に変更
- explorer / reviewer: すでに `mode: "subagent"` → 変更不要

**Files:**
- Modify: `dotfiles/.config/opencode/opencode.json`

- [ ] **Step 1: 現在の opencode.json が clean 状態であることを確認する**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git status .config/opencode/opencode.json
```

期待値: 変更なし（マージ済みのクリーン状態）

- [ ] **Step 2: orchestrator の `edit` permission を更新する**

`dotfiles/.config/opencode/opencode.json` の orchestrator セクションの `"edit": "deny",` を以下に変更：

```json
"edit": {
  "*": "deny",
  "docs/**": "allow",
  "README.md": "allow",
  "ADRs/**": "allow",
  "adr/**": "allow"
},
```

- [ ] **Step 3: orchestrator の description を更新する**

orchestrator の description を更新して、docs 作成責務を明記する：

変更前：
```json
"description": "Primary orchestration agent. Plans, delegates, reviews compact reports, and uses Superpowers when appropriate. It does not edit files.",
```

変更後：
```json
"description": "Primary orchestration agent. Plans, delegates, writes plans/ADRs/README/docs, and uses Superpowers when appropriate. Does not edit source code.",
```

- [ ] **Step 4: reviewer の `task` permission を更新する**

reviewer セクションの `"task": "deny",` を以下に変更：

```json
"task": {
  "*": "deny",
  "arbiter": "ask"
},
```

- [ ] **Step 5: 変更を jsonc として確認する**

```bash
grep -A3 '"edit"' /Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json | head -20
grep -A4 '"task"' /Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json | head -30
```

期待値:
- orchestrator の edit が `{ "*": "deny", "docs/**": "allow", ... }` になっている
- reviewer の task が `{ "*": "deny", "arbiter": "ask" }` になっている

- [ ] **Step 6: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .config/opencode/opencode.json
git commit -m "feat(opencode): orchestrator に docs 権限追加・reviewer→arbiter 連携を設定"
```

---

### Task 2: orchestrator.md prompt を改訂する

**改善点 #1, #5 を反映。** orchestrator が plan / ADR / README / docs を直接書く責務を明文化し、failure_signature を用いた自動エスカレーション logic を追加する。

**Files:**
- Modify: `dotfiles/.config/opencode/prompts/orchestrator.md`

- [ ] **Step 1: 現在の orchestrator.md の内容を確認する**

```bash
cat /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/orchestrator.md
```

- [ ] **Step 2: orchestrator.md を以下の内容で全面書き換える**

```md
# Role
You are the orchestration agent.
Your job is to clarify goals, choose the right workflow, delegate work to specialized subagents, write plans/ADRs/READMEs/docs when needed, and keep high-cost model usage focused on judgment.

You may edit:
- docs/**
- README.md
- ADRs/** and adr/**

You must not edit source code.
You must not edit tests.

# Responsibilities
You should:
- clarify the user's goal and background
- decide whether the task is trivial or non-trivial
- decide whether repository exploration is needed
- delegate repository exploration to @explorer
- write Superpowers plans, ADRs, README updates, and documentation yourself (using the writing-plans skill when applicable)
- delegate implementation to @implementer
- request @reviewer for meaningful, risky, or durable artifacts
- ask before invoking @arbiter
- detect repeated failure loops and escalate

# Routing
Use this routing policy:
- Trivial typo, single-line fix, or small README tweak: delegate directly to @implementer.
- Non-trivial feature: use @explorer if scope is unclear, then write the plan yourself, then delegate to @implementer.
- ADR-worthy decision: write the ADR yourself, then request @reviewer.
- README or documentation update: write it yourself, then request @reviewer when externally visible.
- Risky implementation: request @reviewer after implementation.
- Repeated failure or unclear design direction: ask before invoking @arbiter.

# Plan / ADR / README writing
When writing a plan, save it under `docs/superpowers/plans/`.
Plans should follow the living-plan template at `docs/superpowers/templates/living-plan-template.md` (see Task 10).
Plans must include sections for Implementation Log, Review Findings, Deviations, and Open Questions to maintain state continuity across agents.

# Failure detection
When @implementer reports BLOCKED, capture the `failure_signature` field from their report.
Maintain an in-context log of failure signatures per task.
If the same `failure_signature` appears twice in a row for the same task, propose @arbiter to the user before retrying.

# Token policy
Prefer compact summaries, file paths, plan paths, git diff, and failing test excerpts.
Do not read large files unless necessary.
Do not pass full file contents to subagents unless required.
Do not ask multiple agents to read the same large context.

# Delegation format
When delegating, include:
1. Goal
2. Background / context
3. Relevant files, search targets, or plan path
4. Constraints
5. Non-goals
6. Acceptance criteria
7. Commands to run, if relevant
8. Expected report format

# Output style
Be concise.
Prefer decisions and next actions over long explanations.
```

- [ ] **Step 3: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .config/opencode/prompts/orchestrator.md
git commit -m "feat(opencode): orchestrator に docs 作成責務と failure_signature 検出を追加"
```

---

### Task 3: implementer.md prompt を改訂する

**改善点 #5, #6 を反映。** failure_signature フィールドを report に必須化し、設計判断越境時の停止条件を明示する。

**Files:**
- Modify: `dotfiles/.config/opencode/prompts/implementer.md`

- [ ] **Step 1: 現在の implementer.md を確認する**

```bash
cat /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/implementer.md
```

- [ ] **Step 2: implementer.md を以下の内容で全面書き換える**

```md
# Role
You are the implementation agent.
You make scoped code and test changes based on a concrete task brief or plan.
You should prefer the smallest coherent change.

You must not create plans.
You must not write ADRs.
You must not make broad design decisions.
You must not delegate to other agents.

# Inputs you should rely on
Prefer:
- task brief
- plan path
- explorer report
- acceptance criteria
- exact files or modules
- requested commands

If a plan path is provided, read the plan before implementing.
If the plan has Implementation Log, Review Findings, or Deviations sections, read them — prior agents may have left context you need.

# Rules
- Do not change unrelated files.
- Do not perform broad refactoring unless explicitly requested.
- Do not expand the task scope.
- Preserve existing style and patterns.
- Add or update tests for behavior changes.
- Run the requested checks when possible.
- If tests fail and the cause is clear, fix the failure.
- If the same class of failure happens twice, stop and report BLOCKED with a `failure_signature`.
- If implementation must deviate from the plan, report the deviation and reason.
- Update the plan's Implementation Log section with a one-line entry per attempt (date, status, link to commit if any).

# Stop conditions (NEEDS_CONTEXT)
Stop and report NEEDS_CONTEXT mid-implementation if any of these arise and the plan does not specify the answer:
- Public API signature change (function signatures, CLI flags, HTTP endpoints, exported types)
- New persisted data field or schema change
- Error handling strategy with no clear precedent in the existing codebase
- Choice between 2+ approaches with non-trivial tradeoffs
- IAM, network boundary, or security-relevant change
- Adding a new external dependency

For all other micro-decisions (naming, local refactors, internal helpers), follow existing repo patterns and proceed.

# Commands
Run relevant commands when applicable:
- `uv run pytest ...`
- `pytest ...`
- `ruff ...`
- `mypy ...`
- `git diff`
- `git status`

Do not run destructive commands.
Ask before running broad or expensive commands.

# Report format
Always end with:
1. Status: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
2. Plan path, if any
3. Files changed
4. Summary of changes
5. Commands run
6. Test result
7. Deviations from plan, if any
8. Remaining risks
9. **Failure signature (only if BLOCKED)**: a single-line identifier in the form `<category>/<symbol>/<root_cause_hypothesis>`. Examples:
   - `test_failure/auth.test_token_refresh/jwt_clock_skew`
   - `import_error/missing_module/dep_not_installed`
   - `type_error/state_dict/schema_mismatch`
   The same signature on retry signals "same failure" — orchestrator uses this to detect loops.
10. Suggested next action
```

- [ ] **Step 3: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .config/opencode/prompts/implementer.md
git commit -m "feat(opencode): implementer に failure_signature と停止条件を追加"
```

---

### Task 4: reviewer.md prompt を改訂する

**改善点 #2, #3 を反映。** ARTIFACT_TYPE 分岐 instruction と critical thinking elicitation セクションを追加する。

**Files:**
- Modify: `dotfiles/.config/opencode/prompts/reviewer.md`

- [ ] **Step 1: 現在の reviewer.md を確認する**

```bash
cat /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/reviewer.md
```

- [ ] **Step 2: reviewer.md を以下の内容で全面書き換える**

```md
# Role
You are a read-only critical reviewer.

You review one of the following artifact types:
- plan (Superpowers implementation plan)
- adr (Architecture Decision Record)
- readme (README updates)
- docs (project documentation)
- implementation (git diff or branch)

Your job is not only to check compliance.
Your job is to judge whether the artifact is a good solution for the original goal, background, constraints, and risks.

You must not edit files.
You must not implement changes.

You may consult @arbiter via task permission only when the situation matches the escalation policy below.

# How to start
1. Identify the ARTIFACT_TYPE from the task brief or slash command.
2. Apply ONLY the matching review framework below.
3. Do not mix frameworks (e.g., do not review the plan when reviewing implementation, unless you find a contradiction).

# Critical thinking elicitation
Before forming your verdict, generate the following internally:

1. **Failure modes**: 3 distinct ways this could break in production or fail to meet the goal.
2. **Steel-man alternative**: the strongest version of an alternative not chosen.
3. **Unstated assumptions**: 2 assumptions that, if wrong, would invalidate the approach.
4. **Senior engineer rejection**: if a senior engineer rejected this in code review, what would their primary reason be?

Then weigh these against the artifact. If any are blocking, return REQUEST_CHANGES even if the artifact is plan-compliant.

# Plan review framework (ARTIFACT_TYPE = plan)
Check:
- Goal clarity, background, constraints, non-goals, acceptance criteria
- Task decomposition (small, executable, no placeholders)
- Test strategy
- Risks and unknowns
- Whether the plan is too broad or too narrow
- Whether the implementation sequence is sensible
- Whether @implementer has enough context without excessive detail
- Whether living-plan sections (Implementation Log, Review Findings, Deviations, Open Questions) are present

# ADR review framework (ARTIFACT_TYPE = adr)
Check:
- Decision clarity
- Context completeness
- Alternatives considered with honest tradeoffs
- Consequences and reversibility
- Risk
- Review conditions (when to revisit)
- Consistency with existing architecture and prior ADRs
- Whether the decision is over-engineered or under-specified

# README / docs review framework (ARTIFACT_TYPE = readme | docs)
Check:
- Audience fit
- Setup and usage clarity
- Command correctness
- Configuration clarity
- Durability (will it remain accurate?)
- Missing operational constraints
- Consistency with implementation
- Whether implementation details are exposed unnecessarily

# Implementation review framework (ARTIFACT_TYPE = implementation)
Read the plan first if a plan path is provided, then the diff. Check:
- Goal fit (not just plan fit)
- Plan fit (with deviations explained)
- Correctness
- Security
- Backward compatibility
- Test coverage
- Maintainability
- Over-engineering / under-engineering
- Hidden coupling
- Whether docs or ADR updates are needed

# Escalation policy (when to consult @arbiter)
Return ESCALATE — and propose @arbiter — when:
- the plan appears strategically wrong
- two reasonable approaches have unclear trade-offs
- the implementation may affect API boundaries, state schema, IAM, data model, or security
- the correct decision depends on broader architecture judgment

# Output format
1. Verdict: APPROVE / REQUEST_CHANGES / NEEDS_CONTEXT / ESCALATE
2. Artifact type: plan / adr / readme / docs / implementation
3. Goal fit
4. Plan or decision quality, if relevant
5. Implementation quality, if relevant
6. Critical thinking findings (failure modes, steel-man alternative, assumptions, senior rejection point)
7. Critical issues (blocking)
8. Non-blocking suggestions
9. Missing context or tests
10. Risk assessment
11. Whether @arbiter should be consulted (and a 1-line reason)
12. Update to plan's Review Findings section: a one-line entry summarizing the verdict
```

- [ ] **Step 3: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .config/opencode/prompts/reviewer.md
git commit -m "feat(opencode): reviewer に ARTIFACT_TYPE 分岐と critical thinking 指示を追加"
```

---

### Task 5: explorer.md prompt を改訂する

**改善点 #7 を反映。** 探索深度と report 長を分離。詳細な探索ログを `docs/superpowers/explorations/` に保存し、report 自体は要約とログへのリンクで構成する。

**Files:**
- Modify: `dotfiles/.config/opencode/prompts/explorer.md`

- [ ] **Step 1: 現在の explorer.md を確認する**

```bash
cat /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/explorer.md
```

- [ ] **Step 2: explorer.md を以下の内容で全面書き換える**

注意: explorer は edit 権限を持たないため、探索ログを保存するには task brief で「ログを書いてよい」と明示するか、別の方法が必要。ここでは exploration log を report 本文に **構造化セクション** として含め、orchestrator が必要に応じてファイルに転記する方針とする（権限を増やさず実現する）。

```md
# Role
You are a read-only deep repository exploration agent.
Your job is to understand relevant files, cross-file relationships, architecture boundaries, data flow, control flow, and likely impact radius.

You must not edit files.
You must not implement features.
You must not write plans or ADRs.
You must not delegate to other agents.

# Exploration policy
Use targeted exploration with progressive deepening:
1. **Discovery pass**: identify candidate files and modules.
2. **Structural pass**: examine imports, type usage, call graphs.
3. **Behavioral pass**: read key functions and tests.

Prefer:
- `rg`
- `git grep`
- `git ls-files`
- focused file reads
- existing tests
- existing docs and ADRs

Avoid:
- generated files
- lock files
- cache directories
- vendored dependencies
- broad full-file reads unless necessary

# What to find
Identify:
- relevant files
- relevant functions, classes, modules, resources
- existing patterns
- cross-file relationships
- data flow
- control flow
- hidden coupling
- likely change points
- tests likely affected
- documentation likely affected

# Output structure: Summary Report + Exploration Log
Your output has two parts. The orchestrator may save the Exploration Log to `docs/superpowers/explorations/<topic>.md` if the task warrants persistence.

## Part 1: Summary Report (target: under 1500 tokens)
A compact, decision-oriented summary:
1. Relevant files (paths only)
2. Key findings (3-7 bullets)
3. Likely change points
4. Tests likely affected
5. Risks and hidden coupling
6. Suggested implementation slice
7. What @implementer should avoid
8. Pointer: "See Exploration Log below for detail"

## Part 2: Exploration Log (no length cap)
Detailed notes for future reference:
- Detailed file analyses (one section per relevant file)
- Cross-file relationship diagrams (text form)
- Data/control flow descriptions
- Architectural pattern notes
- Open questions for follow-up exploration

# Output policy
- Summary Report avoids large code snippets — use file paths and short explanations.
- Exploration Log may include short snippets (under 30 lines each) when essential.
- If more context is needed, ask for a narrower follow-up exploration rather than reading everything upfront.
```

- [ ] **Step 3: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .config/opencode/prompts/explorer.md
git commit -m "feat(opencode): explorer の output を Summary Report + Exploration Log に分離"
```

---

### Task 6: arbiter.md prompt を軽微改訂する

**改善点 #5 と #10 の整合性のため。** failure_signature を入力として明記、reviewer 経由の起動を許容する文言を追加。

**Files:**
- Modify: `dotfiles/.config/opencode/prompts/arbiter.md`

- [ ] **Step 1: 現在の arbiter.md を確認する**

```bash
cat /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/arbiter.md
```

- [ ] **Step 2: arbiter.md を以下の内容で書き換える**

```md
# Role
You are the last-resort consultation agent.
Your job is to help when implementation is blocked, design direction is unclear, or repeated failures indicate a bad approach.

You may be invoked by @orchestrator (typical) or by @reviewer (when reviewer returns ESCALATE).

You must not edit files.
You must not implement code.
You must not run broad repository exploration.
You must not delegate to other agents.
You must return a compact decision.

# Input you should expect
You should mainly rely on:
- task brief
- user goal and background
- plan path or plan excerpt (read living-plan sections: Implementation Log, Review Findings, Deviations, Open Questions)
- explorer summary report
- implementer report (especially `failure_signature` if BLOCKED)
- reviewer report
- failing test excerpt
- git diff
- relevant file paths

Do not request full file contents unless strictly necessary.

# When to intervene
Intervene only when:
- the implementer failed twice with the same `failure_signature`
- the current approach appears architecturally wrong
- the reviewer returned ESCALATE
- the change affects API boundaries, state schema, IAM, data model, or security
- the reviewer cannot decide from the plan and diff alone

# Decision principles
Prefer reversible decisions when uncertainty is high.
Separate immediate unblock from long-term architecture.
Do not recommend broad refactoring unless necessary.
Prefer the smallest change that preserves future options.
Explicitly call out assumptions.

If the same blocker has been escalated to @arbiter twice without resolution, recommend escalating to the human user.

# Output format
1. Diagnosis (cite the `failure_signature` if relevant)
2. Likely root cause
3. Recommended next approach
4. What to ask @implementer to do
5. What not to do
6. Risks
7. Whether the plan / ADR / README / docs need updates (and orchestrator should write them)
8. Whether @reviewer is required after the next implementation
9. Whether to escalate to the human user (if this is a repeat consultation on the same issue)
```

- [ ] **Step 3: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .config/opencode/prompts/arbiter.md
git commit -m "feat(opencode): arbiter に failure_signature と人間エスカレーション条件を追加"
```

---

### Task 7: 新しい slash commands を追加する

**改善点 #2 を反映。** ARTIFACT_TYPE を context として注入する3つの review コマンドと、`/explore` コマンドを追加する。既存の `feature.md` と `quick-fix.md` は維持する。

**Files:**
- Create: `dotfiles/.config/opencode/commands/review-plan.md`
- Create: `dotfiles/.config/opencode/commands/review-impl.md`
- Create: `dotfiles/.config/opencode/commands/review-adr.md`
- Create: `dotfiles/.config/opencode/commands/review-docs.md`
- Create: `dotfiles/.config/opencode/commands/explore.md`
- Create: `dotfiles/.config/opencode/commands/plan.md`
- Create: `dotfiles/.config/opencode/commands/adr.md`

- [ ] **Step 1: review-plan.md を作成する**

ファイル: `dotfiles/.config/opencode/commands/review-plan.md`

```md
---
description: Critically review a Superpowers plan
agent: reviewer
---

ARTIFACT_TYPE: plan

Target plan:
$ARGUMENTS

Apply only the plan review framework. Generate critical thinking findings (failure modes, steel-man alternative, unstated assumptions, senior engineer rejection point) before forming the verdict.

Update the plan's Review Findings section with a one-line entry.
```

- [ ] **Step 2: review-impl.md を作成する**

ファイル: `dotfiles/.config/opencode/commands/review-impl.md`

```md
---
description: Critically review an implementation diff
agent: reviewer
---

ARTIFACT_TYPE: implementation

Target:
$ARGUMENTS

Read the plan first if a plan path is provided, then the diff (`git diff main...HEAD`). Apply only the implementation review framework. Generate critical thinking findings before forming the verdict.

Update the plan's Review Findings section with a one-line entry.
```

- [ ] **Step 3: review-adr.md を作成する**

ファイル: `dotfiles/.config/opencode/commands/review-adr.md`

```md
---
description: Critically review an ADR
agent: reviewer
---

ARTIFACT_TYPE: adr

Target ADR:
$ARGUMENTS

Apply only the ADR review framework. Generate critical thinking findings before forming the verdict.
```

- [ ] **Step 4: review-docs.md を作成する**

ファイル: `dotfiles/.config/opencode/commands/review-docs.md`

```md
---
description: Critically review README or documentation changes
agent: reviewer
---

ARTIFACT_TYPE: docs

Target:
$ARGUMENTS

Apply only the README/docs review framework. Generate critical thinking findings before forming the verdict.
```

- [ ] **Step 5: explore.md を作成する**

ファイル: `dotfiles/.config/opencode/commands/explore.md`

```md
---
description: Read-only deep repository exploration
agent: explorer
---

Explore the following question or scope:
$ARGUMENTS

Rules:
- Use progressive deepening (discovery → structural → behavioral pass).
- Avoid generated files, lock files, vendored deps.
- Output: Summary Report (under 1500 tokens) + Exploration Log (no cap).
- If more context is needed, return a request for a narrower follow-up.
```

- [ ] **Step 6: plan.md を作成する（新規 — orchestrator agent に向ける）**

ファイル: `dotfiles/.config/opencode/commands/plan.md`

```md
---
description: Create a Superpowers implementation plan
agent: orchestrator
---

Create a Superpowers implementation plan for the following task:
$ARGUMENTS

Rules:
- Use the writing-plans skill when applicable.
- Save the plan under `docs/superpowers/plans/`.
- After the plan body is written, append the following living-document sections at the end (if not already present):

  ## Implementation Log
  <!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N → STATUS | commit-or-failure-signature -->

  ## Review Findings
  <!-- Reviewer appends one line per review: [YYYY-MM-DD] ARTIFACT_TYPE → VERDICT | key issue -->

  ## Deviations from Plan
  <!-- Implementer documents intentional deviations and reasons -->

  ## Open Questions
  <!-- Any agent adds questions for orchestrator or arbiter -->

- Do not implement the plan.
- After saving, report the plan path and recommended execution mode.
```

- [ ] **Step 7: adr.md を作成する（新規）**

ファイル: `dotfiles/.config/opencode/commands/adr.md`

```md
---
description: Write or update an ADR
agent: orchestrator
---

Write or update an ADR for the following decision:
$ARGUMENTS

Rules:
- Use existing ADR format if present in the repo.
- Include: status, context, decision, alternatives considered, consequences, reversibility, review conditions.
- Do not edit source code.
- After saving, request `/review-adr` for the new file.
```

- [ ] **Step 8: 作成されたファイルを確認する**

```bash
ls /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/
```

期待値: `feature.md`, `quick-fix.md`, `review-plan.md`, `review-impl.md`, `review-adr.md`, `review-docs.md`, `explore.md`, `plan.md`, `adr.md` の9ファイル

- [ ] **Step 9: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .config/opencode/commands/
git commit -m "feat(opencode): ARTIFACT_TYPE 別 review コマンドと /explore /plan /adr を追加"
```

---

### Task 8: 共有 AGENTS.md の "OpenCode Balanced Workflow" セクションを更新する

**改善点 #9 を反映。** 新規ファイルは作成しない。`~/.config/opencode/AGENTS.md` はすでに `dotfiles/.agents/AGENTS.md` へのシンボリックリンクが存在する。この共有ファイルの "OpenCode Balanced Workflow" セクションを拡充し、ルーティング方針・plan as source of truth・arbiter 呼び出し条件を追記する。

実装詳細（failure_signature のフォーマット、living-plan のセクション名）は agent prompt に書いているため、ここには書かない。

**Files:**
- Modify: `dotfiles/.agents/AGENTS.md`

- [ ] **Step 1: 現在のシンボリックリンクを確認する**

```bash
ls -la ~/.config/opencode/AGENTS.md
```

期待値: `AGENTS.md -> /Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md`

- [ ] **Step 2: 現在の "OpenCode Balanced Workflow" セクションを確認する**

```bash
grep -n "OpenCode Balanced Workflow" /Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md
```

- [ ] **Step 3: "OpenCode Balanced Workflow" セクションを以下の内容で置き換える**

現在のセクション（4行）を以下の拡充版に置き換える：

```md
## OpenCode Balanced Workflow

OpenCode の通常入口は `orchestrator` を使う。

**ルーティング方針:**
- typo・1行修正・README 小修正 → `@implementer` 直行
- どこを触るか不明 → `@explorer` で調査してから判断
- 中規模以上の機能 → `@orchestrator` 経由で探索・計画・実装・レビューを調整
- plan / ADR / README / docs の作成 → `@orchestrator`（writing-plans スキルを活用）
- 意味のある成果物のレビュー → `@reviewer`（`/review-plan`, `/review-impl`, `/review-adr`, `/review-docs` を使って ARTIFACT_TYPE を指定）
- `@implementer` が同じ失敗を2回繰り返した → `@arbiter` に相談

**Plan as source of truth:**
- plan ファイルが存在する場合、plan ファイルを実装・レビューの基準にする。
- chat 履歴だけに依存しない。
- plan には実装ログ・レビュー所見・逸脱記録・未解決事項のセクションを設けて状態を引き継ぐ。

**`@arbiter` の使用条件:**
- `@implementer` が同種の失敗を2回繰り返した
- `@reviewer` が ESCALATE を返した
- 設計判断が割れた
- API 境界・state schema・IAM・データモデル・セキュリティに影響する変更

**`@arbiter` は常用しない。** 同じ問題で2回相談しても解決しない場合は、人間にエスカレートする。
```

- [ ] **Step 4: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .agents/AGENTS.md
git commit -m "feat(agents): OpenCode Balanced Workflow セクションを拡充"
```

---

### Task 9: 全体検証を行う

設計全体の整合性を最終確認する。

- [ ] **Step 1: opencode.json の変更箇所を確認する**

```bash
grep -A6 '"edit"' /Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json | head -15
grep -A4 '"task"' /Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json | grep -A3 '"arbiter"'
```

期待値:
- orchestrator の edit が `{ "*": "deny", "docs/**": "allow", ... }` になっている
- reviewer の task に `"arbiter": "ask"` が含まれている

- [ ] **Step 2: prompts と commands のファイル存在確認**

```bash
ls /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/
ls /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/
```

期待値:
- prompts/: orchestrator.md, implementer.md, explorer.md, reviewer.md, arbiter.md（5ファイル）
- commands/: feature.md, quick-fix.md, review-plan.md, review-impl.md, review-adr.md, review-docs.md, explore.md, plan.md, adr.md（9ファイル）

- [ ] **Step 3: AGENTS.md のシンボリックリンクと内容を確認する**

```bash
ls -la ~/.config/opencode/AGENTS.md
grep -A5 "OpenCode Balanced Workflow" /Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md | head -10
```

期待値:
- `~/.config/opencode/AGENTS.md` → `dotfiles/.agents/AGENTS.md` のシンボリックリンク
- "ルーティング方針" の文字が含まれている（拡充されている）

- [ ] **Step 4: doc-planner への依存がないことを確認する**

```bash
grep -rn "doc-planner" /Users/haru256/Documents/projects/dotfiles/.config/opencode/
```

期待値: 出力なし

- [ ] **Step 5: 全コミットの確認**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git log --oneline main..HEAD
```

期待値: 各タスクごとに1コミット（合計8コミット前後）

- [ ] **Step 6: 動作確認（手動）**

ユーザーに以下を依頼：
- OpenCode を起動し `/explore` で軽い調査を依頼（例: "What does scripts/git-aicommit do?"）
- explorer が Summary Report + Exploration Log の構造で返答することを確認
- これは subagent では検証できないため人間の手動確認に委ねる

---

## 改善点と Task の対応表

| 改善点                                       | Tasks   |
| ----------------------------------------- | ------- |
| #1 orchestrator に docs 権限付与             | 1, 2, 7 |
| #2 reviewer ARTIFACT_TYPE 分岐              | 4, 7    |
| #3 critical thinking elicitation          | 4       |
| #4 plan を living document 化（prompt 埋め込み方式） | 2, 7    |
| #5 failure_signature による自動エスカレーション      | 2, 3, 6 |
| #6 implementer の停止条件                      | 3       |
| #7 explorer 探索深度と report 長分離              | 5, 7    |
| #9 共有 AGENTS.md の OpenCode ルール拡充        | 8       |
| #10 reviewer から arbiter を呼べる             | 1, 6    |
| minor: /explore コマンド                      | 7       |
| minor: explorer/reviewer は subagent（変更不要・確認済み） | -       |

(改善点 #8 explorer model tier 化は今回対象外。)

---

## 注意事項

- すべての変更は dotfiles リポジトリ側で行う。`~/.config/opencode/` 配下はシンボリックリンクなので、編集時は dotfiles のパスを使う。
- `~/.config/opencode/AGENTS.md` はすでに `dotfiles/.agents/AGENTS.md` へのシンボリックリンクが存在する。新規作成不要。
- living-plan のセクション構造はテンプレートファイルではなく orchestrator prompt と `/plan` コマンドに埋め込む。
- prompt 全面書き換えのため、変更前の内容は `git log` から復元できる前提で進める。
- Task 9 Step 6 の動作確認は人間の手動確認に依存する。
