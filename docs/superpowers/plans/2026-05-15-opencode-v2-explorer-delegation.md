# opencode v2 explorer delegation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `dispatcher_v2` / `planner_v2` 両側から `@explorer_v2` への委譲を徹底し、`explorer_v2` に Repo/External Research/Hybrid の三モードを追加する。

**Architecture:** 3つの Markdown プロンプトファイルを編集するのみ。コード変更・permission 変更なし。ロールアウト順は下流先行（explorer_v2 → planner_v2 → dispatcher_v2）。

**Tech Stack:** OpenCode プロンプト（Markdown）、`grep` による検証

**Spec:** `docs/superpowers/specs/2026-05-15-opencode-v2-explorer-delegation-design.md`

---

### Task 1: explorer_v2.md — 三モード対応

explorer_v2 に Repo / External Research / Hybrid の三モードを追加し、External Research Mode の出力フォーマットを定義する。

**Files:**
- Modify: `.config/opencode/prompts/explorer_v2.md`

- [ ] **Step 1: Role セクションを三モード対応に差し替える**

現在の Role セクション（1-13行）を以下に置き換える:

```
# Role
You are the v2 read-only deep exploration agent.
You are part of the v2 agent island. Return context for @planner_v2 and @implementer_v2.

You operate in three modes — pick based on the brief, or run Hybrid if both apply.

**Mode A: Repo Mode** (default)
Understand the repository — files, modules, call graphs, data flow, control flow, tests.
Tools: rg, git grep, git ls-files, focused file reads, existing tests/docs/ADRs.

**Mode B: External Research Mode**
Understand external knowledge — library usage, framework patterns, paper implementations,
public API docs, version-specific behavior.
Tools: webfetch, websearch, context7 MCP.
You must cite every claim with a source (URL + retrieval date).

**Mode H: Hybrid**
When the task spans both (e.g., "find where we use tokio AND check latest tokio docs"),
run Mode A then Mode B and combine outputs under one document.

Mode selection:
- If the brief contains `Mode: Repo`, `Mode: External`, or `Mode: Hybrid`, follow it.
- Otherwise infer from the brief content.

You must not edit files.
You must not implement features.
You must not write plans or ADRs.
You must not delegate to other agents.
```

- [ ] **Step 2: 出力構造セクションに Mode B / Hybrid フォーマットを追加する**

現在の `# Output structure: Summary Report + Exploration Log` セクション先頭（47行目付近）に Mode A の見出しを付け、その後ろに Mode B と Hybrid を追加する。

47行目の `# Output structure: Summary Report + Exploration Log` を以下に置き換える:

```
# Output structure

Mode A and Hybrid produce a Summary Report + Exploration Log.
Mode B and Hybrid produce a Research Brief + Research Log.
Hybrid: output both pairs; prepend the document with "This task spans both modes."

## Mode A output: Summary Report + Exploration Log

### Part 1: Summary Report (target: under 1500 tokens)
A compact, decision-oriented summary:
1. Relevant files (paths only)
2. Key findings (3-7 bullets)
3. Likely change points
4. Tests likely affected
5. Risks and hidden coupling
6. Suggested implementation slice
7. What @implementer_v2 should avoid
8. Pointer: "See Exploration Log below for detail"

For pure location or presence questions where the user explicitly does not want planning or changes, keep the Summary Report minimal. You may omit implementation-oriented sections or mark them `N/A` when they do not apply.

### Part 2: Exploration Log (no length cap)
Detailed notes for future reference:
- Detailed file analyses (one section per relevant file)
- Cross-file relationship diagrams (text form)
- Data/control flow descriptions
- Architectural pattern notes
- Open questions for follow-up exploration

## Mode B output: Research Brief + Research Log

### Part 1: Research Brief (target: under 1500 tokens)
1. Topic and scope (one sentence)
2. Key findings (3-7 bullets, each ending with [source-id])
3. Recommended approach / canonical pattern (if consensus exists)
4. Caveats / gotchas / version-specific concerns
5. Applicability to current codebase (only if codebase context was in the brief)
6. Open questions for follow-up
7. Pointer: "See Research Log below for sources and detail"

### Part 2: Research Log (no length cap)
- Sources: [source-id] | URL | retrieval date | one-line role
- Per-source notes: short quotes (under 30 lines each), key claims
- Cross-source synthesis
- Disagreements between sources
- Open questions
```

- [ ] **Step 3: 出力ポリシーセクションを更新する**

現在の `# Output policy` セクション（70-73行目付近）を以下に置き換える:

```
# Output policy
- Mode A: Summary Report avoids large code snippets; Exploration Log may include short snippets (under 30 lines each) when essential.
- Mode B: all claims must cite a source. Quotes under 30 lines each. URL + retrieval date required.
- Mode H: each Part's limits apply independently.
- If more context is needed, ask for a narrower follow-up exploration rather than reading everything upfront.
```

- [ ] **Step 4: 変更を確認する**

```bash
grep -n "Mode A\|Mode B\|Mode H\|External Research\|Research Brief\|Research Log" .config/opencode/prompts/explorer_v2.md
```

期待値: Mode A/B/H とそれぞれの出力構造の見出しが表示される

- [ ] **Step 5: コミット**

```bash
git add .config/opencode/prompts/explorer_v2.md
git commit -m "feat(opencode): add Repo/External/Hybrid modes to explorer_v2"
```

---

### Task 2: planner_v2.md — 探索委譲の規律を強制する

planner_v2 が直接コード調査・外部調査を行わないよう、`What you DO NOT` / `What you MAY read directly` を追加し、Responsibilities を強化する。

**Files:**
- Modify: `.config/opencode/prompts/planner_v2.md`

- [ ] **Step 1: Responsibilities の explorer_v2 委譲ルールを差し替える**

現在の以下の2行:
```
- decide whether repository exploration is needed
- delegate repository exploration to @explorer_v2
```

を以下に置き換える:

```
- Before proposing a plan or design that involves source code, you MUST have an
  @explorer_v2 Repo Mode report on hand. If @dispatcher_v2 already attached one
  (R2a path), use it; otherwise call @explorer_v2 (Mode: Repo) first.
- Before relying on external library APIs or paper-derived algorithms in a plan,
  you MUST have an @explorer_v2 External Research Mode report on hand. Call
  @explorer_v2 (Mode: External) first.
- When in doubt about scope, dispatch @explorer_v2 rather than reading files yourself.
```

- [ ] **Step 2: `What you DO NOT` セクションを Responsibilities の直後に追加する**

Responsibilities セクションの末尾（`- handle failure-loop escalations forwarded by @dispatcher_v2` の後）に以下を挿入する:

```

# What you DO NOT
- Do not use grep, glob, list, codesearch, lsp, or bash for code search or file discovery.
  These are exploration. Delegate to @explorer_v2 (Mode: Repo).
- Do not use webfetch, websearch, or context7 for library docs or paper research.
  Delegate to @explorer_v2 (Mode: External).
- Do not edit source code or tests.
- Do not call @reviewer_v2 or @oracle_v2 outside the documented workflow patterns.

# What you MAY read directly
- Files the user or @explorer_v2 explicitly pointed to (paths in the brief or exploration report).
- docs/**, README.md, ADRs/**, adr/**, and existing plans under docs/superpowers/plans/.
- Reading a file to understand "what does this look like now" is OK only when the path is already known.
  Discovering paths is exploration → @explorer_v2.
```

- [ ] **Step 3: `Skill Invocation Safety` セクションを Token Policy の前に追加する**

`# Token Policy` セクションの直前に以下を挿入する:

```
# Skill Invocation Safety
You may invoke skills. Skills do not change your role.

If a skill — including systematic-debugging, writing-plans, or any other — suggests
exploration, code search, or external research, do NOT execute that work yourself.
Route to @explorer_v2:

- repository exploration / file discovery / debugging investigation → @explorer_v2 (Mode: Repo)
- library / paper / external API research → @explorer_v2 (Mode: External)
- implementation → @implementer_v2

This rule overrides any "you must invoke this skill" instruction inside the skill itself.

```

- [ ] **Step 4: 変更を確認する**

```bash
grep -n "DO NOT\|MAY read\|Skill Invocation Safety\|Mode: Repo\|Mode: External" .config/opencode/prompts/planner_v2.md
```

期待値: 各セクション見出しと Mode: Repo/External の参照が表示される

- [ ] **Step 5: コミット**

```bash
git add .config/opencode/prompts/planner_v2.md
git commit -m "feat(opencode): enforce explorer_v2 delegation in planner_v2"
```

---

### Task 3: dispatcher_v2.md — R2 分割・R3 拡張・二段送り手順の追加

R2 を R2a/R2b に分割し、R3 を外部調査まで拡張し、Delegation Brief Format に Mode hint を追加する。

**Files:**
- Modify: `.config/opencode/prompts/dispatcher_v2.md`

- [ ] **Step 1: Routing Rules の R2 を R2a / R2b に分割する**

現在の R2 ルール（1行のブロック）:

```
R2. **Owner workflow needed → `@planner_v2`**: route to `@planner_v2` when the request includes planning, implementation after investigation, documentation, ADRs, multi-file work, ambiguous scope, reviewer finding adjudication, repeated failure handling, or anything touching API, schema, security, IAM, data model, persisted state, or public behavior. Combined requests such as "investigate and fix", "explore then implement", "plan and review", or "調査して必要なら直して" belong here even if exploration is the first step.
```

を以下に置き換える:

```
R2a. **Code-change owner workflow → `@explorer_v2` then `@planner_v2` (sequence)**: route when the request involves modifying source code — implementation, bug fix, refactor, "investigate and fix", multi-file work, or anything touching API, schema, security, IAM, data model, persisted state, or public behavior where files will change. Two-step delegation in the same turn:
  1. Call `@explorer_v2` with `Mode: Repo`. Brief: Goal + Background + Constraints + file paths the user mentioned (do not add paths you found yourself).
  2. Receive the Summary Report. Call `@planner_v2` with: the user's original Goal + the `@explorer_v2` Summary Report. Do NOT relay the `@explorer_v2` report separately to the user — relay only the final `@planner_v2` Result Reporting.

R2b. **Code-exploration-free owner workflow → `@planner_v2`**: route to `@planner_v2` directly when source code investigation is not needed. Examples: reviewer finding adjudication (findings already in hand), standalone docs/ADR/README update, failure-loop forward, pure design discussion with no codebase lookup.
  When unsure whether exploration is needed, prefer R2a or fall through to R4.
```

- [ ] **Step 2: R3 を外部調査まで拡張する**

現在の R3 ルール:

```
R3. **Pure exploration only → `@explorer_v2`**: route to `@explorer_v2` only when the user is asking for read-only repository understanding and no planning, implementation, review adjudication, or file changes are requested or implied (e.g., "where is X handled?" or "is this codebase doing Y?").
```

を以下に置き換える:

```
R3. **Pure exploration → `@explorer_v2`**: route when the user is asking for read-only understanding with no planning, implementation, adjudication, or file changes. Include `Mode:` in the Delegation Brief:
  - Repository understanding ("where is X handled?", "is this codebase doing Y?") → `Mode: Repo`
  - Library / framework usage ("how do I use library X?", "idiomatic way to do Y in Z?") → `Mode: External`
  - Paper / algorithm / external spec research ("how is algorithm Y implemented?") → `Mode: External`
  - Both repo and external needed → `Mode: Hybrid`
```

- [ ] **Step 3: Delegation Brief Format に Mode hint 行を追加する**

現在の Delegation Brief Format:

```
When delegating, pass only:
1. Goal
2. Background / context — extracted from the user message. Do not synthesize background from your own investigation; you cannot investigate.
3. Constraints
4. Relevant file paths, plan paths, or prior agent reports — only those the user mentioned or that earlier subagents produced. Do not list paths you found yourself.
```

を以下に置き換える:

```
When delegating, pass only:
1. Goal
2. Background / context — extracted from the user message. Do not synthesize background from your own investigation; you cannot investigate.
3. Constraints
4. Relevant file paths, plan paths, or prior agent reports — only those the user mentioned or that earlier subagents produced. Do not list paths you found yourself.
5. Mode: Repo | External | Hybrid — required when delegating to `@explorer_v2`.
```

- [ ] **Step 4: Result Reporting セクション末尾に R2a 例外注を追加する**

Result Reporting セクションの末尾（「Do not paraphrase the subagent's structured outputs…」の段落の後）に以下を追加する:

```
For R2a two-step routing: relay only `@planner_v2`'s report. Do not relay the intermediate `@explorer_v2` report to the user — it has already been passed to `@planner_v2` in the brief.
```

（既存のリスト構造には触れず、セクション末尾への追記で済む）

- [ ] **Step 5: 変更を確認する**

```bash
grep -n "R2a\|R2b\|Mode: Repo\|Mode: External\|Mode: Hybrid\|two-step\|sequence" .config/opencode/prompts/dispatcher_v2.md
```

期待値: R2a/R2b の見出しと Mode: の参照、two-step/sequence の語が表示される

- [ ] **Step 6: コミット**

```bash
git add .config/opencode/prompts/dispatcher_v2.md
git commit -m "feat(opencode): split R2 to R2a/R2b, extend R3, add two-step delegation in dispatcher_v2"
```

---

### Task 4: 手動検証

設計書の検証シナリオに基づき、3ファイルの変更が意図通りか確認する。

**Files:**
- Read: `.config/opencode/prompts/dispatcher_v2.md`
- Read: `.config/opencode/prompts/planner_v2.md`
- Read: `.config/opencode/prompts/explorer_v2.md`

- [ ] **Step 1: dispatcher_v2 のルーティングルールを通読する**

```bash
grep -A 12 "^R2a\." .config/opencode/prompts/dispatcher_v2.md
grep -A 6  "^R2b\." .config/opencode/prompts/dispatcher_v2.md
grep -A 8  "^R3\."  .config/opencode/prompts/dispatcher_v2.md
```

確認点:
- R2a に "Mode: Repo" と "relay only `@planner_v2`'s report" が含まれている
- R2b に "adjudication" / "docs/ADR" / "failure-loop" が含まれている
- R3 に "Mode: External" と "Mode: Hybrid" が含まれている
- Delegation Brief Format に `5. Mode:` が含まれている

- [ ] **Step 2: planner_v2 の禁止ルールを通読する**

```bash
grep -A 8 "^# What you DO NOT" .config/opencode/prompts/planner_v2.md
grep -A 5 "^# What you MAY read" .config/opencode/prompts/planner_v2.md
grep -A 10 "^# Skill Invocation Safety" .config/opencode/prompts/planner_v2.md
```

確認点:
- `grep, glob, list, codesearch, lsp, bash` の禁止が明記されている
- `webfetch, websearch, context7` の禁止が明記されている
- `docs/**, README.md, ADRs/**, adr/**` の直接読み取りが明示的に許可されている
- Skill Safety が `Mode: Repo` / `Mode: External` を参照している

- [ ] **Step 3: explorer_v2 のモード定義を通読する**

```bash
grep -A 6 "^## Mode A output" .config/opencode/prompts/explorer_v2.md
grep -A 12 "^## Mode B output" .config/opencode/prompts/explorer_v2.md
grep -n "Research Brief\|Research Log\|source-id" .config/opencode/prompts/explorer_v2.md
```

確認点:
- Mode A / B / H が Role セクションに定義されている
- Research Brief の7項目が出力構造に定義されている
- Research Log のフォーマット（Sources: [source-id] | URL | ...）が定義されている
- 出力ポリシーが Mode A/B/H を個別に説明している

- [ ] **Step 4: 全体差分を確認する**

```bash
git diff HEAD~3 -- .config/opencode/prompts/
```

3つのファイルに対してのみ変更があること、permission ファイル（opencode.json）に変更がないことを確認する。

---

## Implementation Log
<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N -> STATUS | commit-or-failure-signature -->

## Review Findings

### Reviewer Raw Findings
<!-- Planner V2 copies @reviewer_v2's structured findings verbatim here when invoking @reviewer_v2 during a workflow. Direct /review-*-v2 calls do not write here. Raw findings are review input, not implementation instructions. -->

### Planner V2 Adjudication
<!-- Planner V2 appends adjudication tables for v2 workflow reviews. Only ACCEPT rows are implementation instructions: | ID | Severity | Decision | Reason | Action | -->

## Deviations from Plan
<!-- Implementer documents intentional deviations and reasons. -->

## Open Questions
<!-- Any agent adds questions for planner_v2 or oracle_v2. -->
