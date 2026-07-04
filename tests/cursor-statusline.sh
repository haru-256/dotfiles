#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/scripts/cursor-statusline"
TMP_ROOT=${TMPDIR:-/tmp}
TMP_DIR="$TMP_ROOT/cursor-statusline-test-$$"

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

strip_ansi() {
  esc=$(printf '\033')
  sed "s/${esc}\\[[0-9;]*m//g"
}

mkdir -p "$TMP_DIR/project"
git -C "$TMP_DIR/project" init -q
git -C "$TMP_DIR/project" checkout -b feature/status -q
: >"$TMP_DIR/project/changed.txt"

full_output=$(cat <<JSON | "$SCRIPT" | strip_ansi
{
  "render_width_chars": 130,
  "workspace": {"current_dir": "$TMP_DIR/project"},
  "model": {"display_name": "GPT-5.5", "param_summary": "medium"},
  "context_window": {"used_percentage": 34.5},
  "vim": {"mode": "NORMAL"},
  "output_style": {"name": "compact"},
  "autorun": true,
  "version": "1.2.3"
}
JSON
)
assert_contains "$full_output" "GPT-5.5"
assert_contains "$full_output" "medium"
assert_contains "$full_output" "project"
assert_contains "$full_output" "feature/status +1"
assert_contains "$full_output" "ctx [████░░░░░░] 35%"
assert_contains "$full_output" "NORMAL"
assert_contains "$full_output" "style compact"
assert_contains "$full_output" "autorun"
assert_contains "$full_output" "v1.2.3"

narrow_output=$(cat <<'JSON' | "$SCRIPT" | strip_ansi
{
  "render_width_chars": 59,
  "workspace": {"current_dir": "/tmp/example"},
  "model": {"id": "cursor-model"},
  "context_window": {"used_percentage": 8},
  "vim": {"mode": "INSERT"},
  "output_style": {"name": "compact"},
  "autorun": true,
  "version": "1.2.3"
}
JSON
)
assert_contains "$narrow_output" "cursor-model"
assert_contains "$narrow_output" "ctx [█░░░░░░░░░] 8%"
case $narrow_output in
  *example*|*INSERT*|*compact*|*autorun*|*v1.2.3*) fail "narrow layout retained optional fields" ;;
esac

missing_fields_output=$(printf '%s\n' '{}' | "$SCRIPT" | strip_ansi)
assert_contains "$missing_fields_output" "unknown"
assert_contains "$missing_fields_output" "ctx ?"

set +e
invalid_output=$(printf '{invalid' | "$SCRIPT")
invalid_status=$?
set -e
[ "$invalid_status" -eq 0 ] || fail "malformed JSON returned status $invalid_status"
invalid_output=$(printf '%s\n' "$invalid_output" | strip_ansi)
assert_contains "$invalid_output" "error"

printf '%s\n' "PASS: cursor statusline"
