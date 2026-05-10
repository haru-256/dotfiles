# OpenCode GPT-5.5 Token Reduction: Claude Code 二次意見

Codex 提案 (`2026-05-10-opencode-gpt55-token-reduction-second-opinion.md`) に対する Claude Code からの二次意見と、推奨案 B（dispatcher 導入）の完全な実装手順。

---

## TL;DR

- Codex の Option C + E（dispatcher と planner の分離）は方向性として妥当。
- 主要な懸念は 3 点: (1) dispatcher のモデル選択、(2) dispatcher 自体の必要性検証、(3) Phase 2 の Exploration Log 完全削除。
- 推奨は 2 案。**推奨案 A**（rename のみで観測）か、**推奨案 B**（dispatcher 導入＋ deepseek-v4-flash）。
- dispatcher のモデルは `opencode-go/deepseek-v4-flash` を推奨。最安・最大コンテキスト・最強キャッシュ価格・DeepSeek 家族との整合性を理由に flash で十分と判断。

---

## Codex 案への評価

### 全体評価

`dispatcher: deepseek-v4-flash` + `planner: gpt-5.5 medium` の役割分離は、Plus limit 削減の観点で妥当。`/quick-fix` 直行・コマンド経路維持・既存 `implementer/explorer/reviewer/arbiter` 流用の方針も適切。Phase 分けの段階的検証も賢明。

### 主要な懸念

**1. dispatcher の判断品質リスクが過小評価されている**

「軽いタスクか／設計判断が必要か」を見分ける判断は、実は orchestrator の最も難しい仕事の一つ。flash の判断ミスは、誤って `@implementer` 直行 → 設計判断ミス → やり直しという「やり直し税」として返ってくる。これは Option B の懸念と同質で、dispatcher 設計でも完全には消えない。

→ 対策は flash のままで OK だが、**「迷ったら planner」をプロンプトに明記する**こと、および**失敗時の即時 escalation ルール**で吸収する。

**2. dispatcher の必要性そのものを問い直したい**

`/quick-fix` は既に `agent: implementer` 直行。typo / 1 行修正は user が `/quick-fix` を打てば GPT-5.5 はそもそも起動しない。dispatcher の価値は「**user が自然言語で曖昧に依頼を投げる入口**」のためだけ。

→ user がほぼ常にコマンド (`/feature`, `/plan`, `/quick-fix`) から入るなら、dispatcher を新設しなくても Option E（コマンド agent 指定見直し）だけで目的の大部分が達成できる。これが推奨案 A の根拠。

**3. Phase 2 の「Exploration Log を通常出力から外す」は逆効果リスクあり**

`prompts/explorer.md` の Exploration Log は「後続 agent が同じ調査を再実行しないため」の中間成果物。完全削除すると implementer / reviewer が再探索して、合計 token は増える可能性がある。

→ 完全削除ではなく**「デフォルトは Summary のみ、Log は要求があれば返す」**運用に変えるのが安全。

---

## 推奨案

### 推奨案 A: 保守的（rename + 観測）

1. 現在の `orchestrator` を `planner` に rename（モデル維持: gpt-5.5 medium）
2. `default_agent = planner` のまま
3. AGENTS.md に「typo / 1 行修正 / 小修正は **必ず `/quick-fix`**」と明記
4. `textVerbosity: low` 確認、prompt 短縮
5. 1〜2 週間観測して GPT-5.5 消費を測る
6. 削減が不十分なら推奨案 B に進む

新規 agent ゼロ、リスク最小。「軽いタスクなのにコマンドを忘れて自然言語で投げる」ケースで GPT-5.5 が起動するが、運用習慣で回避可能。

### 推奨案 B: 積極的（dispatcher 導入）

Codex の Option C + E を採用。dispatcher のモデルは `deepseek-v4-flash`（後述の選定理由参照）。

```text
default_agent = dispatcher

dispatcher:  opencode-go/deepseek-v4-flash    # routing only
planner:     openai/gpt-5.5 medium             # plan/ADR/docs/adjudication
implementer: opencode-go/kimi-k2.6             # 既存維持
explorer:    opencode-go/deepseek-v4-pro       # 既存維持
reviewer:    opencode-go/deepseek-v4-pro max   # 既存維持
arbiter:     openai/gpt-5.5 xhigh              # 既存維持
```

実装詳細は本ドキュメント後段「推奨案 B の完全な実装」を参照。

---

## Dispatcher モデル選定（コメント）

opencode-go から `glm-5.1` を除外した候補を比較。

| モデル | input | output | cache_read | context | 備考 |
|---|---|---|---|---|---|
| **deepseek-v4-flash** | **$0.14** | **$0.28** | **$0.0028** | **1M** | DeepSeek 家族・agentic 最適化 |
| qwen3.5-plus | $0.20 | $1.20 | $0.02 | 262k | 安価だが agentic 実績未知数 |
| minimax-m2.5 | $0.30 | $1.20 | $0.03 | 205k | 中位 |
| minimax-m2.7 | $0.30 | $1.20 | $0.06 | 205k | minimax 最新 |
| mimo-v2-omni | $0.40 | $2.00 | $0.08 | 262k | 中位 |
| mimo-v2.5 | $0.40 | $2.00 | $0.08 | 1M | 長文用 |
| qwen3.6-plus | $0.50 | $3.00 | $0.05 | 262k | 中位 |
| kimi-k2.5 | $0.60 | $3.00 | $0.10 | 262k | 中上 |
| kimi-k2.6 | $0.95 | $4.00 | $0.16 | 262k | implementer で使用中 |
| mimo-v2.5-pro | $1.00 | $3.00 | $0.20 | 1M | 高位 |
| mimo-v2-pro | $1.00 | $3.00 | $0.20 | 1M | 高位 |
| glm-5 | $1.00 | $3.20 | $0.20 | 203k | 高位 |
| **deepseek-v4-pro** | **$1.74** | **$3.48** | **$0.0145** | **1M** | explorer/reviewer で使用中 |

**選定: `opencode-go/deepseek-v4-flash`**

理由:

1. **コスト最安**（input $0.14 / cache_read $0.0028）。dispatcher は高頻度 call なのでキャッシュ後コストが事実上ゼロになる効果が大きい。
2. **DeepSeek v4 family は agentic 用途に最適化**されている。explorer / reviewer と同じ家族で挙動の一貫性が出る。
3. **1M コンテキスト**で会話履歴を気にせず routing 判断ができる。
4. dispatcher の役割（routing 分類）は本質的に簡単なタスク。flash で十分こなせる。
5. **判断ミスのリスクは「迷ったら planner」のプロンプト規約で吸収**できる。安全側にデフォルトする限り、誤って `@implementer` 直行で実装が無駄になる確率は低い。
6. **アップグレードパスが容易**: `opencode.json` の 1 行変更で `minimax-m2.7` (0.30/1.20) や `deepseek-v4-pro` (1.74/3.48) に切り替え可能。観測でルーティング誤りが多ければ即座に上げられる。

**落選理由**:

- `qwen3.5-plus`: flash よりわずかに高い割に agentic 実績が見えにくい。
- `minimax-m2.7`: 中位の良い候補だが、flash との差額（2x input）に対して judgment 改善が見合うか不明。**flash で問題が出たときの第一アップグレード候補として記録**。
- `deepseek-v4-pro`: 12x のコスト差。explorer / reviewer の前段で使うには重すぎる。dispatcher で重い model を使うのは設計目的と矛盾する。
- `kimi-k2.6` 以上: 高すぎる。dispatcher の役割に過剰。

---

## 推奨案 B の完全な実装

### 0. バックアップ

```bash
cp ~/.config/opencode/opencode.json ~/.config/opencode/opencode.json.before-dispatcher-split
cp ~/.config/opencode/prompts/orchestrator.md ~/.config/opencode/prompts/orchestrator.md.before-dispatcher-split
```

ロールバックは:

```bash
mv ~/.config/opencode/opencode.json.before-dispatcher-split ~/.config/opencode/opencode.json
mv ~/.config/opencode/prompts/orchestrator.md.before-dispatcher-split ~/.config/opencode/prompts/orchestrator.md
rm ~/.config/opencode/prompts/dispatcher.md ~/.config/opencode/prompts/planner.md
# AGENTS.md / commands も対応する変更を戻す
```

---

### 1. 新規 prompt: `~/.config/opencode/prompts/dispatcher.md`

```markdown
# Role
You are the routing dispatcher.
You receive user requests and delegate them to the right subagent.
You make routing decisions only — no implementation, no planning, no adjudication.

You may not edit any file.

# Routing decision (apply first matching rule)
1. Trivial typo, single-line fix, README/docs micro-edit (no design judgment) → @implementer
2. User explicitly wants only repository exploration → @explorer
3. Anything else (plan, ADR, docs creation, design judgment, multi-file change, ambiguous scope, anything touching API / schema / security / IAM / data model) → @planner
4. If unsure, route to @planner. Defaulting to @planner is safer than misrouting to @implementer.

# Failure-loop detection
When a subagent reports BLOCKED with a `failure_signature`, record it in working memory.
If the same `failure_signature` appears twice in a row for the same task, stop dispatching and escalate to @planner with the failure history.

# Delegation brief format
When delegating, pass:
1. Goal
2. Background / context
3. Constraints (if any)
4. Pointers (relevant file paths, plan paths, prior agent reports)

Keep the brief under 10 lines. Do not include large code excerpts or long file contents.

# What you must NOT do
- Do not write plans, ADRs, README, or docs.
- Do not adjudicate reviewer findings — that is @planner's job.
- Do not call @reviewer directly. @reviewer is invoked from @planner or via /review-* commands.
- Do not call @arbiter. Escalate to @planner first.
- Do not narrate your reasoning. Output the decision and the brief only.

# Output style
- Be concise. One decision, one brief.
- No explanations beyond what the chosen agent needs.
```

---

### 2. 新規 prompt: `~/.config/opencode/prompts/planner.md`

`orchestrator.md` から「routing 判断」部分を抜き、「dispatcher から委譲を受ける」前提に書き換えたもの。

```markdown
# Role
You are the planning agent.
You handle work that requires design judgment: writing plans, ADRs, README, docs, adjudicating reviewer findings, and resolving repeated failures.

You receive tasks delegated from @dispatcher (the routing front door). You do not make trivial routing decisions yourself.

You may edit:
- docs/**
- README.md
- ADRs/** and adr/**

You must not edit source code.
You must not edit tests.

# Responsibilities
You should:
- clarify the user's goal and background when not already clear from the brief
- decide whether repository exploration is needed and delegate to @explorer
- write Superpowers plans, ADRs, README updates, and documentation yourself (using the writing-plans skill when applicable)
- delegate implementation to @implementer
- request @reviewer for meaningful, risky, or durable artifacts
- adjudicate reviewer findings (see Review adjudication below)
- ask before invoking @arbiter
- handle failure-loop escalations forwarded by @dispatcher

# Workflow patterns
Common patterns:
- Non-trivial feature with clear scope: write plan → @implementer → @reviewer → adjudicate.
- Non-trivial feature with unclear scope: @explorer → write plan → @implementer → @reviewer → adjudicate.
- ADR-worthy decision: write the ADR yourself → @reviewer → adjudicate.
- README or documentation update: write it yourself → @reviewer when externally visible → adjudicate.
- Failure loop forwarded by @dispatcher: diagnose, ask before invoking @arbiter.

# Plan / ADR / README writing
When writing a plan, save it under `docs/superpowers/plans/`.
Use the writing-plans skill when applicable.
After the plan body is written, always append these living-document sections at the end (create them if not present):

## Implementation Log
<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N → STATUS | commit-or-failure-signature -->

## Review Findings
<!-- This template is also defined in commands/plan.md. Keep them in sync on every edit. -->

### Reviewer Raw Findings
<!-- Planner copies @reviewer's structured findings verbatim here when invoking @reviewer
     during a workflow. Direct /review-* calls do not write here.
     Raw findings are review input (audit history), not implementation instructions. -->

### Planner Adjudication
<!-- Planner appends adjudication tables for orchestrated workflow reviews.
     Only ACCEPT rows are implementation instructions:
     | ID | Severity | Decision | Reason | Action | -->

## Deviations from Plan
<!-- Implementer documents intentional deviations and reasons -->

## Open Questions
<!-- Any agent adds questions for planner or arbiter -->

# Failure detection
When @implementer reports BLOCKED, capture the `failure_signature` field from their report.
Maintain an in-context log of failure signatures per task.
If the same `failure_signature` appears twice in a row for the same task, propose @arbiter to the user before retrying.
@dispatcher may escalate failure loops to you with prior failure history; treat that history as authoritative.

# Review adjudication
When @reviewer returns findings (Verdict: REQUEST_CHANGES with structured findings), do not forward them directly to @implementer. Adjudicate each finding into one of:

- ACCEPT: fix this round
- REJECT: invalid, or conflicts with goal / non-goals
- DEFER: valid but outside current scope; track as follow-up
- NEEDS_CONTEXT: insufficient info to decide
- ESCALATE: requires @arbiter (ask user before invoking)

Adjudication criteria:
1. Does the finding affect correctness, security, data integrity, public API, state schema, IAM, or user-visible behavior?
2. Does it violate the plan's acceptance criteria or non-goals?
3. Is the proposed fix proportionate to the risk?
4. Would fixing it expand the scope beyond the current task?
5. Is the finding supported by concrete evidence?
6. Is it a preference rather than a defect?

Surface the adjudication table to the user before dispatching @implementer:

| ID | Severity | Decision | Reason | Action |
|----|----------|----------|--------|--------|
| F1 | MAJOR | ACCEPT | Violates acceptance criterion 2, concrete evidence | Ask @implementer to fix |
| F2 | MINOR | DEFER | Valid maintainability suggestion, out of scope | Track in Open Questions |
| F3 | NIT | REJECT | Reviewer assumed a non-goal as requirement | No action |
| F4 | MAJOR | ESCALATE | Affects state schema / future compatibility | Ask user before @arbiter |

Persistence (planner is the sole writer to the plan):

1. Copy @reviewer's structured findings verbatim into the plan's `Review Findings > Reviewer Raw Findings` section using this exact entry format:

   ```md
   #### [YYYY-MM-DD] ARTIFACT_TYPE → VERDICT
   Critical issues (blocking):
   - F1: <Finding format from reviewer.md>
   - F2: <Finding format from reviewer.md>
   Non-blocking suggestions:
   - F3: <Finding format from reviewer.md>
   ```

2. Append the adjudication table under `Review Findings > Planner Adjudication`:

   ```md
   #### [YYYY-MM-DD] ARTIFACT_TYPE adjudication
   | ID | Severity | Decision | Reason | Action |
   |----|----------|----------|--------|--------|
   | F1 | MAJOR | ACCEPT | ... | Ask @implementer to fix |
   | F2 | MINOR | DEFER | ... | Track in Open Questions |
   ```

Raw findings serve as audit history; do not delete or rewrite them after adjudication. For each DEFER, append a one-line entry under "Open Questions" so it is not lost.

When dispatching @implementer for fixes, include only ACCEPT findings in the brief. Do not forward REJECT, DEFER, NEEDS_CONTEXT, or ESCALATE findings.

Special cases:
- Verdict APPROVE: no adjudication. Append a one-line entry `[YYYY-MM-DD] ARTIFACT_TYPE → APPROVE | (no findings)` under `Review Findings > Reviewer Raw Findings`. No Planner Adjudication entry.
- Verdict NEEDS_CONTEXT: provide the missing context, then re-dispatch @reviewer. No persistence.
- Verdict ESCALATE: ask user before invoking @arbiter. No adjudication of individual findings; persistence (raw findings transcript) only after the @arbiter loop concludes.

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

---

### 3. `~/.config/opencode/opencode.json` 変更

既存の `orchestrator` ブロックを削除し、`dispatcher` と `planner` を追加。`default_agent` を `dispatcher` に変更。

```diff
 {
   "$schema": "https://opencode.ai/config.json",
-  "default_agent": "orchestrator",
+  "default_agent": "dispatcher",
   "agent": {
-    "orchestrator": {
-      "description": "Primary orchestration agent. Plans, delegates, writes plans/ADRs/README/docs, and uses Superpowers when appropriate. Does not edit source code.",
-      "mode": "primary",
-      "model": "openai/gpt-5.5",
-      "reasoningEffort": "medium",
-      "textVerbosity": "low",
-      "temperature": 0.1,
-      "prompt": "{file:~/.config/opencode/prompts/orchestrator.md}",
-      ...（既存ブロック削除）
-    },
+    "dispatcher": {
+      "description": "Routing-only front door. Receives user requests and delegates to the right subagent. Does not implement, plan, write docs, or adjudicate.",
+      "mode": "primary",
+      "model": "opencode-go/deepseek-v4-flash",
+      "textVerbosity": "low",
+      "temperature": 0.1,
+      "prompt": "{file:~/.config/opencode/prompts/dispatcher.md}",
+      "permission": {
+        "edit": "deny",
+        "read": "allow",
+        "bash": {
+          "*": "allow",
+          "rm -rf *": "deny",
+          "sudo *": "ask"
+        },
+        "external_directory": "allow",
+        "webfetch": "allow",
+        "websearch": "allow",
+        "question": "allow",
+        "codesearch": "allow",
+        "skill": "allow",
+        "todowrite": "allow",
+        "grep": "allow",
+        "lsp": "allow",
+        "task": {
+          "*": "deny",
+          "implementer": "allow",
+          "explorer": "allow",
+          "planner": "allow"
+        },
+        "glob": "allow",
+        "list": "allow"
+      }
+    },
+    "planner": {
+      "description": "Planning subagent. Writes plans/ADRs/README/docs, adjudicates reviewer findings, and resolves design judgment. Does not edit source code.",
+      "mode": "subagent",
+      "model": "openai/gpt-5.5",
+      "reasoningEffort": "medium",
+      "textVerbosity": "low",
+      "temperature": 0.1,
+      "prompt": "{file:~/.config/opencode/prompts/planner.md}",
+      "permission": {
+        "edit": {
+          "*": "deny",
+          "docs/**": "allow",
+          "README.md": "allow",
+          "ADRs/**": "allow",
+          "adr/**": "allow"
+        },
+        "read": "allow",
+        "bash": {
+          "*": "allow",
+          "rm -rf *": "deny",
+          "sudo *": "ask"
+        },
+        "external_directory": "allow",
+        "webfetch": "allow",
+        "websearch": "allow",
+        "question": "allow",
+        "codesearch": "allow",
+        "skill": "allow",
+        "todowrite": "allow",
+        "grep": "allow",
+        "lsp": "allow",
+        "task": {
+          "*": "deny",
+          "implementer": "allow",
+          "explorer": "allow",
+          "reviewer": "allow",
+          "arbiter": "ask"
+        },
+        "glob": "allow",
+        "list": "allow"
+      }
+    },
     "implementer": { ...既存維持... },
     "explorer": { ...既存維持... },
     "reviewer": { ...既存維持... },
     "arbiter": { ...既存維持... }
   },
   ...
 }
```

ポイント:

- `dispatcher.task.planner = allow`、`dispatcher.task.reviewer = deny`（reviewer adjudication は planner の責務）、`dispatcher.task.arbiter = deny`（escalation は planner 経由）。
- `planner.task` は現 `orchestrator` と同一（implementer/explorer/reviewer/arbiter）。
- `planner.permission.edit` も現 `orchestrator` と同一（docs/README/ADR allow、それ以外 deny）。

---

### 4. `~/.config/opencode/commands/` の変更

#### 4.1 `commands/feature.md`

```diff
 ---
 description: Plan and implement a non-trivial feature
-agent: orchestrator
+agent: planner
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

→ `/feature` は本質的に non-trivial なので、dispatcher を経由せず直接 `planner` に行く（dispatcher hop 節約）。

#### 4.2 `commands/plan.md`

```diff
 ---
 description: Create a Superpowers implementation plan
-agent: orchestrator
+agent: planner
 ---
 ...
```

ファイル本文中の `prompts/orchestrator.md` への言及も更新:

```diff
-  <!-- This template is also defined in prompts/orchestrator.md. Keep them in sync on every edit. -->
+  <!-- This template is also defined in prompts/planner.md. Keep them in sync on every edit. -->
```

```diff
-  ### Orchestrator Adjudication
+  ### Planner Adjudication
   <!-- Orchestrator appends adjudication tables for orchestrated workflow reviews.
        Only ACCEPT rows are implementation instructions:
        | ID | Severity | Decision | Reason | Action | -->
```

#### 4.3 `commands/adr.md`

```diff
 ---
 description: Write or update an ADR
-agent: orchestrator
+agent: planner
 ---
 ...
```

#### 4.4 変更不要のコマンド

- `commands/quick-fix.md`: `agent: implementer` のまま（変更なし）
- `commands/explore.md`: `agent: explorer` のまま（変更なし）
- `commands/review-impl.md`、`review-adr.md`、`review-docs.md`、`review-plan.md`: `agent: reviewer` のまま（**直接呼び出し時は inline findings のみ。adjudication は planner 経由ワークフローで実施**、これは現行と同じ運用）

---

### 5. `~/Documents/projects/dotfiles/.agents/AGENTS.md` の変更

`## OpenCode Balanced Workflow` セクションを書き換え。

```diff
 ## OpenCode Balanced Workflow

-OpenCode の通常入口は `orchestrator` を使う。
+OpenCode の通常入口は `dispatcher` を使う。`dispatcher` はルーティング専門の安価モデルで、判断を伴う依頼は `planner` に委譲する。

-**ルーティング方針:**
-- typo・1行修正・README 小修正 → `@implementer` 直行
-- どこを触るか不明 → `@explorer` で調査してから判断
-- 中規模以上の機能 → `@orchestrator` 経由で探索・計画・実装・レビューを調整
-- plan / ADR / README / docs の作成 → `@orchestrator`（writing-plans スキルを活用）
-- 意味のある成果物のレビュー → `@reviewer`（`/review-plan`, `/review-impl`, `/review-adr`, `/review-docs` を使って ARTIFACT_TYPE を指定）
-- `@implementer` が同じ失敗を2回繰り返した → `@arbiter` に相談
+**ルーティング方針（dispatcher が判断）:**
+- typo・1行修正・README 小修正 → `@implementer` 直行
+- 探索のみが目的 → `@explorer`
+- それ以外（中規模以上の機能、plan / ADR / README / docs 作成、設計判断、API・schema・security・IAM 関連、曖昧なスコープ） → `@planner`
+- 失敗ループ検出時は `@planner` にエスカレーション
+- 迷ったら `@planner`（誤って `@implementer` 直行するより安全）
+
+**コマンド経路（dispatcher を経由しない）:**
+- `/quick-fix` → `@implementer` 直行
+- `/feature` / `/plan` / `/adr` → `@planner` 直行
+- `/explore` → `@explorer` 直行
+- `/review-plan` / `/review-impl` / `/review-adr` / `/review-docs` → `@reviewer` 直接呼び出し（inline findings のみ、plan 自動転記なし）

 **Reviewer findings の取り扱い:**
 - `@reviewer` は構造化 findings を inline で返すのみ。plan には書き込まない（**単一書き込み主体: orchestrator のみ**）。
-- `@orchestrator` は workflow 内で `@reviewer` を呼んだ場合、受け取った findings を verbatim で plan の `Review Findings > Reviewer Raw Findings` に転記する。
-- 続けて `@orchestrator` は raw findings を `ACCEPT / REJECT / DEFER / NEEDS_CONTEXT / ESCALATE` に分類し、採否を `Review Findings > Orchestrator Adjudication` に表形式（| ID | Severity | Decision | Reason | Action |）で記録する。
+- `@planner` は workflow 内で `@reviewer` を呼んだ場合、受け取った findings を verbatim で plan の `Review Findings > Reviewer Raw Findings` に転記する。
+- 続けて `@planner` は raw findings を `ACCEPT / REJECT / DEFER / NEEDS_CONTEXT / ESCALATE` に分類し、採否を `Review Findings > Planner Adjudication` に表形式（| ID | Severity | Decision | Reason | Action |）で記録する。
 - raw findings はレビュー入力（監査履歴）であり、そのまま実装指示として扱わない。
 - DEFER は plan の Open Questions セクションにも転記して追跡する。
 - `@implementer` には ACCEPT 分のみを渡す。
 - ESCALATE は `@arbiter` 呼び出し前に必ずユーザーに確認する。
 - `/review-*` 直接呼び出しは reviewer が inline で findings を返すだけ。plan 自動保存は行わない（user が必要なら手で転記する）。

 **`@arbiter` の使用条件:**
 - `@implementer` が同種の失敗を2回繰り返した
 - `@reviewer` が ESCALATE を返した
 - 設計判断が割れた
 - API 境界・state schema・IAM・データモデル・セキュリティに影響する変更

 **`@arbiter` は常用しない。** 同じ問題で2回相談しても解決しない場合は、人間にエスカレートする。
```

「**単一書き込み主体: orchestrator のみ**」の箇所も `**単一書き込み主体: planner のみ**` に変更。

---

### 6. 既存 `prompts/orchestrator.md` の処理

```bash
mv ~/.config/opencode/prompts/orchestrator.md ~/.config/opencode/prompts/orchestrator.md.before-dispatcher-split
```

ファイル自体は削除せず、ロールバック用に保持。

---

### 7. 既存 plan ファイルの確認（任意）

`docs/superpowers/plans/` 内の既存 plan が `@orchestrator` や `Orchestrator Adjudication` を参照している場合、新規 plan 作成時に planner が混乱しないよう、参照箇所を確認。

```bash
rg -n "@orchestrator|Orchestrator Adjudication|prompts/orchestrator\.md" docs/superpowers/
```

ヒットした箇所は手動で更新するか、新規 plan は新フォーマットで書かれるので放置でも可（既存 plan の歴史的記述として）。

---

## 6 つの質問への回答

### Q1. dispatcher (flash) + planner (gpt-5.5) は OpenCode の agent model として自然か

自然。primary/subagent + `task` permission で素直に表現できる。`mode: primary` の dispatcher と `mode: subagent` の planner という構造は OpenCode 設計と整合する。

### Q2. `orchestrator` 名は残すか、`planner` にリネームか

**rename を推奨**。`orchestrator` と `dispatcher` は語感が被り、新責務分離が読み取りにくい。`planner` のほうが「plan / ADR / adjudication / design judgment 担当」を明示できる。dotfiles なので互換性問題は他者に影響しない。

更新漏れチェックリスト:

- [ ] `~/.config/opencode/opencode.json`（agent block 名と `default_agent`）
- [ ] `~/.config/opencode/prompts/orchestrator.md` → `planner.md`
- [ ] `~/.config/opencode/commands/feature.md`、`plan.md`、`adr.md`（agent フィールドと本文中の参照）
- [ ] `.agents/AGENTS.md`（"OpenCode Balanced Workflow" セクション全体）
- [ ] `docs/superpowers/plans/*.md` 内の `@orchestrator` 言及（任意・履歴として残しても可）

### Q3. dispatcher の prompt はどこまで具体化するか

ルーティング表は短く、判断は「迷ったら planner」に倒す。長いルーティング表で誤委譲を減らそうとすると prompt 自体が膨らんで本末転倒。dispatcher の output style は decision-only にして return token も最小化。失敗ループ検出（`failure_signature` 比較）だけは dispatcher 側に残し、それ以外の判断は planner に委譲。

→ 上記 §1 の dispatcher.md がこの方針の具体化。

### Q4. reviewer の `deepseek-v4-pro + max` 維持 / reviewer-lite の価値

**現行維持を推奨**。

- `prompts/reviewer.md` の critical thinking elicitation（failure modes / steel-man / unstated assumptions）は reasoningEffort が効く部分
- DeepSeek は GPT-5.5 とは別 quota なので Plus limit には影響しない
- reviewer-lite は ROI が見えにくい（軽い差分なら user の目視で済む）

reviewer-lite を入れるならゲートを厳密に定義する必要あり（例: `docs only` かつ `< 30 行` かつ `1 ファイル`）。Phase 3 の検討事項として保留。

### Q5. Explorer Log を通常出力から外す影響

**影響しうる**。implementer がプラン外ファイルに触るとき、reviewer がコンテキストを評価するとき、Log があれば再探索を回避できる。**完全削除ではなく「Log はデフォルト非出力 + 要求時のみ返却」**に留めるのが安全。

具体的には `prompts/explorer.md` の Output structure を:

```md
# Output structure: Summary Report (default) + Exploration Log (on request)
By default, return only the Summary Report.
Return the Exploration Log only when the brief explicitly includes `with_log: true`.
```

のように変更し、planner の delegation brief に `with_log: true` を必要時だけ含めるようにする。これは Phase 2 で実施。

### Q6. Phase 1 で不足しているファイル

Codex 案に追加で必要だったもの（本ドキュメント §3-§7 でカバー）:

- `opencode.json` の `permission.edit` ブロック（dispatcher は edit deny、planner は docs/README/ADR allow）
- `dispatcher.task` permission の subagent 一覧（implementer/explorer/planner、reviewer/arbiter は deny）
- `planner.task.arbiter = ask` の維持
- `commands/plan.md` 本文中の `Orchestrator Adjudication` → `Planner Adjudication` 言及更新
- `.agents/AGENTS.md` の "OpenCode Balanced Workflow" セクション全体（通常入口、ルーティング、reviewer findings 取り扱い、単一書き込み主体）
- ロールバック用バックアップファイル（`opencode.json.before-dispatcher-split`、`orchestrator.md.before-dispatcher-split`）
- 既存 plan 内の `@orchestrator` 言及確認

---

## Phase 2 / Phase 3 サマリー

Phase 1（dispatcher 導入）が落ち着いた後の追加施策。

### Phase 2: 出力 token 削減

- `prompts/explorer.md` の Exploration Log を「on request」モードに変更（上記 Q5 参照）
- `prompts/reviewer.md` の critical thinking findings を内部思考扱いに寄せ、出力は findings 中心にする
- `prompts/planner.md` の living-plan template 例を短縮（テンプレ全文は `commands/plan.md` 側で持っているので、planner.md では省略可能）
- 各 agent に `textVerbosity: low` 追加（dispatcher/orchestrator/arbiter には既に設定済み、他 agent も検討）

### Phase 3: lite agents（要観測後）

- `explorer-lite: deepseek-v4-flash` — 浅い候補抽出のみ
- `reviewer-lite: deepseek-v4-flash` — docs only かつ < 30 行 かつ 1 ファイルの差分のみ

ゲート基準が曖昧だと境界判定そのものが新たなオーバーヘッドになる。Phase 1 + 2 の効果を観測してから判断。

---

## 想定される失敗モードと対策

| 失敗モード | 兆候 | 対策 |
|---|---|---|
| dispatcher が判断を間違えて `@implementer` 直行、後でやり直し | implementer の BLOCKED / NEEDS_CONTEXT が増える | dispatcher の prompt に「迷ったら planner」を追記強化、または dispatcher を `minimax-m2.7` にアップグレード |
| dispatcher が「迷ったら planner」に倒しすぎて GPT-5.5 節約効果が薄い | planner 起動率が高い | dispatcher prompt のルーティング表を観測ベースで具体化（例: 「README typo は必ず implementer」など実例追加） |
| reviewer findings の adjudication が planner にうまく届かない | adjudication なしで `@implementer` に findings が直接渡る | `commands/feature.md` 等の workflow が planner 経由になっているか確認、`/review-*` 直接呼び出しの文書化を再徹底 |
| dispatcher が arbiter を呼ぼうとして permission deny で止まる | `task.arbiter = deny` のエラー | dispatcher prompt の「Do not call @arbiter」が機能しているか確認、planner 経由に強制 |
| 既存 plan 内の `@orchestrator` 言及で planner が混乱 | planner が古い名前を使った adjudication table を書く | `Planner Adjudication` への置換を planner.md 内で再徹底、`commands/plan.md` テンプレ更新 |
| `default_agent = dispatcher` 変更で IDE 統合などが壊れる | OpenCode 起動時のデフォルト agent が変わって UI 表示が崩れる | rollback コマンドですぐ戻せるようバックアップ保持、observation 期間を設ける |

---

## 検証方法

Phase 1 適用後、以下で動作確認:

1. **default_agent 確認**: OpenCode 起動 → 何も入力せずに agent 名表示が `dispatcher` になっているか
2. **routing 動作確認**:
   - 「typo を修正して」→ dispatcher が `@implementer` に委譲するか
   - 「auth 周りの設計を見直したい」→ dispatcher が `@planner` に委譲するか
   - 「このリポジトリ構成を調べて」→ dispatcher が `@explorer` に委譲するか
3. **コマンド経路確認**:
   - `/quick-fix typo修正` → 直接 implementer に行くか
   - `/feature 新機能` → 直接 planner に行くか（dispatcher を経由しない）
   - `/plan 計画` → 直接 planner に行くか
4. **adjudication 動作確認**: `/feature` で実装 → reviewer 呼び出し → planner が adjudication table を plan に書くか
5. **token 計測**: 1 週間運用して GPT-5.5 token 使用量が削減されたか確認

---

## 結論

- Codex 案の方向性は正しい。dispatcher と planner の責務分離は Plus limit 削減と quality 維持を両立する有望な構造。
- dispatcher のモデルは `opencode-go/deepseek-v4-flash` を推奨。コスト・キャッシュ・家族整合性のバランスが最良。判断ミスリスクは prompt 規約と observability で吸収可能。
- 推奨案 A（rename + 観測）から始めるか、推奨案 B（dispatcher 導入）に直接行くかは user の risk appetite 次第。**運用習慣（コマンド使用率）が高ければ A で十分**。**自然言語で重い依頼を投げる頻度が高ければ B が効く**。
- B を選ぶ場合、本ドキュメント §0–§7 の全変更をまとめて適用。バックアップとロールバック手順を必ず先に確保する。
