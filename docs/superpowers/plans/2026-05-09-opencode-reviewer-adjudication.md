# OpenCode Reviewer Adjudication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reviewer の指摘を `ACCEPT / REJECT / DEFER / NEEDS_CONTEXT / ESCALATE` に分類して filter する adjudication フローを orchestrator に導入し、誤指摘による scope 膨張と implementer の迷走を防ぐ。あわせて GPT quota 節約のため reviewer model を `opencode-go/glm-5.1` に切り替える。

**Architecture:** Reviewer は構造化された Finding format（Severity / Confidence / Category / Evidence など）で個別 finding を出す。Orchestrator は受け取った findings を 5値で分類し、ACCEPT のみを implementer に渡す。DEFER は plan の Open Questions セクションに記録する。Reviewer の mode・permission・critical thinking elicitation は据え置き（昨日の改修と整合）。

**Tech Stack:** OpenCode (jsonc 設定), Markdown プロンプト, Superpowers slash command

**Branch:** `claude/opencode-reviewer-adjudication`（main から分岐済み）

**Note on what is NOT in this plan（design doc から意図的に除外したもの）:**

- `mode: "all"` 化 → OpenCode schema で未確認、`subagent` 維持
- `steps: 8` 追加 → OpenCode 設定項目として未確認、追加しない
- reviewer permission の git-only 縮小 → webfetch/test 実行はレビュー品質に寄与するため据え置き
- doc-planner エージェント追加 → 存在しない、orchestrator が docs を担当する現状維持
- Finding format で critical thinking elicitation を置換 → 役割が異なるため両立

**Note on reviewer model change（採用理由）:**

- 現状 `openai/gpt-5.4` は ChatGPT Pro / Codex quota を消費する
- reviewer はタスクごとに呼ばれ、plan / ADR / docs / diff を読むため入力が大きい
- `opencode-go/glm-5.1` に切り替えれば GPT quota を arbiter / orchestrator の判断に温存できる
- 独立性: implementer (kimi-k2.6) と explorer (deepseek-v4-pro) と異なる model を維持
- 品質劣化リスク: GLM-5.1 の批判的レビュー能力は未検証。実運用で `誤指摘・過剰指摘の量` を観察し、許容できなければ revert する

---

### Task 1: opencode.json の reviewer model を `opencode-go/glm-5.1` に変更する

GPT quota 節約のため、reviewer model を opencode-go プロバイダの最新 GLM に切り替える。OpenAI 専用パラメータは削除する。

**Files:**
- Modify: `.config/opencode/opencode.json`

- [ ] **Step 1: 現在の reviewer セクションを確認する**

```bash
grep -A 30 '"reviewer"' /Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json | head -35
```

期待値: `"model": "openai/gpt-5.4"`、`"reasoningEffort": "medium"`、`"textVerbosity": "low"` が見える。

- [ ] **Step 2: reviewer の model を変更し、OpenAI 専用フィールドを削除する**

`reviewer` ブロックの以下を変更：

変更前：
```json
"model": "openai/gpt-5.4",
"reasoningEffort": "medium",
"textVerbosity": "low",
"temperature": 0.1,
```

変更後：
```json
"model": "opencode-go/glm-5.1",
"temperature": 0.1,
```

`reasoningEffort` と `textVerbosity` は openai 系専用なので opencode-go モデルでは外す。`temperature: 0.1` は維持する。

- [ ] **Step 3: 変更を確認する**

```bash
grep -A 5 '"reviewer"' /Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json | head -10
```

期待値: `"model": "opencode-go/glm-5.1"` が見える。`reasoningEffort` / `textVerbosity` の行が無い。

- [ ] **Step 4: opencode.json が JSONC として壊れていないことを確認する**

```bash
node -e "const fs=require('fs'); const s=fs.readFileSync('/Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json','utf8').replace(/\/\/.*$/gm,'').replace(/\/\*[\s\S]*?\*\//g,''); JSON.parse(s); console.log('OK');"
```

期待値: `OK`

- [ ] **Step 5: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .config/opencode/opencode.json
git commit -m "feat(opencode): reviewer を opencode-go/glm-5.1 に変更（GPT quota 節約）"
```

---

### Task 2: reviewer.md に Finding format と discipline を追加する

個別の指摘を `Severity / Confidence / Category / Evidence` 等で構造化し、orchestrator が adjudication しやすい形式にする。critical thinking elicitation はそのまま残す。

**Files:**
- Modify: `.config/opencode/prompts/reviewer.md`

- [ ] **Step 1: 現在の構成を確認する**

```bash
grep -n "^# " /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/reviewer.md
```

期待値（並び順）: Role / How to start / Critical thinking elicitation / Plan review framework / ADR review framework / README / docs review framework / Implementation review framework / Escalation policy / Output format

- [ ] **Step 2: `# Critical thinking elicitation` セクションの直後に `# Finding format` セクションを追加する**

`# Plan review framework` の直前に、以下のブロックを挿入する：

```md
# Finding format
Each individual issue listed under "Critical issues" or "Non-blocking suggestions" MUST use this structured format. This makes adjudication possible for the orchestrator.

1. ID: F1, F2, ... (unique within this review)
2. Severity: BLOCKER / MAJOR / MINOR / NIT
3. Confidence: HIGH / MEDIUM / LOW
4. Category: correctness / security / test / maintainability / docs / plan / adr / scope
5. Evidence: file path with line range, diff hunk, plan section, or command output
6. Why it matters: 1 sentence linking to goal, spec, or risk
7. Recommended action: specific, scoped, in-line with existing patterns
8. Must fix before merge: yes / no / uncertain

# Finding discipline
- Do not inflate Severity beyond what evidence supports.
- Confidence: LOW means orchestrator may safely REJECT or DEFER. Mark it LOW honestly.
- Preferences and stylistic choices belong in NIT, never BLOCKER.
- Refactor recommendations require evidence the change creates clear new risk; otherwise mark them as DEFER candidates.
- A finding without concrete evidence is omitted, not weakened.
- Do not turn missing context into REQUEST_CHANGES; mark Confidence LOW or move it to "Missing context or tests".

```

- [ ] **Step 3: `# Output format` セクションの 7-8 番目を Finding format に置き換える**

変更前（該当行のみ）：
```
7. Critical issues (blocking)
8. Non-blocking suggestions
```

変更後：
```
7. Critical issues (blocking): list of findings using the Finding format above (Severity ≥ MAJOR)
8. Non-blocking suggestions: list of findings using the Finding format above (Severity ≤ MINOR)
```

- [ ] **Step 4: 反映を確認する**

```bash
grep -n "Finding format\|Finding discipline" /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/reviewer.md
```

期待値: 4行（セクション見出し2つ + Output format からの参照2つ）

```bash
grep -n "^# " /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/reviewer.md
```

期待値: 既存セクションの間に `# Finding format` と `# Finding discipline` が挿入されている。

- [ ] **Step 5: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .config/opencode/prompts/reviewer.md
git commit -m "feat(opencode): reviewer に Finding format と discipline を追加"
```

---

### Task 3: orchestrator.md に Review adjudication セクションを追加する

Reviewer の findings を ACCEPT / REJECT / DEFER / NEEDS_CONTEXT / ESCALATE に分類し、ACCEPT のみを implementer に渡すルールを明文化する。

**Files:**
- Modify: `.config/opencode/prompts/orchestrator.md`

- [ ] **Step 1: 現在の構成を確認する**

```bash
grep -n "^# " /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/orchestrator.md
```

期待値: Role / Responsibilities / Routing / Plan / ADR / README writing / Failure detection / Token policy / Delegation format / Output style

- [ ] **Step 2: `# Failure detection` の直後、`# Token policy` の直前に `# Review adjudication` セクションを追加する**

挿入する内容：

```md
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

Append the same table to the plan's "Review Findings" section. For each DEFER, append a one-line entry under "Open Questions" so it is not lost.

When dispatching @implementer for fixes, include only ACCEPT findings in the brief. Do not forward REJECT, DEFER, NEEDS_CONTEXT, or ESCALATE findings.

Special cases:
- Verdict APPROVE: no adjudication. Log `[YYYY-MM-DD] artifact → APPROVE | (no findings)` to Review Findings.
- Verdict NEEDS_CONTEXT: provide the missing context, then re-dispatch @reviewer. No adjudication.
- Verdict ESCALATE: ask user before invoking @arbiter. No adjudication of individual findings.

```

- [ ] **Step 3: 反映を確認する**

```bash
grep -n "^# " /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/orchestrator.md
```

期待値: `# Review adjudication` が `# Failure detection` と `# Token policy` の間にある。

```bash
grep -n "ACCEPT\|REJECT\|DEFER\|NEEDS_CONTEXT\|ESCALATE" /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/orchestrator.md
```

期待値: 5値が複数行で出てくる（criteria 列挙、説明、table 内）。

- [ ] **Step 4: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .config/opencode/prompts/orchestrator.md
git commit -m "feat(opencode): orchestrator に Review adjudication フローを追加"
```

---

### Task 4: review-* slash command に Finding format 指示を追記する

4つの review コマンドそれぞれに、Finding format で個別 finding を列挙する指示を追加する。

**Files:**
- Modify: `.config/opencode/commands/review-plan.md`
- Modify: `.config/opencode/commands/review-impl.md`
- Modify: `.config/opencode/commands/review-adr.md`
- Modify: `.config/opencode/commands/review-docs.md`

- [ ] **Step 1: 現在の review-plan.md を確認する**

```bash
cat /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/review-plan.md
```

- [ ] **Step 2: review-plan.md の末尾の "Update the plan's Review Findings section..." 行の直前に追記する**

`Apply only the plan review framework. Generate critical thinking findings (failure modes, steel-man alternative, unstated assumptions, senior engineer rejection point) before forming the verdict.` の直後、`Update the plan's Review Findings section with a one-line entry.` の直前に、以下を1行追加する：

```md
List individual issues under Critical issues / Non-blocking suggestions using the Finding format defined in reviewer.md (ID / Severity / Confidence / Category / Evidence / Why / Recommended action / Must fix before merge).
```

- [ ] **Step 3: review-impl.md, review-adr.md, review-docs.md にも同じ1行を追加する**

各ファイルで、最後の指示行（`Update the plan's Review Findings section...` または最終行）の直前に同じ文を追加する。

review-impl.md と review-plan.md には末尾に `Update the plan's Review Findings section with a one-line entry.` がある。その直前に追加する。

review-adr.md と review-docs.md には Update 行がない。これらのファイルの末尾に同じ文を追加する。

- [ ] **Step 4: 4ファイル全てに反映されたことを確認する**

```bash
grep -l "Finding format defined in reviewer.md" /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/review-*.md
```

期待値: 4ファイル全て表示される（review-plan.md, review-impl.md, review-adr.md, review-docs.md）

- [ ] **Step 5: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .config/opencode/commands/review-plan.md .config/opencode/commands/review-impl.md .config/opencode/commands/review-adr.md .config/opencode/commands/review-docs.md
git commit -m "feat(opencode): review-* commands に Finding format 指示を追加"
```

---

### Task 5: /plan command の Review Findings コメントを adjudication 表形式に更新する

living plan の Review Findings セクションを「verdict だけの 1行」から「adjudication 表」に拡張する。

**Files:**
- Modify: `.config/opencode/commands/plan.md`

- [ ] **Step 1: 現在の plan.md を確認する**

```bash
cat /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/plan.md
```

- [ ] **Step 2: Review Findings コメントを書き換える**

変更前：
```md
  ## Review Findings
  <!-- Reviewer appends one line per review: [YYYY-MM-DD] ARTIFACT_TYPE → VERDICT | key issue -->
```

変更後：
```md
  ## Review Findings
  <!-- Orchestrator appends per review:
       [YYYY-MM-DD] ARTIFACT_TYPE → VERDICT
       (if REQUEST_CHANGES with findings, also append the adjudication table:
       | ID | Severity | Decision | Reason | Action |) -->
```

- [ ] **Step 3: 確認する**

```bash
grep -A 4 "Review Findings" /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/plan.md
```

期待値: `adjudication table` の文字列が含まれている。

- [ ] **Step 4: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .config/opencode/commands/plan.md
git commit -m "feat(opencode): /plan の Review Findings を adjudication 表形式に更新"
```

---

### Task 6: 共有 AGENTS.md に Reviewer findings handling を追記する

`.agents/AGENTS.md` の OpenCode Balanced Workflow セクションに、reviewer 指摘の取り扱いルールを追加する。

**Files:**
- Modify: `.agents/AGENTS.md`

- [ ] **Step 1: 現在の OpenCode Balanced Workflow セクションを確認する**

```bash
grep -n "OpenCode Balanced Workflow" /Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md
```

- [ ] **Step 2: `**Plan as source of truth:**` ブロックの直前に、新しいサブセクションを追加する**

挿入する内容：

```md
**Reviewer findings の取り扱い:**
- `@reviewer` の指摘は `@orchestrator` が `ACCEPT / REJECT / DEFER / NEEDS_CONTEXT / ESCALATE` に分類してから `@implementer` に渡す。
- 採否は plan の Review Findings セクションに表形式（| ID | Severity | Decision | Reason | Action |）で記録する。
- DEFER は plan の Open Questions セクションにも転記して追跡する。
- `@implementer` には ACCEPT 分のみを渡す（reviewer の全文を流さない）。
- ESCALATE は `@arbiter` 呼び出し前に必ずユーザーに確認する。

```

- [ ] **Step 3: 確認する**

```bash
grep -A 8 "Reviewer findings" /Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md
```

期待値: 5箇条のサブセクションが見える。

- [ ] **Step 4: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .agents/AGENTS.md
git commit -m "feat(agents): AGENTS.md に Reviewer findings の取り扱いを追記"
```

---

### Task 7: 全体検証

設計全体の整合性を最終確認する。

- [ ] **Step 1: opencode.json の reviewer model 確認**

```bash
grep -A 2 '"reviewer"' /Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json | grep model
```

期待値: `"model": "opencode-go/glm-5.1"`

- [ ] **Step 2: reviewer.md と orchestrator.md の主要要素の存在確認**

```bash
grep -l "Finding format\|Finding discipline" /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/reviewer.md
grep -l "Review adjudication" /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/orchestrator.md
```

期待値: 両方ファイル名が出力される。

- [ ] **Step 3: 4つの review コマンドに Finding format 指示があることを確認**

```bash
grep -L "Finding format defined in reviewer.md" /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/review-*.md
```

期待値: 出力なし（`-L` は missing を出すため、全部に含まれていれば空）

- [ ] **Step 4: AGENTS.md にサブセクションが追加されたことを確認**

```bash
grep "Reviewer findings の取り扱い" /Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md
```

期待値: 1行ヒットする。

- [ ] **Step 5: opencode.json が JSONC として valid であることを再確認**

```bash
node -e "const fs=require('fs'); const s=fs.readFileSync('/Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json','utf8').replace(/\/\/.*$/gm,'').replace(/\/\*[\s\S]*?\*\//g,''); JSON.parse(s); console.log('OK');"
```

期待値: `OK`

- [ ] **Step 6: 全コミットの確認**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git log --oneline main..HEAD
```

期待値: 各 Task ごとに 1 コミット（合計 6 コミット）

- [ ] **Step 7: 動作確認（手動）**

ユーザーに以下を依頼：
- OpenCode を起動
- `/review-impl <branch-or-target>` を呼ぶ
- reviewer の出力に Finding format（ID / Severity / Confidence / Category / Evidence / ...）が現れるか確認
- orchestrator が Verdict: REQUEST_CHANGES を受けたとき adjudication 表を提示するか確認
- これは subagent では検証できないため人間の手動確認に委ねる

---

## 改善点と Task の対応表

| 改善点                                          | Tasks |
| --------------------------------------------- | ----- |
| reviewer model を opencode-go/glm-5.1 に変更      | 1     |
| Finding format（個別指摘の構造化）                       | 2, 4  |
| Finding discipline（過剰指摘の抑制）                    | 2     |
| Review adjudication（5値分類で filter）              | 3, 6  |
| Adjudication 表を plan に記録                      | 3, 5  |
| DEFER を Open Questions に転記                    | 3, 6  |
| ACCEPT のみを implementer に渡す                    | 3, 6  |
| AGENTS.md でルールを共有                              | 6     |
| 全体検証                                            | 7     |

---

## 注意事項

- すべての変更は dotfiles リポジトリ側で行う。`~/.config/opencode/` 配下はシンボリックリンク。
- reviewer model 変更後は GLM-5.1 の批判的レビュー品質を実運用で観察する。誤指摘・過剰指摘が許容できなければ `openai/gpt-5.4` に revert する。
- adjudication は **orchestrator がユーザーに表を提示してから** implementer を dispatch する。silent filter にしない（ユーザーが override できる余地を残す）。
- mode / permission / explorer / implementer / arbiter には変更を加えない（昨日の改修と直交）。
