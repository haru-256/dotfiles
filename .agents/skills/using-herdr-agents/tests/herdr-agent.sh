#!/bin/sh
set -eu

SKILL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
ROOT_DIR=$(CDPATH= cd -- "$SKILL_DIR/../../.." && pwd -P)
SCRIPT="$SKILL_DIR/scripts/herdr-agent"
SESSION_SCRIPT="$SKILL_DIR/scripts/herdr-agent-session"
INSTALL_SCRIPT="$SKILL_DIR/scripts/install"
LIB_SCRIPT="$SKILL_DIR/scripts/herdr-agent-lib"
PROMPT_DIR="$SKILL_DIR/prompts"
SKILL_FILE="$SKILL_DIR/SKILL.md"
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/herdr-agent-test.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

run_dry() {
  role="$1"
  shift
  HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PROMPT_DIR" "$SCRIPT" "$role" "$@"
}

assert_contains() {
  haystack="$1"
  needle="$2"
  if ! printf '%s\n' "$haystack" | grep -F "$needle" >/dev/null; then
    printf '%s\n' "missing expected text: $needle" >&2
    printf '%s\n' "$haystack" >&2
    exit 1
  fi
}

assert_not_contains() {
  haystack="$1"
  needle="$2"
  if printf '%s\n' "$haystack" | grep -F "$needle" >/dev/null; then
    printf '%s\n' "unexpected text present: $needle" >&2
    printf '%s\n' "$haystack" >&2
    exit 1
  fi
}

assert_fails_with() {
  expected="$1"
  shift
  if "$@" >"$TMP_DIR/fail.out" 2>"$TMP_DIR/fail.err"; then
    printf '%s\n' "command unexpectedly succeeded: $*" >&2
    cat "$TMP_DIR/fail.out" >&2
    exit 1
  fi
  if ! grep -F "$expected" "$TMP_DIR/fail.err" >/dev/null; then
    printf '%s\n' "missing expected failure text: $expected" >&2
    cat "$TMP_DIR/fail.err" >&2
    exit 1
  fi
}

for script in "$SCRIPT" "$SESSION_SCRIPT" "$INSTALL_SCRIPT" "$LIB_SCRIPT" "$0"
do
  if ! sh -n "$script"; then
    printf '%s\n' "syntax validation failed for: $script" >&2
    exit 1
  fi
done

for file in "$SKILL_FILE" "$SCRIPT" "$SESSION_SCRIPT" "$INSTALL_SCRIPT" "$LIB_SCRIPT" \
  "$PROMPT_DIR/shared.md" "$PROMPT_DIR/scout.md" "$PROMPT_DIR/coder.md" \
  "$PROMPT_DIR/auditor.md" "$PROMPT_DIR/advisor.md"
do
  if [ ! -r "$file" ]; then
    printf '%s\n' "missing readable package file: $file" >&2
    exit 1
  fi
done

skill_text=$(cat "$SKILL_FILE")
assert_contains "$skill_text" "name: using-herdr-agents"
assert_contains "$skill_text" "Default to one-shot"
assert_contains "$skill_text" "Use a persistent session"
assert_contains "$skill_text" "Reuse only when"
assert_contains "$skill_text" "Close stale sessions"
assert_contains "$skill_text" "herdr agent list"
assert_contains "$skill_text" "herdr pane close"
assert_contains "$skill_text" "./.agents/skills/using-herdr-agents/scripts/install"
assert_contains "$skill_text" "scripts/install"
assert_contains "$skill_text" "Do not delegate when Codex can answer faster"
assert_contains "$skill_text" "Operational Contract"
assert_contains "$skill_text" '`HERDR_AGENT_CONTEXT_KEY` is the explicit contract for reuse'
assert_contains "$skill_text" "Shared shell helpers live in"
assert_contains "$skill_text" 'Use the `herdr` skill first when direct Herdr workspace, tab, pane, wait, or low-level agent coordination is needed'
assert_contains "$skill_text" 'ordinary `herdr-agent` and `herdr-agent-session` usage does not require loading that skill'

scout_output=$(run_dry scout "find files")
assert_contains "$scout_output" "ROLE=scout"
assert_contains "$scout_output" "BACKEND=opencode"
assert_contains "$scout_output" "MODEL=opencode-go/deepseek-v4-flash"
assert_contains "$scout_output" "MODE=oneshot"
assert_contains "$scout_output" "OPENCODE_AGENT=scout_v2"
assert_contains "$scout_output" "PROMPT_DIR=$PROMPT_DIR"

scout_agent_override_output=$(
  HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PROMPT_DIR" \
    HERDR_AGENT_SCOUT_OPENCODE_AGENT=ignored_agent "$SCRIPT" scout "find files"
)
assert_contains "$scout_agent_override_output" "OPENCODE_AGENT=scout_v2"
assert_not_contains "$scout_agent_override_output" "ignored_agent"

interactive_scout_output=$(
  HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_MODE=interactive HERDR_AGENT_PROMPT_DIR="$PROMPT_DIR" "$SCRIPT" scout "find files"
)
assert_contains "$interactive_scout_output" "ROLE=scout"
assert_contains "$interactive_scout_output" "BACKEND=opencode"
assert_contains "$interactive_scout_output" "MODE=interactive"

fallback_output=$(HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$TMP_DIR/missing-prompts" "$SCRIPT" scout "find files")
assert_contains "$fallback_output" "ROLE=scout"
assert_contains "$fallback_output" "PROMPT_DIR=$PROMPT_DIR"

cline_scout_output=$(
  HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PROMPT_DIR" HERDR_AGENT_SCOUT_BACKEND=cline \
    "$SCRIPT" scout "find files"
)
assert_contains "$cline_scout_output" "ROLE=scout"
assert_contains "$cline_scout_output" "BACKEND=cline"
assert_contains "$cline_scout_output" "MODEL=deepseek-v4-flash"
assert_contains "$cline_scout_output" "CLINE_PROVIDER=cline-pass"
assert_contains "$cline_scout_output" "CLINE_THINKING=low"

cline_override_output=$(
  HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PROMPT_DIR" HERDR_AGENT_SCOUT_BACKEND=cline \
    HERDR_AGENT_SCOUT_CLINE_PROVIDER=ignored-provider \
    HERDR_AGENT_SCOUT_CLINE_THINKING=xhigh \
    "$SCRIPT" scout "find files"
)
assert_contains "$cline_override_output" "ROLE=scout"
assert_contains "$cline_override_output" "BACKEND=cline"
assert_contains "$cline_override_output" "MODEL=deepseek-v4-flash"
assert_contains "$cline_override_output" "CLINE_PROVIDER=cline-pass"
assert_contains "$cline_override_output" "CLINE_THINKING=low"
assert_not_contains "$cline_override_output" "ignored-provider"
assert_not_contains "$cline_override_output" "xhigh"

assert_fails_with "HERDR_AGENT_SCOUT_BACKEND must be opencode or cline" \
  env HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PROMPT_DIR" HERDR_AGENT_SCOUT_BACKEND=bad \
  "$SCRIPT" scout "find files"

assert_fails_with "HERDR_AGENT_SCOUT_BACKEND must be opencode or cline" \
  env HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_SCOUT_BACKEND=bad HERDR_AGENT_REUSE=never \
  "$SESSION_SCRIPT" scout "find files"

coder_output=$(run_dry coder "change one file")
assert_contains "$coder_output" "ROLE=coder"
assert_contains "$coder_output" "BACKEND=agy"
assert_contains "$coder_output" "MODEL=Gemini 3.5 Flash (Medium)"

auditor_output=$(run_dry auditor "review diff")
assert_contains "$auditor_output" "ROLE=auditor"
assert_contains "$auditor_output" "BACKEND=agy"
assert_contains "$auditor_output" "MODEL=Gemini 3.5 Flash (Medium)"

advisor_output=$(
  HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PROMPT_DIR" HERDR_AGENT_ADVISOR_THINKING=xhigh \
    "$SCRIPT" advisor "decide"
)
assert_contains "$advisor_output" "ROLE=advisor"
assert_contains "$advisor_output" "BACKEND=codex"
assert_contains "$advisor_output" "MODEL=gpt-5.5"
assert_contains "$advisor_output" "THINKING=xhigh"

if HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PROMPT_DIR" HERDR_AGENT_ADVISOR_THINKING=medium \
  "$SCRIPT" advisor "bad" >"$TMP_DIR/out" 2>"$TMP_DIR/err"; then
  printf '%s\n' "advisor accepted invalid thinking" >&2
  exit 1
fi

if ! grep -F "advisor thinking must be high or xhigh" "$TMP_DIR/err" >/dev/null; then
  printf '%s\n' "invalid thinking error message was not clear" >&2
  cat "$TMP_DIR/err" >&2
  exit 1
fi

if ! grep -F "# Repository Root" "$SCRIPT" >/dev/null; then
  printf '%s\n' "runner does not inject repository root into worker prompts" >&2
  exit 1
fi

if ! grep -F -- '--add-dir "$repo_root"' "$SCRIPT" >/dev/null; then
  printf '%s\n' "agy backend does not attach repository root" >&2
  exit 1
fi

if ! grep -F -- '--new-project' "$SCRIPT" >/dev/null; then
  printf '%s\n' "agy backend does not isolate one-shot worker projects" >&2
  exit 1
fi

for removed in \
  'CLINE_BIN_PATH' \
  'mise which cline' \
  '.local/share/mise/installs/npm-cline' \
  '.npm-global/bin/cline' \
  '.bun/bin/cline' \
  '/opt/homebrew/bin/cline' \
  '/usr/local/bin/cline' \
  '$HOME/.config/herdr/agents' \
  '$dotfiles_root/.config/herdr/agents' \
  'HERDR_AGENT_SCOUT_OPENCODE_AGENT' \
  'HERDR_AGENT_SCOUT_CLINE_PROVIDER' \
  'HERDR_AGENT_SCOUT_CLINE_THINKING'
do
  if grep -F "$removed" "$SCRIPT" >/dev/null; then
    printf '%s\n' "removed compatibility path still present: $removed" >&2
    exit 1
  fi
done

session_output=$(
  HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_CONTEXT_KEY=test-context HERDR_AGENT_REUSE=never \
    "$SESSION_SCRIPT" scout "find files"
)
assert_contains "$session_output" "ROLE=scout"
assert_contains "$session_output" "BACKEND=opencode"
assert_contains "$session_output" "RUNNER_MODE=interactive"
assert_contains "$session_output" "REUSE=never"
assert_contains "$session_output" "CONTEXT_KEY=test-context"
assert_contains "$session_output" "RUNNER=$SCRIPT"

session_auto_output=$(
  HERDR_AGENT_SESSION_DRY_RUN=1 "$SESSION_SCRIPT" scout "find files"
)
assert_contains "$session_auto_output" "REUSE=never"
assert_contains "$session_auto_output" "CONTEXT_KEY=no-context-"

assert_fails_with "HERDR_AGENT_CONTEXT_KEY is required when HERDR_AGENT_REUSE=require" \
  env HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_REUSE=require \
  "$SESSION_SCRIPT" scout "find files"

oneshot_session_output=$(
  HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_SESSION_MODE=oneshot HERDR_AGENT_CONTEXT_KEY=test-context \
    HERDR_AGENT_REUSE=never "$SESSION_SCRIPT" scout "find files"
)
assert_contains "$oneshot_session_output" "RUNNER_MODE=oneshot"

install_output=$(
  HERDR_AGENT_INSTALL_DRY_RUN=1 HERDR_AGENT_INSTALL_PREFIX="$TMP_DIR/bin" \
    HERDR_AGENT_INSTALL_CONFIG_DIR="$TMP_DIR/config/herdr" \
    HERDR_AGENT_INSTALL_SKILLS_DIR="$TMP_DIR/skills" \
    "$INSTALL_SCRIPT"
)
assert_contains "$install_output" "$TMP_DIR/bin/herdr-agent -> $SKILL_DIR/scripts/herdr-agent"
assert_contains "$install_output" "$TMP_DIR/bin/herdr-agent-session -> $SKILL_DIR/scripts/herdr-agent-session"
assert_contains "$install_output" "$TMP_DIR/config/herdr/agents -> $SKILL_DIR/prompts"
assert_contains "$install_output" "$TMP_DIR/skills/using-herdr-agents -> $SKILL_DIR"

HERDR_AGENT_INSTALL_PREFIX="$TMP_DIR/installed/bin" \
  HERDR_AGENT_INSTALL_CONFIG_DIR="$TMP_DIR/installed/config/herdr" \
  HERDR_AGENT_INSTALL_SKILLS_DIR="$TMP_DIR/installed/skills" \
  "$INSTALL_SCRIPT" >/dev/null

installed_scout_output=$(
  HERDR_AGENT_DRY_RUN=1 "$TMP_DIR/installed/bin/herdr-agent" scout "find files"
)
assert_contains "$installed_scout_output" "PROMPT_DIR=$SKILL_DIR/prompts"

installed_session_output=$(
  HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_CONTEXT_KEY=test-context \
    HERDR_AGENT_REUSE=never "$TMP_DIR/installed/bin/herdr-agent-session" scout "find files"
)
assert_contains "$installed_session_output" "RUNNER=$SKILL_DIR/scripts/herdr-agent"

mkdir -p "$TMP_DIR/existing-empty/herdr/agents"
HERDR_AGENT_INSTALL_PREFIX="$TMP_DIR/existing-empty/bin" \
  HERDR_AGENT_INSTALL_CONFIG_DIR="$TMP_DIR/existing-empty/herdr" \
  HERDR_AGENT_INSTALL_SKILLS_DIR="$TMP_DIR/existing-empty/skills" \
  "$INSTALL_SCRIPT" >/dev/null
if [ "$(readlink "$TMP_DIR/existing-empty/herdr/agents")" != "$SKILL_DIR/prompts" ]; then
  printf '%s\n' "install did not replace an empty agents directory with the prompts symlink" >&2
  exit 1
fi

mkdir -p "$TMP_DIR/existing-nonempty/herdr/agents"
printf '%s\n' "keep" >"$TMP_DIR/existing-nonempty/herdr/agents/file"
if HERDR_AGENT_INSTALL_PREFIX="$TMP_DIR/existing-nonempty/bin" \
  HERDR_AGENT_INSTALL_CONFIG_DIR="$TMP_DIR/existing-nonempty/herdr" \
  HERDR_AGENT_INSTALL_SKILLS_DIR="$TMP_DIR/existing-nonempty/skills" \
  "$INSTALL_SCRIPT" >"$TMP_DIR/install.out" 2>"$TMP_DIR/install.err"; then
  printf '%s\n' "install replaced a non-empty agents directory" >&2
  exit 1
fi
if ! grep -F "target exists and is not an empty directory or symlink" "$TMP_DIR/install.err" >/dev/null; then
  printf '%s\n' "install non-empty directory error was not clear" >&2
  cat "$TMP_DIR/install.err" >&2
  exit 1
fi

printf '%s\n' "PASS: using-herdr-agents"
