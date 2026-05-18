# opencode v2 — explorer_v2 への委譲を徹底させる設計

**Date**: 2026-05-15
**Scope**: `.config/opencode/prompts/dispatcher_v2.md`, `.config/opencode/prompts/planner_v2.md`, `.config/opencode/prompts/explorer_v2.md`
**Non-scope**: `opencode.json` (permission), 他エージェント prompt, v1 系

## 背景と問題

現状の v2 エージェント運用で次の動きが観測されている。

1. `dispatcher_v2` が「調査して実装」「修正してほしい」系の依頼を、R2 ルールに従って `@planner_v2` に直送する。
2. `@planner_v2` は本来 `@explorer_v2` に repo 探索を委譲すべきだが、自前で `grep` / `read` / `glob` などを使って修正ポイントを探してしまうことがある。
3. ライブラリの使い方や論文実装の調査などの外部リサーチは、現状 `explorer_v2` のスコープに明示されておらず、`planner_v2` が自分で `websearch`/`webfetch` を呼びがち。

結果として:
- `planner_v2` の context が探索ノイズで膨れる
- 探索の専門性（progressive deepening、`rg` 優先、不要ファイル除外）が活かされない
- どこで何が調べられたかが分散して可観測性が落ちる

## ゴール

- `dispatcher_v2` がコード変更を伴う依頼を受けたら、計画前に必ず `@explorer_v2` を呼んで修正候補ファイルを洗い出す。
- `@planner_v2` が修正ポイント特定・追加情報取得のために自前で探索しないようにする（discovery 系 tool と external 系 tool は `@explorer_v2` 経由を強制）。
- `@explorer_v2` のスコープを正式に拡張し、リポジトリ探索だけでなくライブラリ・論文・外部仕様の調査も担当する。

## Non-goals

- `opencode.json` の `permission` 変更は行わない。OpenCode の subagent は親セッションを ceiling として permission を継承する仕様のため、`planner_v2` の権限を絞ると配下の `explorer_v2`/`implementer_v2` も道連れに動けなくなる。よって強制は prompt-only。
- v1 系（`orchestrator`/`explorer`/`implementer`/`reviewer`）は対象外。
- `@reviewer_v2` / `@oracle_v2` / `@implementer_v2` の責務には触らない。
- 既存の Reviewer 裁定ワークフロー、失敗ループ処理、ADR/README 出力規約は変更しない。

## 設計

### A. dispatcher_v2 のルーティングルール

現状の R2 を `R2a` / `R2b` に分割し、R3 のスコープを拡張する。

| ルール | 条件 | 振り先 |
|---|---|---|
| R0 | Light-touch（greeting / メタ質問 / 一般知識 / 確認質問 / 直前 report への follow-up） | 直接応答 |
| R1 | user-specified micro-edit（file path・現在値・希望値の3つ全部明示） | `@implementer_v2` 直送 |
| **R2a** | コード変更を伴う owner work（実装、バグ修正、リファクタ、"investigate and fix"、複数ファイル変更、API/スキーマ/セキュリティ/IAM/データモデル/永続状態/公開挙動に触れる依頼など） | `@explorer_v2` → `@planner_v2` の二段送り |
| **R2b** | コード調査が不要な owner work（reviewer 裁定 / docs・ADR・README 単独更新 / 失敗ループ転送 / 純粋な設計議論） | `@planner_v2` 直送 |
| **R3** | 純粋探索 — リポ理解、ライブラリ使い方、論文・外部仕様調査（計画・実装・裁定・ファイル変更を伴わない） | `@explorer_v2` 直送 |
| R4 | 既定（迷ったとき） | `@planner_v2` |

#### R2a の二段送り手順

dispatcher_v2 は同一ターン内で以下を順に行う:

1. `@explorer_v2` を Repo Mode で呼ぶ。Brief には Goal / Background / Constraints / 関連パス（user 明示分のみ）/ Mode: Repo を含める。
2. `@explorer_v2` の Summary Report を受け取る。
3. `@planner_v2` を呼ぶ。Brief には user の Goal + `@explorer_v2` の Summary Report 全文 + Mode hint を含める。Exploration Log は path 参照のみ（添付不要）。
4. `@planner_v2` の Result Reporting だけをユーザーに返す。`@explorer_v2` の中間レポートは relay しない（planner_v2 に渡れば足りる）。

トリガーの判定:
- 「コード変更が含まれる、または計画段階で修正対象ファイルの洗い出しが必要」が R2a。
- ソースコードに触れる必要が無い owner work は R2b。
- 迷ったら R4 へ落とす（`@planner_v2` が自身で R2a 相当の二段段を実行する形になる）。

#### R3 拡張

現状 "read-only repository understanding" に限定されている R3 を、「ユーザーが知りたいだけで計画・実装・裁定・ファイル変更を伴わない調査」全般に拡張する。リポジトリ探索・ライブラリ使い方・論文/外部仕様の調査がすべて含まれる。

#### dispatcher_v2 prompt の他セクション

- `What you DO NOT` の文言は維持（自分で探索しない、edit しない、等）。
- `Result Reporting` 構造は維持。R2a の場合は planner_v2 のレポート1本だけ relay する旨を明記。
- `Delegation Brief Format` に Mode hint 行を追加（Mode: Repo / External / Hybrid）。
- `Skill Invocation Safety` は維持。

### B. planner_v2 の規律（prompt-only 強制）

#### 追加する "What you DO NOT" セクション

```
# What you DO NOT
- Do not use grep, glob, list, codesearch, lsp, or bash for code search / file discovery.
  These are exploration. Delegate to @explorer_v2 (Repo Mode).
- Do not use webfetch, websearch, or context7 for library docs or paper research.
  Delegate to @explorer_v2 (External Research Mode).
- Do not edit source code or tests.
- Do not call @reviewer_v2 / @oracle_v2 outside the documented workflow patterns.
```

#### 追加する "What you MAY read directly" セクション

```
# What you MAY read directly
- Files the user or @explorer_v2 explicitly pointed to (paths in the brief or in an exploration report).
- docs/**, README.md, ADRs/**, adr/**, and existing plans under docs/superpowers/plans/.
- Reading files for "what does this look like now" is OK only when the path is already known.
  Discovering paths is exploration → @explorer_v2.
```

#### Responsibilities の差し替え

現状の以下を:

```
- decide whether repository exploration is needed
- delegate repository exploration to @explorer_v2
```

次に置き換える:

```
- Before proposing a plan or design that involves source code, you MUST have an
  @explorer_v2 Repo Mode report on hand. If dispatcher_v2 already attached one
  (R2a path), use it; otherwise call @explorer_v2 first.
- Before relying on external library APIs or paper-derived algorithms in a plan,
  you MUST have an @explorer_v2 External Research Mode report on hand.
- When in doubt about scope, dispatch @explorer_v2 rather than reading files yourself.
```

#### Skill Invocation Safety 句

dispatcher_v2 と同趣旨の句を追加。skill（例: `systematic-debugging`）が「ファイル探索しろ」と指示した場合、自分でやらず `@explorer_v2` に振り直す。具体的には:

- exploration / debugging investigation → `@explorer_v2`
- library / paper research → `@explorer_v2` (External Research Mode)
- implementation → `@implementer_v2`

このルールは skill 内部の「必ず invoke せよ」指示より優先する。

#### Workflow Patterns / Delegation Format / Token Policy / Failure Detection / Review Adjudication

これらのセクションは変更しない。Workflow Patterns の `@explorer_v2 -> write plan -> @implementer_v2 -> @reviewer_v2 -> adjudicate` という記述は新ルールと整合する。

### C. explorer_v2 の二モード設計

#### Role 句に二モードを明記

```
# Role
You are the v2 read-only deep exploration agent.
You operate in two modes; pick based on the brief, or run Hybrid if both apply.

## Mode A: Repo Mode (existing default)
Repository understanding — files, modules, call graphs, data flow, tests.
Tools: rg, git grep, git ls-files, focused file reads, existing tests/docs/ADRs.

## Mode B: External Research Mode
External knowledge — library usage, framework patterns, paper implementations,
public API docs, version-specific behavior.
Tools: webfetch, websearch, context7 MCP.
You must cite sources (URL + retrieval date) for every claim.

## Mode H: Hybrid
When a task spans both (e.g., "find where we use tokio AND check latest tokio docs"),
run Mode A then Mode B and combine reports under one Summary.
```

#### モード選択

- Brief に `Mode: Repo | External | Hybrid` が含まれている場合はそれに従う（dispatcher_v2 / planner_v2 が明示する想定）。
- 無指定なら brief 内容から推論する。リポジトリ理解が中心なら Repo、ライブラリ/論文/外部仕様が中心なら External、両方なら Hybrid。

#### 出力フォーマット

**Mode A (Repo Mode)**: 現状の `Summary Report + Exploration Log` を維持。
1. Relevant files
2. Key findings (3-7 bullets)
3. Likely change points
4. Tests likely affected
5. Risks and hidden coupling
6. Suggested implementation slice
7. What `@implementer_v2` should avoid
8. Pointer to Exploration Log

**Mode B (External Research Mode)**: 新フォーマット。

```
## Part 1: Research Brief (target: under 1500 tokens)
1. Topic and scope (one sentence)
2. Key findings (3-7 bullets, each ending with [source-id])
3. Recommended approach / canonical pattern (if consensus exists)
4. Caveats / gotchas / version-specific concerns
5. Applicability to current codebase (only if codebase context was in the brief)
6. Open questions for follow-up
7. Pointer: "See Research Log below for sources and detail"

## Part 2: Research Log (no length cap)
- Sources: [source-id] | URL | retrieval date | one-line role
- Per-source notes: short quotes (under 30 lines each), key claims
- Cross-source synthesis
- Disagreements between sources
- Open questions
```

**Mode H (Hybrid)**: Summary Report と Research Brief を両方出し、先頭に `This task spans both modes` の一行を添える。Exploration Log と Research Log は別々に出す。

#### 出力ポリシー

- Repo Mode: Summary は短く、Exploration Log にはコード断片可（30 行以内）。
- External Research Mode: 引用は短く（30 行以内）、URL と retrieval date 必須。
- Hybrid Mode: 各 Part の上限はそれぞれの mode と同じ。

#### 既存の禁止事項は据え置き

- 編集不可
- 計画書かない、ADR書かない
- 他エージェントに委譲しない

### D. Delegation Brief フォーマットの拡張

dispatcher_v2 と planner_v2 が `@explorer_v2` を呼ぶときの Brief に `Mode:` 行を追加する。例:

```
Goal: 認証ミドルウェアの構造を理解
Background: ユーザーから「JWT 検証を新しいスキーマに置き換えたい」
Constraints: src/auth/** 配下のみ
Mode: Repo
```

無指定の場合 `explorer_v2` が推論するが、明示が望ましい。

## ロールアウト

prompt 編集だけなので段階的展開は不要。次の順で 1 PR で適用する想定:

1. `explorer_v2.md` を更新（二モード対応）。
2. `planner_v2.md` を更新（規律強化）。
3. `dispatcher_v2.md` を更新（R2 分割、R3 拡張、二段送り手順）。

順序は逆方向の依存（dispatcher_v2 が新 R2a を発火しても planner_v2/explorer_v2 が未更新なら旧挙動）を避けるための下流先行。

## 失敗モードと緩和

| 失敗モード | 緩和策 |
|---|---|
| dispatcher_v2 が R2a/R2b の判定を誤る | R4（既定 = `@planner_v2`）に落ちる。planner_v2 側でも explorer_v2 を強制するので最終的に補正される。 |
| planner_v2 が `What you DO NOT` を無視して直接 grep | prompt の文言を強い表現にする。それでも繰り返す場合は別途経過観察し、empirical-prompt-tuning で改善。 |
| explorer_v2 が Mode を誤判定 | Brief 側で明示する運用にする。誤判定時は呼び出し元が再呼び出しできる。 |
| dispatcher_v2 が二段送りで context を肥大化 | Exploration Log は planner_v2 に添付せず path 参照のみ。Summary Report のみを引き渡す。 |
| 簡単な修正でも R2a に倒れて余計な explorer_v2 呼び出しが入る | R1 (micro-edit) はそのまま機能。R2a の判定文に「scope が極端に明確で 1 ファイルの 1 箇所と分かっている場合は R4 経由で planner_v2 直送も可」と但し書きはしない（過剰最適化を避ける）。 |

## 検証

prompt 編集のため自動テストは無い。次の手動確認シナリオで挙動を確認する:

1. **R2a 発火**: 「`src/auth` の認証ロジックをリファクタしたい」→ dispatcher_v2 が `@explorer_v2` → `@planner_v2` の順で呼ぶこと。Result Reporting には planner_v2 のレポートだけが現れること。
2. **R2b 直送**: 「reviewer_v2 が出した F2 の裁定をしてほしい」→ dispatcher_v2 が `@planner_v2` だけを呼ぶこと。
3. **R3 拡張（外部）**: 「tokio の新しい spawn API の使い方を教えて」→ dispatcher_v2 が `@explorer_v2` を External Research Mode で呼ぶこと。
4. **planner_v2 の規律**: planner_v2 がコード探索を要する状況で `@explorer_v2` を呼び、自身で grep を打たないこと。
5. **planner_v2 の外部調査**: planner_v2 が plan 内でライブラリ API を引用する必要があるとき、`@explorer_v2 (External Research Mode)` を呼ぶこと。
6. **Hybrid Mode**: 「現リポでの tokio 利用箇所を洗い出し、最新 tokio docs と照合して」→ explorer_v2 が Hybrid を選び Summary Report と Research Brief を両方出すこと。

## Open Questions

なし（設計合意済み）。
