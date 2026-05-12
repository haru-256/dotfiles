# OpenCode GPT-5.5 Token Reduction: Second Opinion Brief

## Claude Code への依頼

このメモを前提に、`~/.config/opencode` のマルチエージェント設計についてセカンドオピニオンがほしい。

特に見てほしい点:

- GPT-5.5 Plus の利用 limit と token 使用量を削減する設計として妥当か
- `planner(brain): gpt-5.5 medium` と `dispatcher: deepseek-v4-flash` に役割分離する案がよいか
- もっと低リスクで効果の高い token 節約案があるか
- OpenCode の agent / prompt / command 設定として破綻しそうな点がないか

## 目的

OpenCode のマルチエージェント運用を維持しつつ、GPT-5.5 の使用量を大幅に減らす。

優先順位:

1. GPT-5.5 Plus limit 消費を減らす
2. 通常タスクの token 使用量を減らす
3. 実装品質、レビュー品質、設計判断の質を必要以上に落とさない
4. 既存の `orchestrator -> explorer / implementer / reviewer / arbiter` の運用思想はできるだけ保つ

## 課題

現在は OpenCode の通常入口が `orchestrator` で、`orchestrator` が `openai/gpt-5.5` を使っている。

そのため、軽い依頼、ルーティング、確認、簡単な調査開始などでも GPT-5.5 が起動しやすい。実装や探索を Kimi / DeepSeek に委譲していても、入口と司令塔の固定費として GPT-5.5 token を消費する。

解きたい問題は「実装 agent を安いモデルにする」だけではない。むしろ、GPT-5.5 を default path から外し、必要な判断のときだけ呼ぶ構造にしたい。

## 背景

現在の主な設定:

- `~/.config/opencode/AGENTS.md` は dotfiles の `.agents/AGENTS.md` への symlink
- OpenCode の `default_agent` は `orchestrator`
- `orchestrator`: `openai/gpt-5.5`, `reasoningEffort: medium`
- `implementer`: `opencode-go/kimi-k2.6`
- `explorer`: `opencode-go/deepseek-v4-pro`
- `reviewer`: `opencode-go/deepseek-v4-pro`, `reasoningEffort: max`
- `arbiter`: `openai/gpt-5.5`, `reasoningEffort: xhigh`

現在の prompt 上の責務:

- `orchestrator`: 目標確認、ルーティング、探索委譲、plan/ADR/docs 作成、実装委譲、reviewer findings の採否判断、failure loop 検出
- `implementer`: scoped implementation、テスト実行、失敗時の `failure_signature` 報告
- `explorer`: read-only deep repository exploration
- `reviewer`: read-only critical review、構造化 findings
- `arbiter`: last-resort consultation

補足:

- `opencode-delegation` skill / Codex から OpenCode worker を呼ぶ wrapper は今回の主経路ではない
  - 2026-05-12: プロジェクト内の `.agents/skills/opencode-delegation/` スキル定義は削除済み。
- 今回見たいのは `~/.config/opencode/AGENTS.md` と `~/.config/opencode/prompts/*.md` / `opencode.json` の OpenCode ネイティブな運用
- `opencode-go/deepseek-v4-flash` は利用可能モデルとして確認済み

## 選択肢

### Option A: 現状維持 + prompt 圧縮だけ

`default_agent = orchestrator` のまま、`orchestrator.md` や `reviewer.md`、`explorer.md` の出力量を削る。

メリット:

- 変更が小さい
- 既存運用が壊れにくい
- ルーティングや reviewer adjudication の品質を維持しやすい

デメリット:

- 通常入口が GPT-5.5 のままなので、limit 削減効果が限定的
- 軽いタスクでも GPT-5.5 が起動する構造は変わらない

評価:

- 低リスクだが、今回の主目的には弱い

### Option B: `orchestrator` を `deepseek-v4-flash` に置き換える

現在の `orchestrator` モデルだけを `opencode-go/deepseek-v4-flash` に変える。

メリット:

- 設定変更が最小
- GPT-5.5 の入口消費は一気に減る
- agent 数や command 構成を変えずに済む

デメリット:

- 現在の `orchestrator` は単なる dispatcher ではなく、plan 作成、ADR/docs 作成、reviewer findings の採否判断、failure loop 判断を持っている
- flash に設計判断や adjudication を任せすぎるリスクがある
- 品質低下が起きた場合、原因が「モデル変更」なのか「prompt 過負荷」なのか切り分けにくい

評価:

- token 節約効果は大きいが、設計判断の劣化リスクも大きい

### Option C: `dispatcher` を新設し、GPT-5.5 を `planner` に隔離する

`default_agent` を `dispatcher` に変更する。`dispatcher` は `opencode-go/deepseek-v4-flash` を使い、受付とルーティングだけを担当する。

`planner` は `openai/gpt-5.5`, `reasoningEffort: medium` として残し、現在の `orchestrator` の brain 部分を担当する。

想定:

- `dispatcher`: primary, `deepseek-v4-flash`, edit deny
- `planner`: subagent, `gpt-5.5 medium`, docs/ADR/plan のみ edit allow
- `implementer`: subagent, `kimi-k2.6`
- `explorer`: subagent, `deepseek-v4-pro`
- `reviewer`: subagent, `deepseek-v4-pro`
- `arbiter`: subagent, `gpt-5.5 xhigh`

`dispatcher` の役割:

- 軽い依頼は `@implementer` に直行
- どこを見るか不明なら `@explorer` に委譲
- plan / ADR / docs / reviewer adjudication / API・schema・security・IAM 判断は `@planner` に委譲
- escalation は `@planner` または `@arbiter` に回す
- 自分では計画や採否判断を書かない

メリット:

- GPT-5.5 を default path から外せる
- GPT-5.5 を「必要な判断だけ」に限定できる
- 現在の設計思想を保ちやすい
- 失敗時に「dispatcher のルーティング問題」と「planner の判断問題」を分けて分析できる

デメリット:

- agent が増える
- `orchestrator` という既存名との互換性をどう扱うか決める必要がある
- prompt / command / AGENTS.md の同期更新が必要
- dispatcher が planner を呼ぶ基準を曖昧にすると、品質か節約のどちらかに偏る

評価:

- 今回の目的に一番合う

### Option D: `explorer-lite` / `reviewer-lite` を追加する

`deepseek-v4-flash` の軽量 agent を追加し、浅い調査や小差分レビューだけを担当させる。

想定:

- `explorer-lite`: 候補ファイル、影響範囲、読むべきファイルの初期抽出だけ
- `reviewer-lite`: typo / docs / quick-fix / 小さい diff の obvious issue チェックだけ
- 深い探索や重大レビューは既存の `explorer` / `reviewer` に回す

メリット:

- DeepSeek Pro や GPT-5.5 の前段で token を減らせる
- 小さいタスクの固定費が下がる
- 既存の deep review path を残せる

デメリット:

- ルーティングが複雑になる
- lite と full の境界が曖昧だと二度手間になる
- GPT-5.5 節約効果は `dispatcher` 新設ほど直接的ではない

評価:

- Option C の次段階として有効

### Option E: command routing を強化する

`/quick-fix`, `/feature`, `/plan`, `/review-*` の agent 指定を見直し、軽いコマンドが GPT-5.5 に入らないようにする。

例:

- `/quick-fix`: `implementer` 直行を維持
- `/feature`: `dispatcher` に変更
- `/plan`: `planner` に直行
- `/adr`: `planner` に直行
- `/review-impl`: 既存 `reviewer`、または小差分用 `reviewer-lite`

メリット:

- ユーザーが明示コマンドを使う場合の token 節約効果が高い
- default agent 変更と組み合わせると効果が安定する

デメリット:

- コマンドを使わない通常入力には効きにくい
- AGENTS.md の運用説明も更新しないと迷いやすい

評価:

- Option C とセットで実施するとよい

## ベスト案

ベストは Option C を中心に、Option E を同時に行う案。

つまり、`default_agent` を `dispatcher: deepseek-v4-flash` に変更し、GPT-5.5 の `planner` を必要時だけ呼ぶ構成にする。

推奨構成:

```text
default_agent = dispatcher

dispatcher:
  model: opencode-go/deepseek-v4-flash
  mode: primary
  role: cheap routing only
  edit: deny
  task: implementer / explorer / reviewer / planner / arbiter(ask)

planner:
  model: openai/gpt-5.5
  reasoningEffort: medium
  mode: subagent
  role: planning, ADR/docs, review adjudication, design judgment
  edit: docs/**, README.md, ADRs/**, adr/**

implementer:
  model: opencode-go/kimi-k2.6
  mode: subagent
  role: scoped implementation

explorer:
  model: opencode-go/deepseek-v4-pro
  mode: subagent
  role: deep repository exploration

reviewer:
  model: opencode-go/deepseek-v4-pro
  reasoningEffort: max
  mode: subagent
  role: meaningful/risky review

arbiter:
  model: openai/gpt-5.5
  reasoningEffort: xhigh
  mode: subagent
  role: last resort only
```

## 推奨する段階的変更

### Phase 1: GPT-5.5 を default path から外す

- `dispatcher.md` を追加
- `planner.md` を追加し、現在の `orchestrator.md` の brain 責務を移す
- `opencode.json` に `dispatcher` と `planner` を追加
- `default_agent` を `dispatcher` に変更
- `/feature` を `dispatcher` に変更
- `/plan` と `/adr` を `planner` に変更
- `AGENTS.md` の通常入口説明を `dispatcher` に更新

この時点では `explorer-lite` / `reviewer-lite` は追加しない。

理由:

- まず GPT-5.5 の入口消費を止めるのが最重要
- agent を増やしすぎると検証範囲が広がる
- 節約効果と品質低下を観察しやすい

### Phase 2: 出力 token を削る

- `explorer.md` の `Exploration Log (no length cap)` を通常出力から外す
- `reviewer.md` の critical thinking findings は内部思考扱いに寄せ、出力は findings 中心にする
- `orchestrator/planner` の living-plan template 例を短縮する
- 各 agent に `textVerbosity: low` を追加できるなら追加する

### Phase 3: 必要なら lite agents を追加

- `explorer-lite: deepseek-v4-flash`
- `reviewer-lite: deepseek-v4-flash`

ただし、Phase 1 と Phase 2 の効果を見てからでよい。

## 判断基準

成功とみなす条件:

- 通常依頼で GPT-5.5 が起動しない
- plan / ADR / reviewer adjudication / API・schema・security 判断では GPT-5.5 が呼ばれる
- quick fix は `implementer` へ直行できる
- non-trivial feature は `dispatcher -> explorer -> planner -> implementer -> reviewer` のように必要なときだけ重い agent を使う
- reviewer findings の ACCEPT / REJECT / DEFER 判断を flash に任せない

避けたい失敗:

- `dispatcher` が設計判断までしてしまう
- `planner` を呼ぶ条件が広すぎて GPT-5.5 節約にならない
- `planner` を呼ぶ条件が狭すぎて品質が落ちる
- lite agent を増やしすぎて二度読み・二度レビューが増える
- `AGENTS.md`, `commands/*.md`, `prompts/*.md`, `opencode.json` の説明が食い違う

## Claude Code に聞きたい具体質問

1. `dispatcher` を default agent にし、`planner` を GPT-5.5 subagent にする構成は OpenCode の agent model として自然か。
2. 既存の `orchestrator` 名は残すべきか、`planner` にリネームすべきか。互換性と明確さのどちらを優先すべきか。
3. `dispatcher` の prompt はどこまで具体化すべきか。ルーティング表を細かく書くほど token は増えるが、誤委譲は減る。
4. `reviewer` の `deepseek-v4-pro + reasoningEffort=max` は維持すべきか。小差分だけ `reviewer-lite` を追加する価値はあるか。
5. `explorer.md` の詳細ログを通常出力から外す変更は、後続 agent の品質低下につながるか。
6. Phase 1 の最小変更セットとして不足しているファイルはあるか。
