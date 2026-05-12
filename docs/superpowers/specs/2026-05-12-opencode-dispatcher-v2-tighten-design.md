# Design: OpenCode `dispatcher_v2` を厳密 router 化する

**Date:** 2026-05-12

## Goal

OpenCode の `dispatcher_v2` を、ユーザー要望通りに以下 3 役へ厳密に絞り込む。

1. **ユーザー一次受付** — 受け取ったリクエストを評価
2. **sub-agent への routing** — v2 系 sub-agent (`@implementer_v2` / `@explorer_v2` / `@planner_v2`) に振り分け
3. **sub-agent 結果の報告** — sub-agent から返ってきた結果を整理して user に返す

特に「dispatcher が勝手に plan / explore 相当の作業をする」傾向を、permission と prompt の両面から物理的・規範的に抑止する。
sub-agent に振れない軽量応答（雑談・メタ質問・follow-up）は dispatcher 側で吸収して穴を埋める。

---

## Background

### 現状の構成

`.config/opencode/opencode.json` の v2 系エージェントは以下の通り:

- `dispatcher_v2` (primary, deepseek-v4-pro) — routing-only を意図
- `planner_v2` (subagent, gpt-5.5) — plan / ADR / docs / 判断 / adjudication
- `implementer_v2` (subagent, kimi-k2.6) — 実装
- `explorer_v2` (subagent, deepseek-v4-pro) — 読み取り探索
- `reviewer_v2` (subagent, deepseek-v4-pro) — 構造化レビュー
- `arbiter_v2` (subagent, gpt-5.5) — 最終相談

`dispatcher_v2` の現状 permission ([opencode.json:13-38](.config/opencode/opencode.json:13)):

- `edit: deny`、`webfetch: deny`、`websearch: deny`
- `read / bash:* / grep / glob / list / lsp / codesearch / external_directory`: すべて allow
- `task`: v2 三つ (implementer / explorer / planner) のみ allow
- `skill / question / todowrite`: allow

現状 prompt ([prompts/dispatcher_v2.md](.config/opencode/prompts/dispatcher_v2.md)) の構成:

- Role / Routing Decision (4 ルール) / Failure Loop Handling / Delegation Brief Format / Do Not (7 項目) / Output Style

### 観察された問題

1. **権限が広く、調査ツールがほぼ全部 allow** — prompt で「no implementation, no planning」と書いても、`bash / grep / read` が使えるため、model は確率的に自分で `git diff` や `rg` を始める。
2. **`# Do Not` に "no exploration" / "no commands" が無い** — 既存の Do Not は plan/impl/docs/adjudication/reviewer 直呼び/arbiter 直呼び/思考独白 のみで、能動的探索を禁止する文言が欠ける。
3. **Routing 判断のために調査が必要なケースの逃げ道が無い** — Rule 2 (`@explorer_v2`) は「user が明示的に exploration を要求した場合」だけで、dispatcher 自身の routing 判断のために context が要るケースに割り当てられていない。
4. **Result Reporting が prompt に書かれていない** — sub-agent 結果を user にどう返すかが未定義。
5. **Trivial 直 implementer の判定が dispatcher の自由裁量** — 「typo / single-line」を判定するために dispatcher が中身を見たくなる。
6. **`bash:*` が広すぎる** — git/gh/cat/pytest 等を何でも実行できる。
7. **Skill 起動時の脆さ** — `using-superpowers` は強い skill であり、`brainstorming` や `systematic-debugging` を引き当てると dispatcher が自分で考え始める。fixup plan で 1 行の bullet が追加されているが、補強の余地がある。

### ユーザーが選んだ方針

事前にすり合わせた選択肢は以下:

| 論点 | 選択 |
|---|---|
| Permission 全体 | **C** (ハイブリッド): `read` は残し、能動探索ツール (`bash / grep / glob / list / lsp / codesearch`) を deny |
| `bash` の粒度 | **C-1**: 完全 deny (ホワイトリスト無し) |
| Dispatcher の応答範囲 | **D-Z**: routing + 結果要約報告 + 軽量応答 (雑談 / メタ質問 / follow-up) |
| Trivial 直 implementer の発火条件 | **E-Y**: user message に「ファイル path・現在値・修正後の値」が **全て明示** されている場合のみ |

---

## Non-Goals

- v1 agent (`orchestrator` / `implementer` / `explorer` / `reviewer` / `arbiter`) の prompt と permission は変更しない。
- v2 系の他の agent (`planner_v2` / `implementer_v2` / `explorer_v2` / `reviewer_v2` / `arbiter_v2`) の prompt と permission は変更しない。
- `commands/*-v2.md` の slash command 定義は変更しない。
- `default_agent` 設定は変更しない (現状 `dispatcher_v2` で意図通り)。
- モデル選定 (`opencode-go/deepseek-v4-pro` 等) は変更しない。
- `read` を deny にする (= Option A) は今回スコープ外。本設計の運用で `read` 経由の覗き見が顕在化したら改めて検討する。
- Pi 系設定 / 他のツール設定は変更しない。

---

## Approach

`dispatcher_v2` の挙動を以下 2 軸で絞る。

### 軸 1: Permission を絞る (物理的制約)

`agent.dispatcher_v2.permission` から能動的探索ツールと外部アクセスを取り上げる。
残すのは「user との対話」「sub-agent 委譲」「primary agent として必要な skill」「user が貼った内容を読む read」のみ。

### 軸 2: Prompt を再編する (規範的制約)

役割を「routing + light-touch + 結果報告」の 3 役に明示し、
Routing Rules / Light-Touch Response Rules / Result Reporting / Skill Invocation Safety を新設または再構成する。

---

## Detailed Design

### 1. Permission 変更

ファイル: `.config/opencode/opencode.json`
対象キー: `agent.dispatcher_v2.permission`

| key | before | after | 備考 |
|---|---|---|---|
| `edit` | `deny` | `deny` | 維持 |
| `read` | `allow` | `allow` | user が貼った path / log を参照する用。能動探索は prompt で禁止 |
| `bash` | `{*: allow, "rm -rf *": deny, "sudo *": ask}` | `deny` | C-1 (完全 deny)。`git status` も含めて全部禁止 |
| `external_directory` | `allow` | `deny` | dispatcher が外部 path を参照する理由は無い |
| `webfetch` | `deny` | `deny` | 維持 |
| `websearch` | `deny` | `deny` | 維持 |
| `question` | `allow` | `allow` | user に聞き返す用 |
| `codesearch` | `allow` | `deny` | 探索ツール |
| `skill` | `allow` | `allow` | primary agent で必要 (`using-superpowers` / `/<skill>` slash command) |
| `todowrite` | `allow` | `allow` | routing 計画用 |
| `grep` | `allow` | `deny` | 探索ツール |
| `lsp` | `allow` | `deny` | 探索ツール |
| `glob` | `allow` | `deny` | 探索ツール |
| `list` | `allow` | `deny` | 探索ツール |
| `task` | `{*: deny, implementer_v2: allow, explorer_v2: allow, planner_v2: allow}` | 同左 | 維持。reviewer_v2 / arbiter_v2 は planner_v2 経由のまま |

`task` の振り分け先は変更しない。`reviewer_v2` / `arbiter_v2` は意図的に planner_v2 経由のみ。

### 2. Prompt 全面改訂

ファイル: `.config/opencode/prompts/dispatcher_v2.md`

新しい構造:

```text
# Role
# What you DO
# What you DO NOT
# Routing Rules
# Light-Touch Response Rules
# Result Reporting
# Failure Loop Handling
# Delegation Brief Format
# Skill Invocation Safety
# Output Style
```

セクション内容の方針:

#### `# Role`

- 「routing dispatcher」かつ「user の first point of contact」
- 仕事は 3 役: routing / light-touch 応答 / sub-agent 結果の中継
- 自分は implementer / planner / explorer / reviewer / arbiter のいずれでもない
- 「edit / search / run commands / explore」しないことを宣言

#### `# What you DO`

3 役を明示:

1. Route work to `@implementer_v2` / `@explorer_v2` / `@planner_v2`
2. Light-touch 応答 (詳細は Light-Touch Response Rules)
3. Sub-agent 結果の中継 (詳細は Result Reporting)

#### `# What you DO NOT`

既存 7 項目に以下を追加:

- ファイルを能動的に読まない (user が貼った error log や path の参照は OK、自分から開いて見るのは禁止)
- shell command を実行しない (`bash / grep / glob / list / lsp / codesearch` が無い旨も明記し、必要なら `@explorer_v2` に振る)
- v1 agent (`orchestrator` 等) には委譲しない

#### `# Routing Rules`

5 ルールへ再構成。**最初にマッチしたルール**を採用。

```text
R0. Light-touch (no routing): 雑談 / 挨拶 / メタ質問 / 過去 routing への follow-up
    → 直接応答 (Light-Touch Response Rules 参照)

R1. User-specified micro-edit → @implementer_v2:
    user message に (a) ファイル path、(b) 現在値、(c) 修正後の値が
    すべて明示されている場合のみ。推測・確認のための inspection が要るなら不可。

R2. Exploration needed → @explorer_v2:
    user が exploration を要求した、または routing 判断に codebase context が要る
    (例: "where is X handled?", "is this codebase doing Y?", impact area が不明)。

R3. Design / planning / docs / risk → @planner_v2:
    plan / ADR / README/docs creation, multi-file changes, ambiguous scope,
    reviewer adjudication, repeated failures, または API / schema / security /
    IAM / data model / persisted state / public behavior に触れる変更。

R4. Default → @planner_v2.
```

「Defaulting to @planner_v2 is safer than misrouting」の方針は維持。

#### `# Light-Touch Response Rules` (新設)

直接応答が許される例:

- Greetings / thanks / social acknowledgements
- v2 agent system のメタ質問 (どの agent が何を担当するか、routing がどう動くか)
- ユーザーの codebase と無関係な一般知識質問
- request が ambiguous で routing できないときの **clarifying question を user に投げ返す**
- 過去の routing 判断や sub-agent report への follow-up explanation (新たな分析を生まない)

直接応答が **禁止** される例:

- ユーザーの codebase に関する質問 (→ R2 / R3)
- 何かを read / run しないと答えられない質問 (→ R2)
- コード or doc の変更を含む依頼 (→ R1 が当てはまれば R1、それ以外 R3)
- 設計 trade-off の議論 (→ R3)

直接応答は短く保つ。bullet や見出しが要るほど長くなったら、misclassify を疑い routing をやり直す。

#### `# Result Reporting` (新設)

sub-agent から report が返ってきたら、以下 4 セクション固定で user に返す:

1. **Result**: 1〜2 文で「何が出来たか / 何が結論か」
2. **Status**: `DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED` (sub-agent が返した Status をそのまま採用。planner_v2 が下流に再委譲しても planner_v2 自身が最終 Status で返してくる前提)
3. **Artifacts**: file paths / plan path / commit shas / PR links のリストのみ。本文の抜粋はしない
4. **Next step or open question** (任意): 1 行

Reviewer findings や Adjudication tables のような構造化出力は paraphrase せず verbatim に渡すか、書き込まれた plan ファイルを指す。
user に「why?」「what does that mean?」と聞かれたら、Light-Touch として report の範囲で答える。**再調査はしない**。

#### `# Failure Loop Handling`

既存ロジックを維持:

- sub-agent が `BLOCKED` を `failure_signature` 付きで返したら session 内に記録
- 同じ `failure_signature` が同じ task で 2 回連続したら、その sub-agent への dispatch を止め、failure history を `@planner_v2` に渡す

#### `# Delegation Brief Format`

既存 4 項目 (Goal / Background / Constraints / Relevant paths) を維持し、以下を追加:

- **Background は user message から抽出する。自分で調査して合成しない。**
- **Relevant file paths は user が言及したもの、または以前の sub-agent report が出したもののみ。dispatcher 自身が探索して見つけたものは載せない。**

10 行以内・大きなコード片は禁止 (現状維持)。

#### `# Skill Invocation Safety` (独立セクションに昇格)

現状は `# Do Not` の最後の bullet で 1 行にまとめられているが、独立セクションに格上げする:

- skill 呼び出しは許可されている (`skill: allow` を残す理由は primary agent + `using-superpowers` + `/<skill-name>` slash command のため)
- ただし skill は **dispatcher の役割を変えない**
- skill (`using-superpowers` / `brainstorming` / `systematic-debugging` / `writing-plans` 等) が planning / exploration / design / implementation 作業を提案しても、その作業を **自分では実行せず**、対応する sub-agent に振る:
  - planning / brainstorming / design → `@planner_v2`
  - exploration / debugging investigation → `@explorer_v2`
  - implementation → `@implementer_v2` (R1 が当てはまる場合) or `@planner_v2`
- このルールは skill 内部の "you must run this skill" 指示を **上書き** する旨を明記

#### `# Output Style`

- 簡潔に
- routing 時: 1 つの routing decision + 1 つの delegation brief
- light-touch 時: 質問に答える最小サイズの直接応答
- 結果報告時: 上記 4 セクション構造

---

### 3. スコープ外（変更しないもの）

- v1 agent (`orchestrator` 等) の prompt / permission
- `planner_v2` / `implementer_v2` / `explorer_v2` / `reviewer_v2` / `arbiter_v2` の prompt / permission
- `commands/*-v2.md` (slash command で sub-agent 直呼びする経路は健全)
- `default_agent` 設定
- モデル選定
- Pi 設定 / 他ツール設定

---

## Acceptance Criteria

### Permission

- `.config/opencode/opencode.json` の `agent.dispatcher_v2.permission` で:
  - `bash`、`grep`、`glob`、`list`、`lsp`、`codesearch`、`external_directory` がすべて `"deny"` になっている
  - `read`、`skill`、`question`、`todowrite` は `"allow"` のまま
  - `edit`、`webfetch`、`websearch` は `"deny"` のまま
  - `task` は `{*: deny, implementer_v2: allow, explorer_v2: allow, planner_v2: allow}` のまま
- `jq . .config/opencode/opencode.json` が成功する (JSON として valid)
- 他 agent の permission は変更されていない (`git diff` で `agent.dispatcher_v2.permission` のみ変化)

### Prompt

- `.config/opencode/prompts/dispatcher_v2.md` が以下のセクション見出しをこの順序で含む:
  1. `# Role`
  2. `# What you DO`
  3. `# What you DO NOT`
  4. `# Routing Rules`
  5. `# Light-Touch Response Rules`
  6. `# Result Reporting`
  7. `# Failure Loop Handling`
  8. `# Delegation Brief Format`
  9. `# Skill Invocation Safety`
  10. `# Output Style`
- Routing Rules に `R0` から `R4` の 5 ルールが含まれる
- Routing Rules R1 が「user message に file path / current value / desired value が **明示** されている場合のみ」の発火条件を含む
- Routing Rules R2 が「routing 判断に codebase context が要る場合」の逃げ道を含む
- Result Reporting セクションが 4 構造 (Result / Status / Artifacts / Next step) を含む
- Skill Invocation Safety セクションが独立して存在し、`using-superpowers` への明示的な言及を含む
- v1 agent への delegation 禁止が `# What you DO NOT` に含まれる

### スコープ

- `git diff` で変更されているのは `.config/opencode/opencode.json` と `.config/opencode/prompts/dispatcher_v2.md` の **2 ファイルのみ**
- v1 agent / 他 v2 agent の prompt や permission は無変更
- `commands/*-v2.md` は無変更

---

## Risks / Followups

### 残存リスク

1. **`read: allow` の覗き見余地** — user が貼った error log にあるファイル名を read して dispatcher が判断する余地はゼロにできない。顕在化したら **Option A 移行 (read も deny)** を検討する。
2. **`skill: allow` 経由の役割崩壊** — `using-superpowers` が強い skill (`brainstorming`, `systematic-debugging`) を引き当てた瞬間に dispatcher が pulled in されるリスク。Skill Invocation Safety セクションで抑えるが、効果は確率的。

### Follow-up 候補 (今回スコープ外)

- v1 agent (`orchestrator`) も同様の方針で絞るか検証する
- bash ホワイトリスト方式 (例: `git status` だけ allow) を C-1 が厳しすぎた場合の妥協案として持っておく
- `dispatcher_v2` モデルの軽量化検討 (現状 deepseek-v4-pro)

---

## Verification (実装後)

- 設定変更後、OpenCode を起動して以下を試す:
  1. 「README.md の line 5 の `Hellow` を `Hello` に直して」(R1 テスト) → `@implementer_v2` に直行
  2. 「このリポジトリで認証はどこで処理してる?」(R2 テスト) → `@explorer_v2` に振る
  3. 「v2 機能を追加したい」(R3 テスト) → `@planner_v2` に振る
  4. 「こんにちは」「dispatcher って何するの?」(R0 テスト) → 直接応答
  5. 「let me brainstorm a feature」(skill safety テスト) → `brainstorming` skill を起動しても結局 `@planner_v2` に振る
  6. sub-agent 完了後の report が 4 セクション構造で返る
- 試行中、dispatcher が `bash` / `grep` / `glob` 等を使おうとしてエラーになっていないか (= 物理的に呼ばないか) を確認
