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
