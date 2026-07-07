# Claude Code statusline 設計

## 目的

Claude Code CLI の TUI 下部に、モデル・作業ディレクトリ・Git・コンテキスト使用率・コスト・推論強度・利用量上限を一行で表示する。既存の `scripts/agy-statusline`（Antigravity CLI）・`scripts/cursor-statusline`（Cursor CLI）と同じ設計規約に従う。

## スコープ

- dotfiles で管理するステータスライン描画スクリプトを追加する。
- Claude Code の statusLine JSON（stdin）と `$COLUMNS` 環境変数のみを入力とする。Git 情報は JSON に含まれないため `git` コマンドを実行する（`cursor-statusline` と同じ手法）。
- 配色は Catppuccin Latte の truecolor（`cursor-statusline` と同一パレット）。

スコープ外は、`~/.claude/settings.json` 全体の dotfiles 管理化、テーマ選択 UI、vim mode・PR 状態・session_id の表示である。

## 配置と設定

- `scripts/claude-statusline`: POSIX shell と `jq` による実行可能な描画スクリプト。
- `tests/claude-statusline.sh`: 代表入力を標準入力に渡すシェルテスト。
- `README.md`: `### Claude Code` セクションを追加し、シンボリックリンク手順と `~/.claude/settings.json` への追記スニペットを記載する。

`~/.claude/settings.json` は `hooks`・`enabledPlugins`・`effortLevel`・`theme` など既存の個人設定を含むため、ファイル全体はシンボリックリンクしない（`cursor-statusline` における `~/.cursor/cli-config.json` と同じ扱い）。スクリプトのみを次のようにリンクする。

```sh
ln -s ~/dotfiles/scripts/claude-statusline ~/.claude/statusline.sh
chmod +x ~/dotfiles/scripts/claude-statusline
```

利用者は既存の `~/.claude/settings.json` に次のブロックを追記する（ファイル全体の上書きは行わない）。

```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline.sh",
  "padding": 2
}
```

リポジトリのクローン先が `~/dotfiles` と異なる場合は、symlink 元パスを実際のパスに置き換える。

## 表示とデータフロー

Claude Code は statusLine 更新時に JSON を標準入力へ渡し、端末幅を `$COLUMNS` 環境変数で渡す（Claude Code v2.1.153 以上）。スクリプトは `jq` で JSON を検証・抽出し、`$COLUMNS` を読んで ANSI truecolor 付きの一行を標準出力へ返す。

表示例（100 列以上）：

```text
Sonnet 5 | dotfiles main +2 | ctx [███░░░░░░░] 32% | $0.42 12m | effort high | 5h 18%
```

セグメントと閾値：

- 常時表示:
  - モデル: `model.display_name`。空なら `model.id`。両方なければ `unknown`。青。
  - コンテキスト: `context_window.used_percentage` を 0–100 に丸め、10 セルのバーと整数パーセントを表示。値がなければ `ctx ?`。マゼンタ（mauve）。
- `$COLUMNS` ≥ 60: ディレクトリ/worktree ラベル。`workspace.git_worktree` があればそれを使用し、なければ `workspace.current_dir`（なければ `workspace.project_dir`）の basename。teal。
- `$COLUMNS` ≥ 70: Git。ディレクトリ/worktree ラベルと同じディレクトリ（`workspace.current_dir`、なければ `workspace.project_dir`）で `git rev-parse --git-dir` が成功する場合のみ、`git branch --show-current`（空なら `git rev-parse --short HEAD`）と `git status --porcelain` の行数を表示。0 件なら緑 `<branch> clean`、1 件以上なら黄 `<branch> +<count>`。Git リポジトリでなければこの区間を省略する。
- `$COLUMNS` ≥ 90: コスト。`cost.total_cost_usd` を `$X.XX` に整形し、`cost.total_duration_ms` をミリ秒から分に変換して `<n>m` として並べる。いずれかが欠落・非数値ならこの区間を省略する。peach。
- `$COLUMNS` ≥ 100: 推論強度。`effort.level`（`low`/`medium`/`high`/`xhigh`/`max`）をそのまま表示。欠落時は区間を省略する。lavender。
- `$COLUMNS` ≥ 110: 利用量上限。`rate_limits.five_hour.used_percentage` と `rate_limits.seven_day.used_percentage` のうち大きい方を採用し、対応するラベル（`5h`/`7d`）とパーセントを表示。フィールド自体が存在しない場合（Claude.ai Pro/Max 未加入、または最初の API 応答前）はこの区間を省略する。使用率 90% 以上は赤、70–89% は黄、69% 以下は緑。

`$COLUMNS` が未設定または数値として解釈できない場合は 80 として扱う（コンテキストとモデルに加え、dir/worktree と Git までが表示される安全側のデフォルト）。

## エラー処理

- `jq` が利用できない、または JSON の解析に失敗した場合、赤い `● claude statusline error` を出力して終了ステータス 0 を返す。TUI の更新経路を壊さないことを優先する。
- 任意情報（dir/worktree、Git、コスト、推論強度、利用量上限）の欠落は、該当セグメントの省略で扱う。コンテキストのみ既存規約に合わせて `ctx ?` を表示する。
- スクリプトは入力 JSON の値（cwd の絶対パス以外の個人情報、session_id、pr 情報など）を出力に含めない。

## 検証

代表入力を標準入力に渡すシェルテスト（`tests/claude-statusline.sh`）を追加し、次を確認する。

- clean / dirty の Git 表示、および Git リポジトリでない場合の省略
- コンテキストバーの丸めと欠落時の `ctx ?`
- コストと実行時間の整形、および欠落時の省略
- 推論強度の表示と欠落時の省略
- 利用量上限（five_hour / seven_day のうち大きい方の選択、閾値による色分け）と欠落時の省略
- `$COLUMNS` 閾値ごとのセグメント表示・省略（59 / 60 / 70 / 90 / 100 / 110 列相当）
- 壊れた JSON と `jq` 失敗時の `error` 表示

スクリプトは `sh -n` と実入力で検証する。
