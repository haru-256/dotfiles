# OpenCode Reviewer Adjudication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reviewer の指摘を `ACCEPT / REJECT / DEFER / NEEDS_CONTEXT / ESCALATE` に分類して filter する adjudication フローを orchestrator に導入し、誤指摘による scope 膨張と implementer の迷走を防ぐ。あわせて GPT quota 節約のため reviewer model を `opencode-go/glm-5.1` に切り替える。

**Architecture:** Reviewer は構造化された Finding format（Severity / Confidence / Category / Evidence など）で個別 finding を **inline で返すのみ**（plan には書き込まない）。Orchestrator は自分の workflow 内で @reviewer を呼んだ場合だけ、受け取った findings を **verbatim で plan の `Review Findings > Reviewer Raw Findings` に転記**し、5値分類した採否表を `Review Findings > Orchestrator Adjudication` に追記し、ACCEPT のみを implementer に渡す。DEFER は plan の Open Questions セクションに記録する。`/review-*` command は「単にレビューする」入口なので direct reviewer のままにし、orchestrator workflow を経由しない（plan 自動保存も行わない）。**plan への書き込みは orchestrator のみ**（単一書き込み主体）。Reviewer の mode・permission・critical thinking elicitation は据え置き（昨日の改修と整合）。

**Tech Stack:** OpenCode (jsonc 設定), Markdown プロンプト, Superpowers slash command

**Branch:** `claude/opencode-reviewer-adjudication`（main から分岐済み）

**Note on what is NOT in this plan（design doc から意図的に除外したもの）:**

- `mode: "all"` 化 → OpenCode schema で未確認、`subagent` 維持
- `steps: 8` 追加 → OpenCode 設定項目として未確認、追加しない
- reviewer permission の git-only 縮小 → webfetch/test 実行はレビュー品質に寄与するため据え置き
- doc-planner エージェント追加 → 存在しない、orchestrator が docs を担当する現状維持
- Finding format で critical thinking elicitation を置換 → 役割が異なるため両立
- reviewer 直行の `/review-*` command 維持 → ユーザーが単にレビュー結果を見たい入口なので維持する。reviewer は inline で findings を返し、plan への永続化は呼び出し元（orchestrator workflow か user の手動転記）に委ねる
- reviewer に plan 書き込み責務を持たせない（単一書き込み主体: orchestrator のみ）→ ADR / docs / branch 単独 review で plan が存在しない場合の分岐ロジックを排除し、drift と race を構造的に防ぐ

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
node <<'NODE'
const fs = require('fs');
const path = '/Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json';
const input = fs.readFileSync(path, 'utf8');
function stripJsonc(s) {
  let out = '', inString = false, escape = false, line = false, block = false;
  for (let i = 0; i < s.length; i++) {
    const c = s[i], n = s[i + 1];
    if (line) { if (c === '\n') { line = false; out += c; } continue; }
    if (block) { if (c === '*' && n === '/') { block = false; i++; } continue; }
    if (inString) { out += c; if (escape) escape = false; else if (c === '\\') escape = true; else if (c === '"') inString = false; continue; }
    if (c === '"') { inString = true; out += c; continue; }
    if (c === '/' && n === '/') { line = true; i++; continue; }
    if (c === '/' && n === '*') { block = true; i++; continue; }
    out += c;
  }
  return out;
}
const config = JSON.parse(stripJsonc(input));
console.log(JSON.stringify(config.agent.reviewer, null, 2));
NODE
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
node <<'NODE'
const fs = require('fs');
const path = '/Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json';
const input = fs.readFileSync(path, 'utf8');
function stripJsonc(s) {
  let out = '', inString = false, escape = false, line = false, block = false;
  for (let i = 0; i < s.length; i++) {
    const c = s[i], n = s[i + 1];
    if (line) { if (c === '\n') { line = false; out += c; } continue; }
    if (block) { if (c === '*' && n === '/') { block = false; i++; } continue; }
    if (inString) { out += c; if (escape) escape = false; else if (c === '\\') escape = true; else if (c === '"') inString = false; continue; }
    if (c === '"') { inString = true; out += c; continue; }
    if (c === '/' && n === '/') { line = true; i++; continue; }
    if (c === '/' && n === '*') { block = true; i++; continue; }
    out += c;
  }
  return out;
}
const reviewer = JSON.parse(stripJsonc(input)).agent.reviewer;
console.log(reviewer.model);
if ('reasoningEffort' in reviewer || 'textVerbosity' in reviewer) {
  throw new Error('OpenAI-only reviewer fields still present');
}
NODE
```

期待値: `"model": "opencode-go/glm-5.1"` が見える。`reasoningEffort` / `textVerbosity` の行が無い。

- [ ] **Step 4: opencode.json が JSONC として壊れていないことを確認する**

```bash
node <<'NODE'
const fs = require('fs');
const path = '/Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json';
const input = fs.readFileSync(path, 'utf8');
function stripJsonc(s) {
  let out = '', inString = false, escape = false, line = false, block = false;
  for (let i = 0; i < s.length; i++) {
    const c = s[i], n = s[i + 1];
    if (line) { if (c === '\n') { line = false; out += c; } continue; }
    if (block) { if (c === '*' && n === '/') { block = false; i++; } continue; }
    if (inString) { out += c; if (escape) escape = false; else if (c === '\\') escape = true; else if (c === '"') inString = false; continue; }
    if (c === '"') { inString = true; out += c; continue; }
    if (c === '/' && n === '/') { line = true; i++; continue; }
    if (c === '/' && n === '*') { block = true; i++; continue; }
    out += c;
  }
  return out;
}
JSON.parse(stripJsonc(input));
console.log('OK');
NODE
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

- [ ] **Step 3: `# Output format` セクションの 7-8 番目を Finding format に置き換え、12 番目を inline-only に変更する**

変更前（該当行のみ）：
```
7. Critical issues (blocking)
8. Non-blocking suggestions
12. Update to plan's Review Findings section: a one-line entry summarizing the verdict
```

変更後：
```
7. Critical issues (blocking): list of findings using the Finding format above (Severity ≥ MAJOR)
8. Non-blocking suggestions: list of findings using the Finding format above (Severity ≤ MINOR)
12. Inline output only. Do not read or write plan files. Raw findings are review input, not implementation instructions. The invoking workflow (@orchestrator or the user) is responsible for any plan persistence.
```

- [ ] **Step 4: 反映を確認する**

```bash
grep -n "Finding format\|Finding discipline" /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/reviewer.md
```

期待値: 4行（セクション見出し2つ + Output format からの参照2つ）

```bash
grep -n "Inline output only\|Do not read or write plan" /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/reviewer.md
```

期待値: reviewer は inline 出力のみで plan を書かない旨が見える。

```bash
grep -nE "Reviewer Raw Findings|append.*plan|update.*plan'" /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/reviewer.md || echo "OK: reviewer は plan に書く指示を含まない"
```

期待値: `OK: reviewer は plan に書く指示を含まない`（reviewer が plan セクション名を知らない / 書かない）。

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

Persistence (orchestrator is the sole writer to the plan):

1. Copy @reviewer's structured findings verbatim into the plan's `Review Findings > Reviewer Raw Findings` section using this exact entry format:

   ```md
   #### [YYYY-MM-DD] ARTIFACT_TYPE → VERDICT
   Critical issues (blocking):
   - F1: <Finding format from reviewer.md>
   - F2: <Finding format from reviewer.md>
   Non-blocking suggestions:
   - F3: <Finding format from reviewer.md>
   ```

2. Append the adjudication table under `Review Findings > Orchestrator Adjudication`:

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
- Verdict APPROVE: no adjudication. Append a one-line entry `[YYYY-MM-DD] ARTIFACT_TYPE → APPROVE | (no findings)` under `Review Findings > Reviewer Raw Findings`. No Orchestrator Adjudication entry.
- Verdict NEEDS_CONTEXT: provide the missing context, then re-dispatch @reviewer. No persistence.
- Verdict ESCALATE: ask user before invoking @arbiter. No adjudication of individual findings; persistence (raw findings transcript) only after the @arbiter loop concludes.

```

- [ ] **Step 3: living plan の Review Findings コメントを orchestrator 管理に更新する**

`# Plan / ADR / README writing` 内の Review Findings コメントを変更する。reviewer は plan に書き込まないため、両セクションとも orchestrator 管理である旨を明記する。あわせて plan.md（Task 5）と template が二重管理になるため、sync コメントを入れる：

変更前：
```md
## Review Findings
<!-- Reviewer appends one line per review: [YYYY-MM-DD] ARTIFACT_TYPE → VERDICT | key issue -->
```

変更後：
```md
## Review Findings
<!-- This template is also defined in commands/plan.md. Keep them in sync (verified by Task 7 Step 7). -->

### Reviewer Raw Findings
<!-- Orchestrator copies @reviewer's structured findings verbatim here when invoking @reviewer
     during a workflow. Direct /review-* calls do not write here.
     Raw findings are review input (audit history), not implementation instructions. -->

### Orchestrator Adjudication
<!-- Orchestrator appends adjudication tables for orchestrated workflow reviews.
     Only ACCEPT rows are implementation instructions:
     | ID | Severity | Decision | Reason | Action | -->
```

- [ ] **Step 4: 反映を確認する**

```bash
grep -n "^# " /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/orchestrator.md
```

期待値: `# Review adjudication` が `# Failure detection` と `# Token policy` の間にある。

```bash
grep -n "ACCEPT\|REJECT\|DEFER\|NEEDS_CONTEXT\|ESCALATE" /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/orchestrator.md
```

期待値: 5値が複数行で出てくる（criteria 列挙、説明、table 内）。

```bash
grep -A 5 "## Review Findings" /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/orchestrator.md
```

期待値: `Reviewer Raw Findings` と `Orchestrator Adjudication` の両方の説明が見える。

- [ ] **Step 5: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .config/opencode/prompts/orchestrator.md
git commit -m "feat(opencode): orchestrator に Review adjudication フローを追加"
```

---

### Task 4: review-* slash command に Finding format 指示を追記する（plan 書き込みは削除）

4つの review コマンドは「単にレビューする」入口なので `agent: reviewer` のまま維持する。各 command には Finding format で個別 finding を列挙する指示を追加する。reviewer は inline 出力のみで plan に書き込まないため、Phase 1 で追加された `Update the plan's Review Findings section...` の指示は **削除する**（user / orchestrator が必要に応じて転記する）。

**Files:**
- Modify: `.config/opencode/commands/review-plan.md`
- Modify: `.config/opencode/commands/review-impl.md`
- Modify: `.config/opencode/commands/review-adr.md`
- Modify: `.config/opencode/commands/review-docs.md`

- [ ] **Step 1: 4ファイルの現在の内容を確認する**

```bash
for f in /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/review-{plan,impl,adr,docs}.md; do
  echo "=== $f ==="; cat "$f"; echo
done
```

- [ ] **Step 2: 4ファイルの frontmatter が `agent: reviewer` のままであることを確認する**

```bash
grep -n "^agent:" /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/review-*.md
```

期待値: 4 ファイル全てで `agent: reviewer`。理由: `/review-*` は direct review command であり、orchestrator workflow の adjudication 入口ではないため。

- [ ] **Step 3: 4ファイルそれぞれに Finding format 指示を追加する**

各 command の critical thinking 指示行（`...before forming the verdict.`）の直後に以下 1行を追加する：

```md
List individual issues under Critical issues / Non-blocking suggestions using the Finding format defined in reviewer.md (ID / Severity / Confidence / Category / Evidence / Why / Recommended action / Must fix before merge).
```

- [ ] **Step 4: 既存の plan 書き込み指示を削除する**

review-plan.md / review-impl.md には末尾に `Update the plan's Review Findings section with a one-line entry.` がある（Phase 1 で追加されたもの）。これを **削除する**。reviewer は plan に書き込まないため。

review-adr.md / review-docs.md には plan 書き込み指示は元々無い。追加もしない。

- [ ] **Step 5: 4ファイル全てに反映されたことを確認する**

```bash
grep -L "agent: reviewer" /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/review-*.md
```

期待値: 出力なし（4ファイル全て direct reviewer のまま）。

```bash
grep -L "Finding format defined in reviewer.md" /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/review-*.md
```

期待値: 出力なし（4ファイル全て Finding format 指示を含む）。

```bash
grep -l "Update the plan's Review Findings" /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/review-*.md
```

期待値: 出力なし（4ファイル全て plan 書き込み指示が消えている）。

- [ ] **Step 6: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git add .config/opencode/commands/review-plan.md .config/opencode/commands/review-impl.md .config/opencode/commands/review-adr.md .config/opencode/commands/review-docs.md
git commit -m "feat(opencode): review-* commands に Finding format 指示を追加（plan 書き込みは orchestrator に集約）"
```

---

### Task 5: /plan command の Review Findings コメントを adjudication 表形式に更新する

living plan の Review Findings セクションを、orchestrator が raw findings を verbatim 転記し、続けて adjudication 表を追記する形式に拡張する。**Task 3 Step 3 の orchestrator.md template と完全に同じ内容**にする（F6: sync 必須、Task 7 Step 7 で機械検証）。

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

変更後（orchestrator.md と完全一致させる。インデントのみ list 配下に合わせる）：
```md
  ## Review Findings
  <!-- This template is also defined in prompts/orchestrator.md. Keep them in sync (verified by Task 7 Step 7). -->

  ### Reviewer Raw Findings
  <!-- Orchestrator copies @reviewer's structured findings verbatim here when invoking @reviewer
       during a workflow. Direct /review-* calls do not write here.
       Raw findings are review input (audit history), not implementation instructions. -->

  ### Orchestrator Adjudication
  <!-- Orchestrator appends adjudication tables for orchestrated workflow reviews.
       Only ACCEPT rows are implementation instructions:
       | ID | Severity | Decision | Reason | Action | -->
```

- [ ] **Step 3: 確認する**

```bash
grep -A 14 "## Review Findings" /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/plan.md
```

期待値: `Reviewer Raw Findings`、`Orchestrator Adjudication`、`Only ACCEPT rows are implementation instructions`、`Keep them in sync` の文字列が含まれている。

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
- `@reviewer` は構造化 findings を inline で返すのみ。plan には書き込まない（**単一書き込み主体: orchestrator のみ**）。
- `@orchestrator` は workflow 内で `@reviewer` を呼んだ場合、受け取った findings を verbatim で plan の `Review Findings > Reviewer Raw Findings` に転記する。
- 続けて `@orchestrator` は raw findings を `ACCEPT / REJECT / DEFER / NEEDS_CONTEXT / ESCALATE` に分類し、採否を `Review Findings > Orchestrator Adjudication` に表形式（| ID | Severity | Decision | Reason | Action |）で記録する。
- raw findings はレビュー入力（監査履歴）であり、そのまま実装指示として扱わない。
- DEFER は plan の Open Questions セクションにも転記して追跡する。
- `@implementer` には ACCEPT 分のみを渡す。
- ESCALATE は `@arbiter` 呼び出し前に必ずユーザーに確認する。
- `/review-*` 直接呼び出しは reviewer が inline で findings を返すだけ。plan 自動保存は行わない（user が必要なら手で転記する）。

```

- [ ] **Step 3: 確認する**

```bash
grep -A 11 "Reviewer findings" /Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md
```

期待値: 単一書き込み主体、verbatim 転記、adjudication、ACCEPT のみ実装指示、direct `/review-*` の挙動が見える。

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
node <<'NODE'
const fs = require('fs');
const path = '/Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json';
const input = fs.readFileSync(path, 'utf8');
function stripJsonc(s) {
  let out = '', inString = false, escape = false, line = false, block = false;
  for (let i = 0; i < s.length; i++) {
    const c = s[i], n = s[i + 1];
    if (line) { if (c === '\n') { line = false; out += c; } continue; }
    if (block) { if (c === '*' && n === '/') { block = false; i++; } continue; }
    if (inString) { out += c; if (escape) escape = false; else if (c === '\\') escape = true; else if (c === '"') inString = false; continue; }
    if (c === '"') { inString = true; out += c; continue; }
    if (c === '/' && n === '/') { line = true; i++; continue; }
    if (c === '/' && n === '*') { block = true; i++; continue; }
    out += c;
  }
  return out;
}
const reviewer = JSON.parse(stripJsonc(input)).agent.reviewer;
console.log(reviewer.model);
NODE
```

期待値: `"model": "opencode-go/glm-5.1"`

- [ ] **Step 2: reviewer.md と orchestrator.md の主要要素の存在確認**

```bash
grep -l "Finding format\|Finding discipline" /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/reviewer.md
grep -l "Review adjudication" /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/orchestrator.md
```

期待値: 両方ファイル名が出力される。

- [ ] **Step 3: reviewer.md が plan に書く指示を含まないことを確認（Option A: 単一書き込み主体）**

```bash
grep -nE "Reviewer Raw Findings|append.*plan|update.*plan'" /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/reviewer.md || echo "OK: reviewer は plan に書く指示を含まない"
```

期待値: `OK: reviewer は plan に書く指示を含まない`

- [ ] **Step 4: 4つの review コマンドに Finding format 指示があることを確認**

```bash
grep -L "Finding format defined in reviewer.md" /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/review-*.md
```

期待値: 出力なし（`-L` は missing を出すため、全部に含まれていれば空）

- [ ] **Step 5: 4つの review コマンドが direct reviewer のままで plan 書き込み指示を含まないことを確認**

```bash
grep -L "agent: reviewer" /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/review-*.md
grep -l "Update the plan's Review Findings" /Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/review-*.md
```

期待値: いずれも出力なし。

- [ ] **Step 6: AGENTS.md にサブセクションが追加されたことを確認**

```bash
grep "Reviewer findings の取り扱い" /Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md
```

期待値: 1行ヒットする。

- [ ] **Step 7: orchestrator.md と plan.md の Review Findings template が一致することを確認（F6 sync 検証）**

```bash
node <<'NODE'
const fs = require('fs');
function extract(filepath) {
  const txt = fs.readFileSync(filepath, 'utf8');
  const start = txt.indexOf('## Review Findings');
  if (start < 0) throw new Error(`'## Review Findings' not found in ${filepath}`);
  // template ブロック（## から次の ## または `` まで）を抽出
  const after = txt.slice(start + 1);
  const endRel = after.search(/\n## |\n```/);
  const block = endRel < 0 ? txt.slice(start) : txt.slice(start, start + 1 + endRel);
  // インデント、行末空白、空行を正規化（plan.md は list 配下なのでインデントが付く）
  return block
    .split('\n')
    .map(l => l.replace(/^\s+/, '').trimEnd())
    .filter(l => l.length > 0)
    .join('\n');
}
const a = extract('/Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/orchestrator.md');
const b = extract('/Users/haru256/Documents/projects/dotfiles/.config/opencode/commands/plan.md');
if (a !== b) {
  console.error('Templates diverged.');
  console.error('--- orchestrator.md ---');
  console.error(a);
  console.error('--- plan.md ---');
  console.error(b);
  process.exit(1);
}
console.log('OK');
NODE
```

期待値: `OK`。template が orchestrator.md と plan.md で一致している。

- [ ] **Step 8: opencode.json が JSONC として valid であることを再確認**

```bash
node <<'NODE'
const fs = require('fs');
const path = '/Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json';
const input = fs.readFileSync(path, 'utf8');
function stripJsonc(s) {
  let out = '', inString = false, escape = false, line = false, block = false;
  for (let i = 0; i < s.length; i++) {
    const c = s[i], n = s[i + 1];
    if (line) { if (c === '\n') { line = false; out += c; } continue; }
    if (block) { if (c === '*' && n === '/') { block = false; i++; } continue; }
    if (inString) { out += c; if (escape) escape = false; else if (c === '\\') escape = true; else if (c === '"') inString = false; continue; }
    if (c === '"') { inString = true; out += c; continue; }
    if (c === '/' && n === '/') { line = true; i++; continue; }
    if (c === '/' && n === '*') { block = true; i++; continue; }
    out += c;
  }
  return out;
}
JSON.parse(stripJsonc(input));
console.log('OK');
NODE
```

期待値: `OK`

- [ ] **Step 9: 責務分岐の確認（reviewer は inline-only / orchestrator は verbatim 転記）**

```bash
grep -n "Inline output only\|Do not read or write plan" /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/reviewer.md
grep -n "verbatim\|Reviewer Raw Findings\|Orchestrator Adjudication\|Only ACCEPT rows are implementation instructions" /Users/haru256/Documents/projects/dotfiles/.config/opencode/prompts/orchestrator.md
```

期待値: reviewer は inline-only の旨が見え、orchestrator は raw findings を verbatim 転記し採否表を追記する旨が見え、ACCEPT のみが実装指示であることが見える。

- [ ] **Step 10: 全コミットの確認**

```bash
cd /Users/haru256/Documents/projects/dotfiles
git log --oneline main..HEAD
```

期待値: 各 Task ごとに 1 コミット（Task 1〜6 = 6 コミット）+ plan 修正コミット 1〜2 = 合計 7〜8 コミット。

- [ ] **Step 11: 動作確認（手動）**

ユーザーに以下を依頼：
- OpenCode を起動
- `/review-impl <branch-or-target>` を呼ぶ
- reviewer の出力に Finding format（ID / Severity / Confidence / Category / Evidence / ...）が現れるか確認
- `/review-impl` は inline で findings を返し、**plan に勝手に書き込まない**ことを確認
- orchestrator workflow 内で @reviewer が REQUEST_CHANGES を返した場合に、orchestrator が:
  - `Review Findings > Reviewer Raw Findings` に raw findings を **verbatim 転記**する
  - `Review Findings > Orchestrator Adjudication` に **採否表**を追記する
  - ACCEPT のみを implementer に渡す
  - DEFER を Open Questions に転記する
  を確認
- これは subagent では検証できないため人間の手動確認に委ねる

---

## 改善点と Task の対応表

| 改善点                                          | Tasks |
| --------------------------------------------- | ----- |
| reviewer model を opencode-go/glm-5.1 に変更      | 1     |
| Finding format（個別指摘の構造化）                       | 2, 4  |
| Finding discipline（過剰指摘の抑制）                    | 2     |
| reviewer は inline-only（plan に書かない、単一書き込み主体）        | 2, 4  |
| review commands は direct reviewer として維持             | 4     |
| Review adjudication（5値分類で filter）              | 3, 6  |
| Orchestrator が raw findings verbatim 転記 + 採否表追記 | 3, 6  |
| Adjudication 表 / Raw findings format を plan に定義 | 3, 5  |
| DEFER を Open Questions に転記                    | 3, 6  |
| ACCEPT のみを implementer に渡す                    | 3, 6  |
| Review Findings template の sync 維持（orchestrator.md ↔ plan.md） | 3, 5, 7 |
| AGENTS.md でルールを共有                              | 6     |
| 全体検証                                            | 7     |

---

## 注意事項

- すべての変更は dotfiles リポジトリ側で行う。`~/.config/opencode/` 配下はシンボリックリンク。
- reviewer model 変更後は GLM-5.1 の批判的レビュー品質を実運用で観察する。誤指摘・過剰指摘が許容できなければ `openai/gpt-5.4` に revert する。
- adjudication は **orchestrator がユーザーに表を提示してから** implementer を dispatch する。silent filter にしない（ユーザーが override できる余地を残す）。
- raw findings は監査履歴として残すが実装指示ではない。implementer に渡すのは ACCEPT findings だけ。
- **plan への書き込みは orchestrator のみ**が行う。reviewer は inline 出力のみ（単一書き込み主体）。これにより ADR / docs / branch 単独 review で plan が無い場合の分岐ロジックを排除し、drift と race を構造的に防ぐ。
- **Review Findings template は orchestrator.md と plan.md の両方に存在する**。更新時は両方を変更し、Task 7 Step 7 の sync 検証で確認する。
- mode / permission / explorer / implementer / arbiter には変更を加えない（昨日の改修と直交）。
- `/review-*` は direct reviewer のままなので、単にレビュー結果を見たい時に使う。adjudication と plan 永続化は orchestrator workflow 内で @reviewer を呼んだ場合だけ実施する。

## Implementation Log
<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N → STATUS | commit-or-failure-signature -->

## Review Findings
<!-- This template is also defined in prompts/orchestrator.md and commands/plan.md. Keep them in sync (verified by Task 7 Step 7). -->

### Reviewer Raw Findings
<!-- Orchestrator copies @reviewer's structured findings verbatim here when invoking @reviewer
     during a workflow. Direct /review-* calls do not write here.
     Raw findings are review input (audit history), not implementation instructions. -->

### Orchestrator Adjudication
<!-- Orchestrator appends adjudication tables for orchestrated workflow reviews.
     Only ACCEPT rows are implementation instructions:
     | ID | Severity | Decision | Reason | Action | -->

## Deviations from Plan
<!-- Implementer documents intentional deviations and reasons -->

## Open Questions
<!-- Any agent adds questions for orchestrator or arbiter -->
