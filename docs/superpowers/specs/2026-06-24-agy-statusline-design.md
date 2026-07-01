# agy バランス型ステータスライン設計

## 目的

Antigravity CLI (`agy`) の TUI 下部に、通常の開発判断で必要な状態、Git、モデル、コンテキスト使用率、並列実行状況を一行で表示する。B（バランス型）を採用する。

## スコープ

- dotfiles で管理するステータスライン描画スクリプトと agy 設定を追加する。
- 状態は `idle`、`working`、`error` の3種に正規化する。
- agy が標準入力へ渡す状態 JSON のみを使用し、Git コマンドなどの追加プロセスは起動しない。

スコープ外は、利用量・課金残高の表示、テーマの選択 UI、既存の agy 権限設定やワークスペース信頼設定の変更である。

## 配置と設定

- `scripts/agy-statusline`: POSIX shell と `jq` による実行可能な描画スクリプト。
- `.gemini/antigravity-cli/settings.json`: `statusLine` 設定を追跡する dotfiles 側の設定ファイル。
- `README.md`: `~/.gemini/antigravity-cli/settings.json` へのシンボリックリンクと、スクリプトへの実行権限付与を追記する。

既存のホーム側 `settings.json` に含まれる値を保持した状態で、dotfiles 側へ移管する。シンボリックリンクの作成は利用者が README の手順に従って行う。実装時に既存ファイルを上書き・削除しない。

`statusLine.command` は、ホームディレクトリから解決できる `~/dotfiles/scripts/agy-statusline` を指定する。リポジトリの配置が異なる利用者は、README のリンク手順と同時にこのパスを自分のクローン先に更新する。

## 表示とデータフロー

agy は状態変化時に JSON をスクリプトの標準入力へ渡す。スクリプトは JSON を `jq` で検証・抽出し、ANSI カラー付きの一行を標準出力へ返す。

表示順は次のとおりとする。

```text
● working  main  ✚ dirty  Gemini 3.5 Flash  ctx [██░░░░░░░░] 18%  agents 2  tasks 1
```

- 状態: `agent_state` が `idle` なら `idle`、`thinking`・`working`・`tool_use`・`initializing` なら `working`。未知値、JSON不正、必須値の欠落時は `error`。
- Git: `vcs.branch` と `vcs.dirty`。VCS 情報またはブランチがない場合、この区間全体を省略する。
- モデル: `model.display_name` を表示し、空の場合は `model.id` を使用する。両方ない場合は `unknown`。
- コンテキスト: `context_window.used_percentage` を 0–100 に丸め、10セルのバーと整数パーセントを表示する。値がない場合は `ctx ?`。
- agents: `subagents` 配列の要素数。
- tasks: `background_tasks` 配列の要素数。

端末幅は `terminal_width` を使用して、次のように表示を縮小する。状態とコンテキスト表示は必ず残す。

- 100列以上: 全セグメントを表示する。
- 80–99列: agents と tasks を省略する。
- 60–79列: Git、agents、tasks を省略する。
- 59列以下: 状態とコンテキストだけを表示する。

## エラー処理

- `jq` が利用できない、または JSON の解析に失敗した場合、赤い `● error` を出力して終了ステータス 0 を返す。TUI の更新経路を壊さないことを優先する。
- 任意情報の欠落は、前述のフォールバックまたは該当セグメントの省略で扱う。
- スクリプトは入力 JSON・メールアドレス・会話IDなどの値を出力しない。

## 検証

代表入力を標準入力に渡すシェルテストを追加し、次を確認する。

- clean / dirty の Git 表示
- 3状態への正規化
- コンテキストバーの丸め
- subagents / background_tasks の件数
- VCS・任意フィールドの欠落
- 壊れた JSON と `jq` 失敗時の `error` 表示

設定 JSON は `jq empty` で構文確認し、スクリプトは `sh -n` と実入力で検証する。
