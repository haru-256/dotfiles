# Design: ~/.config/opencode を dotfiles で管理する

**Date:** 2026-05-09

## 概要

`~/.config/opencode` 以下の設定ファイルを dotfiles リポジトリで管理し、新マシンでのセットアップを再現可能にする。
合わせて `opencode.json` 内のハードコードされた絶対パスをチルダパスに変更してポータビリティを確保する。

---

## 管理対象ファイル

### dotfiles に追加するファイル

| ファイル | リンク種別 | 説明 |
|---------|-----------|------|
| `opencode.json` | ファイルシンボリックリンク | エージェント定義・パーミッション・MCP設定 |
| `tui.json` | ファイルシンボリックリンク | テーマ設定（catppuccin-latte） |
| `package.json` | ファイルシンボリックリンク | プラグイン依存関係 |
| `bun.lock` | ファイルシンボリックリンク | 依存の再現性確保 |
| `prompts/` | ディレクトリシンボリックリンク | 5エージェント分のプロンプトファイル |
| `commands/` | ディレクトリシンボリックリンク | カスタムコマンド |

### dotfiles に追加しないもの

| ファイル | 理由 |
|---------|------|
| `.gitignore` | `package.json` / `bun.lock` を除外しており、dotfiles に持ち込むと追跡できなくなる |
| `node_modules/` | 生成物 |
| `*.bak` / `*.before-*` | 作業バックアップ、不要 |

---

## opencode.json のパス変更

各エージェントの `prompt` フィールドに含まれる絶対パスをチルダパスに変更する。

**変更前:**
```json
"prompt": "{file:/Users/haru256/.config/opencode/prompts/orchestrator.md}"
```

**変更後:**
```json
"prompt": "{file:~/.config/opencode/prompts/orchestrator.md}"
```

対象エージェント: `orchestrator`, `implementer`, `explorer`, `reviewer`, `arbiter`（計5箇所）

OpenCode はチルダ展開（`~/` → `$HOME/`）をサポートしていることを確認済み。

---

## dotfiles のディレクトリ構造

```
dotfiles/.config/opencode/
├── opencode.json
├── tui.json
├── package.json
├── bun.lock
├── prompts/
│   ├── orchestrator.md
│   ├── implementer.md
│   ├── explorer.md
│   ├── reviewer.md
│   └── arbiter.md
└── commands/
    ├── feature.md
    └── quick-fix.md
```

---

## シンボリックリンク構成

```sh
DOTFILES=~/Documents/projects/dotfiles

# ファイル単位
ln -s $DOTFILES/.config/opencode/opencode.json ~/.config/opencode/opencode.json
ln -s $DOTFILES/.config/opencode/tui.json      ~/.config/opencode/tui.json
ln -s $DOTFILES/.config/opencode/package.json  ~/.config/opencode/package.json
ln -s $DOTFILES/.config/opencode/bun.lock      ~/.config/opencode/bun.lock

# ディレクトリ単位（既存ディレクトリは削除してからリンク）
rm -rf ~/.config/opencode/prompts
ln -s $DOTFILES/.config/opencode/prompts   ~/.config/opencode/prompts
rm -rf ~/.config/opencode/commands
ln -s $DOTFILES/.config/opencode/commands  ~/.config/opencode/commands
```

---

## mise に bun を追加

`dotfiles/.config/mise/config.toml` の `[tools]` セクションに追記：

```toml
bun = "latest"
```

---

## README へのセットアップ手順追記

README の `## Usage` セクションに OpenCode セクションを追加する：

```markdown
### OpenCode

ln -s ~/dotfiles/.config/opencode/opencode.json ~/.config/opencode/opencode.json
ln -s ~/dotfiles/.config/opencode/tui.json      ~/.config/opencode/tui.json
ln -s ~/dotfiles/.config/opencode/package.json  ~/.config/opencode/package.json
ln -s ~/dotfiles/.config/opencode/bun.lock      ~/.config/opencode/bun.lock
ln -s ~/dotfiles/.config/opencode/prompts       ~/.config/opencode/prompts
ln -s ~/dotfiles/.config/opencode/commands      ~/.config/opencode/commands

# プラグインのインストール
cd ~/.config/opencode && bun install
```

---

## 作業ステップ（実装計画に渡す）

1. `opencode.json` の絶対パス5箇所をチルダパスに変更
2. `dotfiles/.config/opencode/` ディレクトリを作成し、管理対象ファイルをコピー
3. `~/.config/opencode/` の既存ファイル/ディレクトリをシンボリックリンクに置き換える
4. `dotfiles/.config/mise/config.toml` に `bun = "latest"` を追加
5. `dotfiles/README.md` に OpenCode セットアップ手順を追記
6. 動作確認（OpenCode が起動し、エージェントが正しくプロンプトを読み込む）
