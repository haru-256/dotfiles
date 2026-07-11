# Claude Code statusline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Claude Code CLI statusline (`scripts/claude-statusline`) that mirrors the existing `scripts/agy-statusline` and `scripts/cursor-statusline` conventions, wire it into README.md, and configure it on the user's machine.

**Architecture:** A single POSIX `sh` + `jq` script reads the Claude Code statusLine JSON from stdin, reads terminal width from the `$COLUMNS` environment variable (Claude Code does not put width in the JSON), runs `git` directly for branch/dirty state (also not in the JSON), and prints one ANSI truecolor line using the Catppuccin Latte palette already defined in `scripts/cursor-statusline`.

**Tech Stack:** POSIX `sh`, `jq`, `git`. Shell test harness matching `tests/agy-statusline.sh` / `tests/cursor-statusline.sh` (no test framework, plain `sh` script with `assert_contains`).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-07-claude-statusline-design.md` — every requirement below is copied from it verbatim.
- Script must be POSIX `sh` (`#!/bin/sh`), executable, and exit `0` even on malformed input (print a red `● claude statusline error` line instead of a nonzero exit).
- Terminal width comes from `$COLUMNS`; if unset or non-numeric, treat it as `80`.
- Git branch/dirty state is not in the JSON — obtain it by running `git` against `workspace.current_dir` (fallback `workspace.project_dir`).
- Colors are Catppuccin Latte truecolor, reusing the exact ANSI codes already defined in `scripts/cursor-statusline`: blue `\033[38;2;30;102;229m`, green `\033[38;2;64;160;43m`, lavender `\033[38;2;114;135;253m`, mauve `\033[38;2;136;57;239m`, peach `\033[38;2;254;100;11m`, red `\033[38;2;210;15;57m`, subtext `\033[38;2;108;111;133m`, teal `\033[38;2;23;146;153m`, yellow `\033[38;2;223;142;29m`, reset `\033[0m`.
- Segment thresholds (by `$COLUMNS`): always → model + context; ≥60 → dir/worktree; ≥70 → git; ≥90 → cost; ≥100 → effort; ≥110 → rate limits.
- Optional fields that are missing/non-numeric/empty omit their whole segment (no placeholder), except context which shows `ctx ?` when missing.
- `~/.claude/settings.json` as a whole is never symlinked (it holds personal `hooks`/`enabledPlugins`/`effortLevel`/`theme`); only the script itself is symlinked to `~/.claude/statusline.sh`, and the `statusLine` block is appended to the user's existing settings file.
- Do not print `session_id`, `pr`, or raw JSON contents — only the derived display segments.

---

### Task 1: `scripts/claude-statusline` script + test

**Files:**
- Create: `scripts/claude-statusline`
- Create: `tests/claude-statusline.sh`

**Interfaces:**
- Consumes: nothing from other tasks (first task).
- Produces: an executable file at `scripts/claude-statusline` that reads a JSON statusLine payload on stdin and `$COLUMNS` from the environment, and prints one line to stdout. Later tasks (README, machine setup) reference this file by its repo-relative path `scripts/claude-statusline` and assume it is executable (`chmod +x` applied in Step 5 below).

- [ ] **Step 1: Write the failing test**

Create `tests/claude-statusline.sh`:

```sh
#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/scripts/claude-statusline"
TMP_ROOT=${TMPDIR:-/tmp}
TMP_DIR="$TMP_ROOT/claude-statusline-test-$$"

fail() {
  printf '%s\n' "FAIL: $1" >&2
  exit 1
}

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT HUP INT TERM

[ -x "$SCRIPT" ] || fail "missing or non-executable statusline script: $SCRIPT"

assert_contains() {
  haystack=$1
  needle=$2
  case $haystack in
    *"$needle"*) ;;
    *) fail "expected [$needle] in [$haystack]" ;;
  esac
}

assert_not_contains() {
  haystack=$1
  needle=$2
  case $haystack in
    *"$needle"*) fail "did not expect [$needle] in [$haystack]" ;;
  esac
}

strip_ansi() {
  esc=$(printf '\033')
  sed "s/${esc}\\[[0-9;]*m//g"
}

mkdir -p "$TMP_DIR/clean-repo" "$TMP_DIR/dirty-repo" "$TMP_DIR/plain-dir"
git -C "$TMP_DIR/clean-repo" init -q
git -C "$TMP_DIR/clean-repo" checkout -b main -q
git -C "$TMP_DIR/dirty-repo" init -q
git -C "$TMP_DIR/dirty-repo" checkout -b feature/status -q
: >"$TMP_DIR/dirty-repo/changed.txt"

full_output=$(cat <<JSON | COLUMNS=130 "$SCRIPT" | strip_ansi
{
  "workspace": {"current_dir": "$TMP_DIR/dirty-repo"},
  "model": {"display_name": "Sonnet 5"},
  "context_window": {"used_percentage": 34.5},
  "cost": {"total_cost_usd": 0.4235, "total_duration_ms": 725000},
  "effort": {"level": "high"},
  "rate_limits": {"five_hour": {"used_percentage": 18}, "seven_day": {"used_percentage": 92}}
}
JSON
)
assert_contains "$full_output" "Sonnet 5"
assert_contains "$full_output" "dirty-repo"
assert_contains "$full_output" "feature/status +1"
assert_contains "$full_output" "ctx [████░░░░░░] 35%"
assert_contains "$full_output" "\$0.42 12m"
assert_contains "$full_output" "effort high"
assert_contains "$full_output" "7d 92%"

clean_output=$(cat <<JSON | COLUMNS=130 "$SCRIPT" | strip_ansi
{
  "workspace": {"current_dir": "$TMP_DIR/clean-repo", "git_worktree": "wt-name"},
  "model": {"id": "claude-model"},
  "context_window": {"used_percentage": 8},
  "rate_limits": {"five_hour": {"used_percentage": 40}}
}
JSON
)
assert_contains "$clean_output" "claude-model"
assert_contains "$clean_output" "wt-name"
assert_contains "$clean_output" "main clean"
assert_contains "$clean_output" "ctx [█░░░░░░░░░] 8%"
assert_contains "$clean_output" "5h 40%"

no_git_output=$(cat <<JSON | COLUMNS=130 "$SCRIPT" | strip_ansi
{
  "workspace": {"current_dir": "$TMP_DIR/plain-dir"},
  "model": {"display_name": "Sonnet 5"},
  "context_window": {"used_percentage": 50}
}
JSON
)
assert_contains "$no_git_output" "plain-dir"
assert_not_contains "$no_git_output" "clean"
assert_not_contains "$no_git_output" "+0"

narrow_output=$(cat <<JSON | COLUMNS=59 "$SCRIPT" | strip_ansi
{
  "workspace": {"current_dir": "$TMP_DIR/dirty-repo"},
  "model": {"display_name": "Sonnet 5"},
  "context_window": {"used_percentage": 8},
  "cost": {"total_cost_usd": 1, "total_duration_ms": 60000},
  "effort": {"level": "high"},
  "rate_limits": {"five_hour": {"used_percentage": 95}}
}
JSON
)
assert_contains "$narrow_output" "Sonnet 5"
assert_contains "$narrow_output" "ctx [█░░░░░░░░░] 8%"
case $narrow_output in
  *dirty-repo*|*feature*|*effort*|*95%*) fail "narrow layout retained optional fields" ;;
esac

no_cost_output=$(cat <<JSON | COLUMNS=89 "$SCRIPT" | strip_ansi
{
  "workspace": {"current_dir": "$TMP_DIR/dirty-repo"},
  "model": {"display_name": "Sonnet 5"},
  "context_window": {"used_percentage": 8},
  "cost": {"total_cost_usd": 1, "total_duration_ms": 60000}
}
JSON
)
assert_contains "$no_cost_output" "feature/status +1"
assert_not_contains "$no_cost_output" '$1.00'

partial_cost_output=$(cat <<JSON | COLUMNS=130 "$SCRIPT" | strip_ansi
{
  "workspace": {"current_dir": "$TMP_DIR/clean-repo"},
  "model": {"display_name": "Sonnet 5"},
  "context_window": {"used_percentage": 8},
  "cost": {"total_cost_usd": 1}
}
JSON
)
assert_not_contains "$partial_cost_output" '$1.00'

missing_fields_output=$(printf '%s\n' '{}' | COLUMNS=130 "$SCRIPT" | strip_ansi)
assert_contains "$missing_fields_output" "unknown"
assert_contains "$missing_fields_output" "ctx ?"
case $missing_fields_output in
  *effort*|*rate*) fail "missing-fields output retained optional segments" ;;
esac

set +e
invalid_output=$(printf '{invalid' | COLUMNS=130 "$SCRIPT")
invalid_status=$?
set -e
[ "$invalid_status" -eq 0 ] || fail "malformed JSON returned status $invalid_status"
invalid_output=$(printf '%s\n' "$invalid_output" | strip_ansi)
assert_contains "$invalid_output" "error"

printf '%s\n' "PASS: claude statusline"
```

Make it executable:

```bash
chmod +x tests/claude-statusline.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/claude-statusline.sh`
Expected: `FAIL: missing or non-executable statusline script: <repo>/scripts/claude-statusline` (script does not exist yet).

- [ ] **Step 3: Write the implementation**

Create `scripts/claude-statusline`:

```sh
#!/bin/sh

# Render the Claude Code statusline from its JSON input.
blue='\033[38;2;30;102;229m'
green='\033[38;2;64;160;43m'
lavender='\033[38;2;114;135;253m'
mauve='\033[38;2;136;57;239m'
peach='\033[38;2;254;100;11m'
red='\033[38;2;210;15;57m'
subtext='\033[38;2;108;111;133m'
teal='\033[38;2;23;146;153m'
yellow='\033[38;2;223;142;29m'
reset='\033[0m'

print_error() {
  printf '%b● claude statusline error%b\n' "$red" "$reset"
}

data=$(jq -r '
  def value($path): try getpath($path) catch null;
  def text_or_empty:
    if type == "string" then gsub("[\u0000-\u001f\u007f-\u009f]"; "") else "" end;

  (value(["workspace", "current_dir"]) | text_or_empty) as $current_dir |
  (value(["workspace", "project_dir"]) | text_or_empty) as $project_dir |
  (if $current_dir != "" then $current_dir else $project_dir end) as $dir |
  (value(["workspace", "git_worktree"]) | text_or_empty) as $worktree |
  (value(["model", "display_name"]) | text_or_empty) as $display_name |
  (value(["model", "id"]) | text_or_empty) as $model_id |
  (if $display_name != "" then $display_name
   elif $model_id != "" then $model_id
   else "unknown"
   end) as $model |
  (value(["context_window", "used_percentage"])) as $usage |
  (if $usage | type == "number" then
      ($usage | round | if . < 0 then 0 elif . > 100 then 100 else . end | tostring)
   else "?"
   end) as $context |
  (value(["cost", "total_cost_usd"])) as $cost_raw |
  (value(["cost", "total_duration_ms"])) as $duration_raw |
  (($cost_raw | type == "number") and ($duration_raw | type == "number")) as $has_cost |
  (if $has_cost then ($cost_raw | tostring) else "" end) as $cost_usd |
  (if $has_cost then ($duration_raw / 60000 | floor | tostring) else "" end) as $duration_min |
  (value(["effort", "level"]) | text_or_empty) as $effort |
  (value(["rate_limits", "five_hour", "used_percentage"])) as $five_raw |
  (value(["rate_limits", "seven_day", "used_percentage"])) as $seven_raw |
  ($five_raw | if type == "number" then . else null end) as $five |
  ($seven_raw | if type == "number" then . else null end) as $seven |
  (if $five != null and $seven != null then
     (if $five >= $seven then "5h" else "7d" end)
   elif $five != null then "5h"
   elif $seven != null then "7d"
   else "" end) as $rl_label |
  (if $five != null and $seven != null then
     (if $five >= $seven then $five else $seven end)
   elif $five != null then $five
   elif $seven != null then $seven
   else null end) as $rl_value |
  ($rl_value | if . == null then "" else
     (round | if . < 0 then 0 elif . > 100 then 100 else . end | tostring)
   end) as $rl_pct |
  [$model, $dir, $worktree, $context, $cost_usd, $duration_min, $effort, $rl_label, $rl_pct] | @sh
' 2>/dev/null) || {
  print_error
  exit 0
}

eval "set -- $data"
model=$1
dir=$2
worktree=$3
context=$4
cost_usd=$5
duration_min=$6
effort=$7
rl_label=$8
rl_pct=$9

width=${COLUMNS:-80}
case $width in
  ''|*[!0-9]*) width=80 ;;
esac

dir_label=${dir##*/}
if [ -n "$worktree" ]; then
  dir_label=$worktree
fi
if [ -z "$dir_label" ]; then
  dir_label=.
fi

branch=
dirty=0
if [ -n "$dir" ] && git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$dir" branch --show-current 2>/dev/null || true)
  if [ -z "$branch" ]; then
    branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || true)
  fi
  dirty=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
fi

printf '%b%s%b' "$blue" "$model" "$reset"

if [ "$width" -ge 60 ]; then
  printf ' %b|%b %b%s%b' "$subtext" "$reset" "$teal" "$dir_label" "$reset"
fi

if [ "$width" -ge 70 ] && [ -n "$branch" ]; then
  if [ "$dirty" -gt 0 ]; then
    printf ' %b|%b %b%s +%s%b' "$subtext" "$reset" "$yellow" "$branch" "$dirty" "$reset"
  else
    printf ' %b|%b %b%s clean%b' "$subtext" "$reset" "$green" "$branch" "$reset"
  fi
fi

if [ "$context" = "?" ]; then
  printf ' %b|%b %bctx ?%b' "$subtext" "$reset" "$mauve" "$reset"
else
  filled=$(((context + 5) / 10))
  empty=$((10 - filled))
  bar=
  i=0
  while [ "$i" -lt "$filled" ]; do
    bar="${bar}█"
    i=$((i + 1))
  done
  i=0
  while [ "$i" -lt "$empty" ]; do
    bar="${bar}░"
    i=$((i + 1))
  done
  printf ' %b|%b %bctx [%s] %s%%%b' "$subtext" "$reset" "$mauve" "$bar" "$context" "$reset"
fi

if [ "$width" -ge 90 ] && [ -n "$cost_usd" ] && [ -n "$duration_min" ]; then
  cost_fmt=$(printf '%.2f' "$cost_usd")
  printf ' %b|%b %b$%s %sm%b' "$subtext" "$reset" "$peach" "$cost_fmt" "$duration_min" "$reset"
fi

if [ "$width" -ge 100 ] && [ -n "$effort" ]; then
  printf ' %b|%b %beffort %s%b' "$subtext" "$reset" "$lavender" "$effort" "$reset"
fi

if [ "$width" -ge 110 ] && [ -n "$rl_label" ]; then
  if [ "$rl_pct" -ge 90 ]; then
    rl_color=$red
  elif [ "$rl_pct" -ge 70 ]; then
    rl_color=$yellow
  else
    rl_color=$green
  fi
  printf ' %b|%b %b%s %s%%%b' "$subtext" "$reset" "$rl_color" "$rl_label" "$rl_pct" "$reset"
fi

printf '\n'
```

- [ ] **Step 4: Make it executable and run the test**

```bash
chmod +x scripts/claude-statusline
sh tests/claude-statusline.sh
```

Expected: `PASS: claude statusline`

If any `assert_contains`/`assert_not_contains` fails, the failure message names the exact needle and haystack — fix `scripts/claude-statusline` accordingly and re-run until it passes.

- [ ] **Step 5: Commit**

```bash
git add scripts/claude-statusline tests/claude-statusline.sh
git commit -m "feat(claude): add statusline script"
```

---

### Task 2: README.md documentation

**Files:**
- Modify: `README.md` (add a new `### Claude Code` subsection under the same heading level as the existing `### Cursor (orchestrator / worker)` at `README.md:137` and `### Antigravity CLI` at `README.md:195`)

**Interfaces:**
- Consumes: `scripts/claude-statusline` (Task 1) — referenced by its repo-relative path.
- Produces: documentation only; no other task depends on this one.

- [ ] **Step 1: Add the section**

Insert a new subsection immediately before the existing `### Herdr Multi-Agent System` heading (`README.md:209`), i.e. right after the `### Antigravity CLI` block ends (after `README.md:207`):

```markdown
### Claude Code

```sh
ln -s ~/dotfiles/scripts/claude-statusline ~/.claude/statusline.sh
chmod +x ~/dotfiles/scripts/claude-statusline
```

`~/.claude/settings.json` はテーマや `hooks` など個人設定を含むため、ファイル全体は dotfiles 管理しません。既存ファイルへ次のブロックを追記します。

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 2
  }
}
```

`claude-statusline` は `jq` と `git` を使います。clone 先が `~/dotfiles` でない場合は、symlink 元パスを実際のパスに置き換えてください。
```

- [ ] **Step 2: Validate the JSON snippet**

```bash
echo '{"statusLine": {"type": "command", "command": "~/.claude/statusline.sh", "padding": 2}}' | jq empty
```

Expected: no output, exit code `0` (valid JSON).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs(claude): document statusline setup"
```

---

### Task 3: Configure the user's machine

**Files:**
- Modify (outside repo): `~/.claude/settings.json`
- Create (outside repo, symlink): `~/.claude/statusline.sh`

**Interfaces:**
- Consumes: `scripts/claude-statusline` (Task 1, must already be executable) and the README instructions (Task 2).
- Produces: a working statusline in the user's live Claude Code session. Nothing downstream depends on this task.

- [ ] **Step 1: Create the symlink**

```bash
ln -s ~/Documents/projects/dotfiles/scripts/claude-statusline ~/.claude/statusline.sh
ls -la ~/.claude/statusline.sh
```

Expected: `ls` shows it as a symlink pointing at `~/Documents/projects/dotfiles/scripts/claude-statusline`.

- [ ] **Step 2: Read the current settings file**

```bash
cat ~/.claude/settings.json
```

Confirm it does not already contain a `statusLine` key before editing (it did not, as of this plan's writing — the file only had `hooks`, `enabledPlugins`, `effortLevel`, `skipDangerousModePermissionPrompt`, `theme`).

- [ ] **Step 3: Add the `statusLine` block**

Edit `~/.claude/settings.json`, adding a `"statusLine"` key alongside the existing top-level keys (do not remove or reorder the existing keys):

```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline.sh",
  "padding": 2
}
```

- [ ] **Step 4: Validate the edited file is valid JSON**

```bash
jq empty ~/.claude/settings.json
```

Expected: no output, exit code `0`.

- [ ] **Step 5: Smoke-test the statusline manually**

```bash
COLUMNS=130 sh -c '
cat <<JSON | ~/.claude/statusline.sh
{
  "workspace": {"current_dir": "'"$HOME"'/Documents/projects/dotfiles"},
  "model": {"display_name": "Sonnet 5"},
  "context_window": {"used_percentage": 12},
  "effort": {"level": "high"}
}
JSON
'
```

Expected: one printed line containing `Sonnet 5`, the `dotfiles` directory/branch segment, and `ctx [...] 12%` — confirming the symlink and settings wiring work end-to-end. Then start (or restart) a Claude Code session in this repo and visually confirm the statusline renders at the bottom of the TUI.

- [ ] **Step 6: Report completion**

No git commit for this task (it only touches files outside the repo). Report to the user: the settings key added, the symlink created, and the smoke-test output.
