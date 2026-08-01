#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/scripts/agy-statusline"

fail() {
  printf '%s\n' "FAIL: $1" >&2
  exit 1
}

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

compact_output=$(cat <<'JSON' | "$SCRIPT" | strip_ansi
{
  "agent_state": "idle",
  "terminal_width": 79,
  "vcs": {"branch": "main", "dirty": true},
  "model": {"display_name": "Gemini"},
  "context_window": {"used_percentage": 50},
  "subagents": [{"name": "worker"}],
  "background_tasks": [{"name": "test"}]
}
JSON
)
assert_contains "$compact_output" "Gemini"
case $compact_output in
  *main*|*dirty*|*agents*|*tasks*) fail "79-column layout retained hidden fields" ;;
esac

standard_output=$(cat <<'JSON' | "$SCRIPT" | strip_ansi
{
  "agent_state": "idle",
  "terminal_width": 99,
  "vcs": {"branch": "main", "dirty": false},
  "model": {"display_name": "Gemini"},
  "context_window": {"used_percentage": 50},
  "subagents": [{"name": "worker"}],
  "background_tasks": [{"name": "test"}]
}
JSON
)
assert_contains "$standard_output" "main"
assert_contains "$standard_output" "clean"
assert_contains "$standard_output" "Gemini"
case $standard_output in
  *agents*|*tasks*) fail "99-column layout retained hidden counts" ;;
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

null_fields_output=$(cat <<'JSON' | "$SCRIPT" | strip_ansi
{
  "agent_state": "working",
  "terminal_width": 120,
  "vcs": null,
  "model": null,
  "context_window": null,
  "subagents": null,
  "background_tasks": null
}
JSON
)
assert_contains "$null_fields_output" "working"
assert_contains "$null_fields_output" "unknown"
assert_contains "$null_fields_output" "ctx ?"
assert_contains "$null_fields_output" "agents 0"
assert_contains "$null_fields_output" "tasks 0"

unknown_state_output=$(cat <<'JSON' | "$SCRIPT" | strip_ansi
{
  "agent_state": "paused",
  "terminal_width": 120
}
JSON
)
assert_contains "$unknown_state_output" "error"

sanitized_output=$(cat <<'JSON' | "$SCRIPT" | strip_ansi
{
  "agent_state": "idle",
  "terminal_width": 120,
  "vcs": {"branch": "feature\n\u001f\u001b[31m", "dirty": true},
  "model": {"display_name": "Gemini\n\u001f\u001b[2J"},
  "context_window": {"used_percentage": 42},
  "subagents": [{}, {}],
  "background_tasks": [{}]
}
JSON
)
assert_contains "$sanitized_output" "feature[31m dirty"
assert_contains "$sanitized_output" "Gemini[2J"
assert_contains "$sanitized_output" "ctx [████░░░░░░] 42%"
assert_contains "$sanitized_output" "agents 2"
assert_contains "$sanitized_output" "tasks 1"
esc=$(printf '\033')
case $sanitized_output in
  *"$esc"*) fail "sanitized output retained escape characters" ;;
esac

set +e
invalid_output=$(printf '{invalid' | "$SCRIPT")
invalid_status=$?
set -e
[ "$invalid_status" -eq 0 ] || fail "malformed JSON returned status $invalid_status"
invalid_output=$(printf '%s\n' "$invalid_output" | strip_ansi)
assert_contains "$invalid_output" "error"

printf '%s\n' "PASS: agy statusline"
