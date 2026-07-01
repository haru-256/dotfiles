# agy バランス型ステータスライン Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** agy の TUI に、状態・Git・モデル・コンテキスト・並列処理数を表示するバランス型ステータスラインを追加する。

**Architecture:** `scripts/agy-statusline` は agy が標準入力へ渡す JSON を `jq` で抽出し、ANSI カラー付きの一行を標準出力へ返す。agy の `statusLine.command` は dotfiles に追跡された同スクリプトを指し、ホームの設定ファイルは dotfiles 内の `.gemini` ディレクトリへのシンボリックリンクで提供する。

**Tech Stack:** POSIX shell (`sh`)、`jq`、agy statusLine JSON、Git。

---

## File structure

- Create: `scripts/agy-statusline` — JSON を一行の ANSI ステータス表示へ変換する実行スクリプト。
- Create: `tests/agy-statusline.sh` — 入力ケースごとにスクリプトの出力を検証する POSIX shell テスト。
- Create: `.gemini/antigravity-cli/settings.json` — 現在の agy 設定を保ったまま `statusLine` を有効化する dotfiles 管理設定。
- Modify: `README.md` — agy 設定とスクリプトのリンク手順を追加する。

### Task 1: ステータスラインの失敗テストを追加する

**Files:**
- Create: `tests/agy-statusline.sh`
- Test: `tests/agy-statusline.sh`

- [ ] **Step 1: テストスクリプトを作成する**

```sh
#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/scripts/agy-statusline"

fail() {
  printf '%s\n' "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  haystack=$1
  needle=$2
  case $haystack in
    *"$needle"*) ;;
    *) fail "expected [$needle] in [$haystack]" ;;
  esac
}

strip_ansi() {
  esc=$(printf '\033')
  sed "s/${esc}\\[[0-9;]*m//g"
}

clean_output=$(cat <<'JSON' | "$SCRIPT" | strip_ansi
{
  "agent_state": "idle",
  "terminal_width": 120,
  "vcs": {"branch": "main", "dirty": false},
  "model": {"display_name": "Gemini 3.5 Flash", "id": "gemini"},
  "context_window": {"used_percentage": 18.4},
  "subagents": [{"name": "reviewer"}],
  "background_tasks": [{"name": "test"}]
}
JSON
)
assert_contains "$clean_output" "idle"
assert_contains "$clean_output" "main"
assert_contains "$clean_output" "clean"
assert_contains "$clean_output" "Gemini 3.5 Flash"
assert_contains "$clean_output" "ctx [██░░░░░░░░] 18%"
assert_contains "$clean_output" "agents 1"
assert_contains "$clean_output" "tasks 1"

working_output=$(cat <<'JSON' | "$SCRIPT" | strip_ansi
{
  "agent_state": "tool_use",
  "terminal_width": 120,
  "vcs": {"branch": "feature/status", "dirty": true},
  "model": {"id": "gemini"},
  "context_window": {"used_percentage": 105},
  "subagents": [],
  "background_tasks": []
}
JSON
)
assert_contains "$working_output" "working"
assert_contains "$working_output" "feature/status"
assert_contains "$working_output" "dirty"
assert_contains "$working_output" "gemini"
assert_contains "$working_output" "ctx [██████████] 100%"

narrow_output=$(cat <<'JSON' | "$SCRIPT" | strip_ansi
{
  "agent_state": "thinking",
  "terminal_width": 59,
  "vcs": {"branch": "main", "dirty": true},
  "model": {"display_name": "Gemini"},
  "context_window": {"used_percentage": 8},
  "subagents": [{"name": "worker"}],
  "background_tasks": [{"name": "test"}]
}
JSON
)
assert_contains "$narrow_output" "working"
assert_contains "$narrow_output" "ctx [█░░░░░░░░░] 8%"
case $narrow_output in
  *main*|*Gemini*|*agents*|*tasks*) fail "narrow layout retained optional fields" ;;
esac

missing_vcs_output=$(cat <<'JSON' | "$SCRIPT" | strip_ansi
{
  "agent_state": "working",
  "terminal_width": 80,
  "model": {},
  "context_window": {},
  "subagents": null,
  "background_tasks": null
}
JSON
)
assert_contains "$missing_vcs_output" "working"
assert_contains "$missing_vcs_output" "unknown"
assert_contains "$missing_vcs_output" "ctx ?"

invalid_output=$(printf '{invalid' | "$SCRIPT" | strip_ansi)
assert_contains "$invalid_output" "error"

printf '%s\n' "PASS: agy statusline"
```

- [ ] **Step 2: 失敗することを確認する**

Run: `sh tests/agy-statusline.sh`

Expected: FAIL。`scripts/agy-statusline` がまだ存在しないため、シェルがファイルを実行できない。

### Task 2: JSON 描画スクリプトを実装する

**Files:**
- Create: `scripts/agy-statusline`
- Test: `tests/agy-statusline.sh`

- [ ] **Step 1: ステータスラインスクリプトを作成し、実行可能にする**

```sh
#!/bin/sh
set -u

red='\033[31m'
green='\033[32m'
blue='\033[34m'
purple='\033[35m'
reset='\033[0m'

error() {
  printf '%b\n' "${red}● error${reset}"
  exit 0
}

command -v jq >/dev/null 2>&1 || error
payload=$(cat) || error
printf '%s' "$payload" | jq -e . >/dev/null 2>&1 || error

state=$(printf '%s' "$payload" | jq -r '.agent_state // empty')
case $state in
  idle)
    state_label=idle
    state_color=$purple
    ;;
  thinking|working|tool_use|initializing)
    state_label=working
    state_color=$purple
    ;;
  *) error ;;
esac

width=$(printf '%s' "$payload" | jq -r '.terminal_width // 120')
case $width in
  ''|*[!0-9]*) width=120 ;;
esac

branch=$(printf '%s' "$payload" | jq -r '.vcs.branch // empty')
dirty=$(printf '%s' "$payload" | jq -r '.vcs.dirty // false')
model=$(printf '%s' "$payload" | jq -r '.model.display_name // .model.id // "unknown"')
used=$(printf '%s' "$payload" | jq -r '.context_window.used_percentage // empty')
agents=$(printf '%s' "$payload" | jq -r '(.subagents // []) | length')
tasks=$(printf '%s' "$payload" | jq -r '(.background_tasks // []) | length')

if [ -z "$used" ] || ! printf '%s' "$used" | awk 'BEGIN { ok = 0 } /^[0-9]+(\.[0-9]+)?$/ { ok = 1 } END { exit !ok }'; then
  context='ctx ?'
else
  percent=$(awk -v value="$used" 'BEGIN { value = int(value + 0.5); if (value < 0) value = 0; if (value > 100) value = 100; print value }')
  filled=$(( (percent + 5) / 10 ))
  empty=$(( 10 - filled ))
  bar=$(printf '%*s' "$filled" '' | tr ' ' '█')
  bar="$bar$(printf '%*s' "$empty" '' | tr ' ' '░')"
  context="ctx [$bar] ${percent}%"
fi

output=$(printf '%b' "${state_color}● ${state_label}${reset}")

if [ "$width" -ge 60 ] && [ "$width" -lt 80 ]; then
  output="$output  ${green}${model}${reset}"
fi

if [ "$width" -ge 80 ]; then
  if [ -n "$branch" ]; then
    if [ "$dirty" = true ]; then
      git_state="${red}✚ dirty${reset}"
    else
      git_state="${green}✓ clean${reset}"
    fi
    output="$output  ${blue}${branch}${reset}  $git_state"
  fi
  output="$output  ${green}${model}${reset}"
fi

output="$output  $context"

if [ "$width" -ge 100 ]; then
  output="$output  agents $agents  tasks $tasks"
fi

printf '%b\n' "$output"
```

```sh
chmod +x scripts/agy-statusline
```

- [ ] **Step 2: テストを実行して通ることを確認する**

Run: `sh tests/agy-statusline.sh`

Expected: `PASS: agy statusline`

- [ ] **Step 3: 構文を確認する**

Run: `sh -n scripts/agy-statusline && git diff --check`

Expected: 終了ステータス 0。

### Task 3: agy 設定を dotfiles に移管する

**Files:**
- Create: `.gemini/antigravity-cli/settings.json`
- Modify: `README.md`

- [ ] **Step 1: 現在の有効な設定を保持し、statusLine コマンドを設定する**

```json
{
  "allowNonWorkspaceAccess": true,
  "colorScheme": "light",
  "permissions": {
    "allow": [
      "command(mise)",
      "command(grep)",
      "command(find)",
      "command(ls)",
      "command(which)",
      "command(agy)",
      "command(cat)",
      "command(head)",
      "command(tail)"
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "~/dotfiles/scripts/agy-statusline",
    "enabled": true
  },
  "trustedWorkspaces": [
    "/Users/haru256/repo/github.com/haru-256/hacker-rank",
    "/Users/haru256/Documents/projects/dotfiles"
  ]
}
```

- [ ] **Step 2: JSON の構文を検証する**

Run: `jq empty .gemini/antigravity-cli/settings.json`

Expected: 終了ステータス 0、標準出力なし。

- [ ] **Step 3: README の OpenCode 節の後に agy 節を追加する**

````md
### Antigravity CLI

```sh
mkdir -p ~/.gemini/antigravity-cli
if [ -e ~/.gemini/antigravity-cli/settings.json ] && [ ! -L ~/.gemini/antigravity-cli/settings.json ]; then
  mv ~/.gemini/antigravity-cli/settings.json ~/.gemini/antigravity-cli/settings.json.backup
fi
ln -s ~/dotfiles/.gemini/antigravity-cli/settings.json ~/.gemini/antigravity-cli/settings.json
chmod +x ~/dotfiles/scripts/agy-statusline
```

`statusLine.command` の `~/dotfiles` は、このリポジトリを別の場所にクローンした場合はその絶対パスに置き換えてください。
````

- [ ] **Step 4: 既存設定を破壊せずにリンクできることを確認する**

Run: `test -e ~/.gemini/antigravity-cli/settings.json && test ! -L ~/.gemini/antigravity-cli/settings.json && cp ~/.gemini/antigravity-cli/settings.json /tmp/agy-settings.json.backup && rm ~/.gemini/antigravity-cli/settings.json && ln -s "$PWD/.gemini/antigravity-cli/settings.json" ~/.gemini/antigravity-cli/settings.json && readlink ~/.gemini/antigravity-cli/settings.json`

Expected: `.../dotfiles/.gemini/antigravity-cli/settings.json`。問題があれば `rm ~/.gemini/antigravity-cli/settings.json && mv /tmp/agy-settings.json.backup ~/.gemini/antigravity-cli/settings.json` で復元する。

### Task 4: 利用経路を検証する

**Files:**
- Test: `scripts/agy-statusline`
- Test: `tests/agy-statusline.sh`
- Test: `.gemini/antigravity-cli/settings.json`

- [ ] **Step 1: 自動テストと設定の静的検証をまとめて実行する**

Run: `sh tests/agy-statusline.sh && sh -n scripts/agy-statusline && jq empty .gemini/antigravity-cli/settings.json && git diff --check`

Expected: `PASS: agy statusline` が出力され、終了ステータス 0。

- [ ] **Step 2: agy を再起動し、実際の状態遷移を確認する**

Run: `agy`

Expected: TUI 下部に idle 状態、現在の Git ブランチ、モデル、コンテキスト、agents/tasks が表示される。プロンプト処理中は `working`、Git 作業ツリーに変更がある場合は `dirty` へ変化する。

- [ ] **Step 3: 意図したファイルだけが変更されたことを確認する**

Run: `git status --short -- scripts/agy-statusline tests/agy-statusline.sh .gemini/antigravity-cli/settings.json README.md docs/superpowers/specs/2026-06-24-agy-statusline-design.md docs/superpowers/plans/2026-06-24-agy-statusline.md`

Expected: この計画で作成・変更したファイルだけが表示される。既存の未コミット変更は変更・復元しない。
