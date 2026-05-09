# OpenCode dotfiles 管理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `~/.config/opencode` の設定ファイルを dotfiles で管理し、`opencode.json` のハードコードパスをチルダパスに変更することで新マシンへの移植性を確保する。

**Architecture:** dotfiles リポジトリに `opencode/` 設定を追加し、`prompts/` と `commands/` はディレクトリシンボリックリンク、個別設定ファイルはファイルシンボリックリンクで `~/.config/opencode/` と接続する。`opencode.json` 内の絶対パスはすべてチルダパスに変更する。

**Tech Stack:** bash, ln, git, bun (plugin 依存管理), mise (bun のバージョン管理)

---

### Task 1: dotfiles に opencode ディレクトリを構成する

**Files:**
- Create: `dotfiles/.config/opencode/opencode.json`（パス変更済み版）
- Create: `dotfiles/.config/opencode/tui.json`
- Create: `dotfiles/.config/opencode/package.json`
- Create: `dotfiles/.config/opencode/bun.lock`
- Create: `dotfiles/.config/opencode/prompts/`（ディレクトリごとコピー）
- Create: `dotfiles/.config/opencode/commands/`（ディレクトリごとコピー）

作業ディレクトリ: worktree（`/Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2`）

- [ ] **Step 1: dotfiles 側のディレクトリを作成する**

```bash
mkdir -p /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2/.config/opencode
```

- [ ] **Step 2: opencode.json をコピーしつつ絶対パスをチルダパスに変換する**

```bash
sed 's|{file:/Users/haru256/.config/opencode/|{file:~/.config/opencode/|g' \
  ~/.config/opencode/opencode.json \
  > /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2/.config/opencode/opencode.json
```

- [ ] **Step 3: 変換結果を確認する（絶対パスが残っていないこと）**

```bash
grep -n "file:/" /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2/.config/opencode/opencode.json
```

期待値: 出力なし（0行）

- [ ] **Step 4: チルダパスが正しく入っていることを確認する**

```bash
grep "file:~" /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2/.config/opencode/opencode.json
```

期待値: 5行（orchestrator, implementer, explorer, reviewer, arbiter それぞれ1行）

- [ ] **Step 5: tui.json、package.json、bun.lock をコピーする**

```bash
cp ~/.config/opencode/tui.json \
   /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2/.config/opencode/
cp ~/.config/opencode/package.json \
   /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2/.config/opencode/
cp ~/.config/opencode/bun.lock \
   /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2/.config/opencode/
```

- [ ] **Step 6: prompts/ と commands/ ディレクトリをコピーする**

```bash
cp -r ~/.config/opencode/prompts \
      /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2/.config/opencode/
cp -r ~/.config/opencode/commands \
      /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2/.config/opencode/
```

- [ ] **Step 7: コピーされたファイルを確認する**

```bash
find /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2/.config/opencode \
  -not -path "*/node_modules/*" -type f | sort
```

期待値: opencode.json, tui.json, package.json, bun.lock, prompts/*.md (5ファイル), commands/*.md (2ファイル) が表示される

- [ ] **Step 8: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2
git add .config/opencode/
git commit -m "feat(opencode): dotfiles に opencode 設定を追加（チルダパス対応済み）"
```

---

### Task 2: ~/.config/opencode/ にシンボリックリンクを設定する

**Files:**
- Modify: `~/.config/opencode/opencode.json`（ファイル → シンボリックリンク）
- Modify: `~/.config/opencode/tui.json`（ファイル → シンボリックリンク）
- Modify: `~/.config/opencode/package.json`（ファイル → シンボリックリンク）
- Modify: `~/.config/opencode/bun.lock`（ファイル → シンボリックリンク）
- Modify: `~/.config/opencode/prompts/`（ディレクトリ → シンボリックリンク）
- Modify: `~/.config/opencode/commands/`（ディレクトリ → シンボリックリンク）

dotfiles の実体パス（main ブランチ）: `/Users/haru256/Documents/projects/dotfiles/.config/opencode/`

**注意:** worktree ブランチのファイルをシンボリックリンク先にしてはいけない。main ブランチにマージ後の `/Users/haru256/Documents/projects/dotfiles/.config/opencode/` を使う。このタスクはマージ後に実施するか、main ブランチを確認してから進めること。

- [ ] **Step 1: main ブランチに .config/opencode/ が存在するか確認する**

```bash
ls /Users/haru256/Documents/projects/dotfiles/.config/opencode/ 2>/dev/null || echo "NOT FOUND - worktree merge が必要です"
```

存在しない場合は、このタスクをスキップして Task 3 以降を進め、PR マージ後に実施する。

- [ ] **Step 2: 既存のファイルをシンボリックリンクに置き換える（ファイル単位）**

```bash
DOTFILES=/Users/haru256/Documents/projects/dotfiles

# 既存ファイルを削除してシンボリックリンクを作成
rm ~/.config/opencode/opencode.json
ln -s $DOTFILES/.config/opencode/opencode.json ~/.config/opencode/opencode.json

rm ~/.config/opencode/tui.json
ln -s $DOTFILES/.config/opencode/tui.json ~/.config/opencode/tui.json

rm ~/.config/opencode/package.json
ln -s $DOTFILES/.config/opencode/package.json ~/.config/opencode/package.json

rm ~/.config/opencode/bun.lock
ln -s $DOTFILES/.config/opencode/bun.lock ~/.config/opencode/bun.lock
```

- [ ] **Step 3: 既存ディレクトリをシンボリックリンクに置き換える**

```bash
DOTFILES=/Users/haru256/Documents/projects/dotfiles

rm -rf ~/.config/opencode/prompts
ln -s $DOTFILES/.config/opencode/prompts ~/.config/opencode/prompts

rm -rf ~/.config/opencode/commands
ln -s $DOTFILES/.config/opencode/commands ~/.config/opencode/commands
```

- [ ] **Step 4: シンボリックリンクを確認する**

```bash
ls -la ~/.config/opencode/ | grep -E "opencode.json|tui.json|package.json|bun.lock|prompts|commands"
```

期待値: 各エントリが `->` で dotfiles のパスを指していること

- [ ] **Step 5: opencode.json が正しく読めることを確認する**

```bash
grep "file:~" ~/.config/opencode/opencode.json
```

期待値: 5行（チルダパスが含まれている）

---

### Task 3: mise に bun を追加する

**Files:**
- Modify: `dotfiles/.config/mise/config.toml`（worktree 経由で編集）

- [ ] **Step 1: 現在の config.toml に bun がないことを確認する**

```bash
grep "bun" /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2/.config/mise/config.toml
```

期待値: 出力なし

- [ ] **Step 2: [tools] セクションに bun = "latest" を追加する**

`dotfiles/.config/mise/config.toml` の `[tools]` セクション末尾（`opencode = "latest"` の直後など）に追記する：

```toml
bun = "latest"
```

具体的には、以下の行の後に追記：
```
opencode = "latest"
```
↓
```
opencode = "latest"
bun = "latest"
```

- [ ] **Step 3: 追加されたことを確認する**

```bash
grep "bun" /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2/.config/mise/config.toml
```

期待値: `bun = "latest"`

- [ ] **Step 4: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2
git add .config/mise/config.toml
git commit -m "chore(mise): bun を追加"
```

---

### Task 4: README に OpenCode セットアップ手順を追記する

**Files:**
- Modify: `dotfiles/README.md`（worktree 経由で編集）

- [ ] **Step 1: 現在の README の Usage セクションを確認する**

```bash
grep -n "Usage\|ln -s" /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2/README.md | head -20
```

- [ ] **Step 2: README に OpenCode セクションを追加する**

既存の `ln -s` コマンド群の末尾に以下のブロックを追加する：

```markdown
### OpenCode

```sh
ln -s ~/dotfiles/.config/opencode/opencode.json ~/.config/opencode/opencode.json
ln -s ~/dotfiles/.config/opencode/tui.json      ~/.config/opencode/tui.json
ln -s ~/dotfiles/.config/opencode/package.json  ~/.config/opencode/package.json
ln -s ~/dotfiles/.config/opencode/bun.lock      ~/.config/opencode/bun.lock
ln -s ~/dotfiles/.config/opencode/prompts       ~/.config/opencode/prompts
ln -s ~/dotfiles/.config/opencode/commands      ~/.config/opencode/commands

# プラグインのインストール（bun が mise で管理されている前提）
cd ~/.config/opencode && bun install
```
```

- [ ] **Step 3: コミットする**

```bash
cd /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/charming-engelbart-9d50c2
git add README.md
git commit -m "docs: README に OpenCode セットアップ手順を追記"
```
