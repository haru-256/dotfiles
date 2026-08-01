#!/bin/sh
set -eu

SKILL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
ROOT_DIR=$(CDPATH= cd -- "$SKILL_DIR/../../.." && pwd -P)
SCRIPT="$SKILL_DIR/scripts/herdr-worker"
RUNNER="$SKILL_DIR/scripts/herdr-worker-run"
INSTALL_SCRIPT="$SKILL_DIR/scripts/install"
PROMPT_DIR="$SKILL_DIR/prompts"
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/herdr-worker-test.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

assert_contains() {
  haystack="$1"
  needle="$2"
  if ! printf '%s\n' "$haystack" | grep -F -- "$needle" >/dev/null; then
    printf '%s\n' "missing expected text: $needle" >&2
    printf '%s\n' "$haystack" >&2
    exit 1
  fi
}

assert_not_contains() {
  haystack="$1"
  needle="$2"
  if printf '%s\n' "$haystack" | grep -F -- "$needle" >/dev/null; then
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
    exit 1
  fi
  if ! grep -F -- "$expected" "$TMP_DIR/fail.err" >/dev/null; then
    printf '%s\n' "missing expected failure text: $expected" >&2
    cat "$TMP_DIR/fail.err" >&2
    exit 1
  fi
}

for file in \
  "$SKILL_DIR/SKILL.md" \
  "$SCRIPT" \
  "$RUNNER" \
  "$INSTALL_SCRIPT" \
  "$PROMPT_DIR/shared.md" \
  "$PROMPT_DIR/explorer.md" \
  "$PROMPT_DIR/implementer.md" \
  "$PROMPT_DIR/reviewer.md"
do
  if [ ! -r "$file" ]; then
    printf '%s\n' "missing readable package file: $file" >&2
    exit 1
  fi
done

for script in "$SCRIPT" "$RUNNER" "$INSTALL_SCRIPT" "$0"
do
  sh -n "$script"
done

mkdir -p "$TMP_DIR/repo/docs/superpowers/plans"
git -C "$TMP_DIR/repo" init -q
printf '%s\n' "# Approved plan" >"$TMP_DIR/repo/docs/superpowers/plans/task.md"
git -C "$TMP_DIR/repo" add docs/superpowers/plans/task.md
FAKE_CONTEXT_ID=$(printf '%s' "$(CDPATH= cd -- "$TMP_DIR/repo" && pwd -P)" | cksum | awk '{print $1}')
export FAKE_CONTEXT_ID
HERDR_WORKER_TURN_TOKEN=test-turn
export HERDR_WORKER_TURN_TOKEN
unset HERDR_PANE_ID HERDR_TAB_ID

run_dry() {
  HERDR_ENV=1 \
    HERDR_WORKER_DRY_RUN=1 \
    HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
    HERDR_WORKER_PROMPT_DIR="$PROMPT_DIR" \
    "$SCRIPT" "$@"
}

assert_fails_with "HERDR_ENV=1 is required" \
  env -u HERDR_ENV HERDR_WORKER_DRY_RUN=1 HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  "$SCRIPT" run explorer --task-id task --brief "find files"

assert_fails_with "role must be explorer, implementer, or reviewer" \
  env HERDR_ENV=1 HERDR_WORKER_DRY_RUN=1 HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  "$SCRIPT" run scout --task-id task --brief "find files"

assert_fails_with "invalid task id" \
  env HERDR_ENV=1 HERDR_WORKER_DRY_RUN=1 HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  "$SCRIPT" run explorer --task-id "bad task" --brief "find files"

assert_fails_with "--plan is required for implementer" \
  env HERDR_ENV=1 HERDR_WORKER_DRY_RUN=1 HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  "$SCRIPT" run implementer --task-id task --brief "implement"

assert_fails_with "--depth is only valid for explorer" \
  env HERDR_ENV=1 HERDR_WORKER_DRY_RUN=1 HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  "$SCRIPT" run reviewer --task-id task --plan docs/superpowers/plans/task.md --depth deep

printf '%s\n' "outside plan" >"$TMP_DIR/outside-plan.md"
ln -s "$TMP_DIR/outside-plan.md" "$TMP_DIR/repo/docs/superpowers/plans/symlink.md"
assert_fails_with "plan must not be a symlink" \
  env HERDR_ENV=1 HERDR_WORKER_DRY_RUN=1 HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  "$SCRIPT" run reviewer --task-id task --plan docs/superpowers/plans/symlink.md

explorer_output=$(run_dry run explorer --task-id task --brief "find files")
assert_contains "$explorer_output" "COMMAND=run"
assert_contains "$explorer_output" "ROLE=explorer"
assert_contains "$explorer_output" "BACKEND=cursor"
assert_contains "$explorer_output" "MODEL=composer-2.5"
assert_contains "$explorer_output" "READ_ONLY=1"
assert_contains "$explorer_output" "DEPTH=quick"
assert_contains "$explorer_output" "TASK_ID=task"

deep_output=$(run_dry run explorer --task-id task --brief "trace architecture" --depth deep)
assert_contains "$deep_output" "DEPTH=deep"

implementer_output=$(
  run_dry run implementer --task-id task --plan docs/superpowers/plans/task.md --brief "implement the plan"
)
assert_contains "$implementer_output" "ROLE=implementer"
assert_contains "$implementer_output" "MODEL=cursor-grok-4.5-high"
assert_contains "$implementer_output" "READ_ONLY=0"
assert_contains "$implementer_output" "PLAN=$TMP_DIR/repo/docs/superpowers/plans/task.md"
assert_contains "$implementer_output" "RETAIN_PANE=1"

reviewer_output=$(
  HERDR_WORKER_BACKEND=opencode run_dry run reviewer --task-id task --plan docs/superpowers/plans/task.md
)
assert_contains "$reviewer_output" "ROLE=reviewer"
assert_contains "$reviewer_output" "BACKEND=opencode"
assert_contains "$reviewer_output" "OPENCODE_AGENT=reviewer"
assert_contains "$reviewer_output" "READ_ONLY=1"
assert_contains "$reviewer_output" "RETAIN_PANE=0"

install_output=$(
  HERDR_WORKER_INSTALL_DRY_RUN=1 \
    HERDR_WORKER_INSTALL_BIN_DIR="$TMP_DIR/install/bin" \
    HERDR_WORKER_INSTALL_CODEX_SKILLS_DIR="$TMP_DIR/install/codex/skills" \
    HERDR_WORKER_INSTALL_CLAUDE_SKILLS_DIR="$TMP_DIR/install/claude/skills" \
    HERDR_WORKER_INSTALL_CODEX_AGENTS_DIR="$TMP_DIR/install/codex/agents" \
    HERDR_WORKER_INSTALL_CLAUDE_AGENTS_DIR="$TMP_DIR/install/claude/agents" \
    "$INSTALL_SCRIPT"
)
assert_contains "$install_output" "$TMP_DIR/install/bin/herdr-worker -> $SCRIPT"
assert_contains "$install_output" "$TMP_DIR/install/codex/skills/orchestrating-herdr-workers -> $SKILL_DIR"
assert_contains "$install_output" "$TMP_DIR/install/claude/skills/orchestrating-herdr-workers -> $SKILL_DIR"
assert_contains "$install_output" "$TMP_DIR/install/codex/agents/orchestrator.toml -> $ROOT_DIR/.codex/agents/orchestrator.toml"
assert_contains "$install_output" "$TMP_DIR/install/claude/agents/orchestrator.md -> $ROOT_DIR/.claude/agents/orchestrator.md"
assert_not_contains "$install_output" "cursor/skills"
assert_not_contains "$install_output" "opencode/skills"

HERDR_WORKER_INSTALL_BIN_DIR="$TMP_DIR/installed/bin" \
  HERDR_WORKER_INSTALL_CODEX_SKILLS_DIR="$TMP_DIR/installed/codex/skills" \
  HERDR_WORKER_INSTALL_CLAUDE_SKILLS_DIR="$TMP_DIR/installed/claude/skills" \
  HERDR_WORKER_INSTALL_CODEX_AGENTS_DIR="$TMP_DIR/installed/codex/agents" \
  HERDR_WORKER_INSTALL_CLAUDE_AGENTS_DIR="$TMP_DIR/installed/claude/agents" \
  "$INSTALL_SCRIPT" >/dev/null

if [ "$(readlink "$TMP_DIR/installed/bin/herdr-worker")" != "$SCRIPT" ]; then
  printf '%s\n' "installer did not create the herdr-worker link" >&2
  exit 1
fi
if [ "$(readlink "$TMP_DIR/installed/codex/skills/orchestrating-herdr-workers")" != "$SKILL_DIR" ]; then
  printf '%s\n' "installer did not create the Codex skill link" >&2
  exit 1
fi
if [ "$(readlink "$TMP_DIR/installed/claude/skills/orchestrating-herdr-workers")" != "$SKILL_DIR" ]; then
  printf '%s\n' "installer did not create the Claude skill link" >&2
  exit 1
fi

ALIAS_REPO="$TMP_DIR/alias-repo"
ALIAS_SKILL="$ALIAS_REPO/.agents/skills/orchestrating-herdr-workers"
mkdir -p "$ALIAS_SKILL/scripts" "$ALIAS_REPO/.codex/agents" "$ALIAS_REPO/.claude/agents" "$TMP_DIR/alias-home"
cp "$INSTALL_SCRIPT" "$ALIAS_SKILL/scripts/install"
cp "$SCRIPT" "$ALIAS_SKILL/scripts/herdr-worker"
cp "$ROOT_DIR/.codex/agents/orchestrator.toml" "$ALIAS_REPO/.codex/agents/orchestrator.toml"
cp "$ROOT_DIR/.claude/agents/orchestrator.md" "$ALIAS_REPO/.claude/agents/orchestrator.md"
ln -s "$ALIAS_REPO/.codex/agents" "$TMP_DIR/alias-home/codex-agents"

HERDR_WORKER_INSTALL_BIN_DIR="$TMP_DIR/alias-install/bin" \
  HERDR_WORKER_INSTALL_CODEX_SKILLS_DIR="$TMP_DIR/alias-install/codex/skills" \
  HERDR_WORKER_INSTALL_CLAUDE_SKILLS_DIR="$TMP_DIR/alias-install/claude/skills" \
  HERDR_WORKER_INSTALL_CODEX_AGENTS_DIR="$TMP_DIR/alias-home/codex-agents" \
  HERDR_WORKER_INSTALL_CLAUDE_AGENTS_DIR="$TMP_DIR/alias-install/claude/agents" \
  "$ALIAS_SKILL/scripts/install" >/dev/null

if [ ! -f "$ALIAS_REPO/.codex/agents/orchestrator.toml" ] || [ -L "$ALIAS_REPO/.codex/agents/orchestrator.toml" ]; then
  printf '%s\n' "installer replaced an agent definition through an aliased parent directory" >&2
  exit 1
fi

FAKE_BIN="$TMP_DIR/fake-bin"
FAKE_LOG="$TMP_DIR/fake.log"
mkdir -p "$FAKE_BIN"

cat >"$FAKE_BIN/cursor-agent" <<'EOF'
#!/bin/sh
printf 'cursor-agent %s\n' "$*" >>"$FAKE_LOG"
case "${1:-}" in
  status) exit "${FAKE_CURSOR_PREFLIGHT_STATUS:-0}" ;;
  models)
    printf '%s\n' "composer-2.5" "cursor-grok-4.5-high"
    exit "${FAKE_CURSOR_MODELS_STATUS:-0}"
    ;;
esac
if [ -n "${FAKE_CURSOR_EDIT_PATH:-}" ]; then
  printf '%s\n' "cursor edit" >>"$FAKE_CURSOR_EDIT_PATH"
fi
exit "${FAKE_CURSOR_RUN_STATUS:-0}"
EOF

cat >"$FAKE_BIN/mise" <<'EOF'
#!/bin/sh
printf 'mise %s\n' "$*" >>"$FAKE_LOG"
exit "${FAKE_OPENCODE_STATUS:-0}"
EOF

cat >"$FAKE_BIN/herdr" <<'EOF'
#!/bin/sh
printf 'herdr %s\n' "$*" >>"$FAKE_LOG"
case "$1 $2" in
  "pane list")
    if [ "${FAKE_PANE_LIST:-}" = "task" ]; then
      cat <<JSON
{"result":{"panes":[{"focused":true,"workspace_id":"ws","tab_id":"tab-focus","pane_id":"pane-focus"},{"focused":false,"workspace_id":"ws","tab_id":"tab-focus","pane_id":"pane-impl","label":"herdr-worker:${FAKE_CONTEXT_ID}:task:implementer:cursor:123:success"},{"focused":false,"workspace_id":"ws","tab_id":"tab-focus","pane_id":"pane-review","label":"herdr-worker:${FAKE_CONTEXT_ID}:task:reviewer:cursor:124:success"},{"focused":false,"workspace_id":"ws","tab_id":"tab-focus","pane_id":"pane-blocked","label":"herdr-worker:${FAKE_CONTEXT_ID}:task:reviewer:cursor:125:blocked"},{"focused":false,"workspace_id":"ws","tab_id":"tab-other","pane_id":"pane-other-tab","label":"herdr-worker:${FAKE_CONTEXT_ID}:task:reviewer:cursor:126:success"}]}}
JSON
    else
      printf '%s\n' '{"result":{"panes":[{"focused":true,"workspace_id":"ws","tab_id":"tab-focus","pane_id":"pane-focus"}]}}'
    fi
    ;;
  "pane layout")
    printf '{"result":{"layout":{"panes":[{"pane_id":"pane-focus","rect":{"width":%s,"height":%s}}]}}}\n' \
      "${FAKE_LAYOUT_WIDTH:-180}" "${FAKE_LAYOUT_HEIGHT:-50}"
    ;;
  "pane split")
    printf '%s\n' '{"result":{"pane":{"pane_id":"pane-new","tab_id":"tab-focus"}}}'
    ;;
  "pane rename")
    ;;
  "pane read")
    printf '%s\n' "startup output"
    ;;
  "agent get")
    if [ "${FAKE_HERDR_GET_STATUS:-0}" -ne 0 ]; then
      exit "$FAKE_HERDR_GET_STATUS"
    fi
    if [ -n "${FAKE_HERDR_STATUS_SEQUENCE_FILE:-}" ]; then
      if [ ! -e "$FAKE_HERDR_STATUS_SEQUENCE_FILE" ]; then
        : >"$FAKE_HERDR_STATUS_SEQUENCE_FILE"
        _fake_status=working
      else
        _fake_status="${FAKE_HERDR_FINAL_STATUS:-done}"
      fi
    else
      _fake_status="${FAKE_HERDR_STATUS:-done}"
    fi
    printf '{"result":{"agent_status":"%s"}}\n' "$_fake_status"
    ;;
  "agent read")
    _fake_token="${FAKE_STATUS_TOKEN:-$HERDR_WORKER_TURN_TOKEN}"
    # Shell banner and the echoed prompt always precede the report in a real
    # pane snapshot. The echoed instruction names both markers mid-sentence, so
    # it must not be mistaken for a marker line.
    printf '%s\n' "Welcome to fish, the friendly interactive shell"
    printf '%s\n' "  -> Begin the final response with REPORT[${_fake_token}]: BEGIN alone on its own line."
    if [ "${FAKE_PRIOR_TURN:-0}" = "1" ]; then
      printf '%s\n' "REPORT[old-turn]: BEGIN"
      printf '%s\n' "PRIOR_TURN_BODY"
      printf '%s\n' "STATUS[old-turn]: DONE"
    fi
    if [ "${FAKE_OMIT_BEGIN:-0}" != "1" ]; then
      if [ "${FAKE_DUPLICATE_BEGIN:-0}" = "1" ]; then
        printf 'REPORT[%s]: BEGIN\n' "$_fake_token"
        printf '%s\n' "DISCARDED_BY_LATER_BEGIN"
      fi
      printf '  REPORT[%s]: BEGIN\n' "$_fake_token"
    fi
    printf '%s\n' "FILES_CHANGED: none"
    if [ "${FAKE_OMIT_STATUS:-0}" = "1" ]; then
      printf '%s\n' "STATUS[old-turn]: DONE"
    else
      printf '  STATUS[%s]: %s\n' "$_fake_token" \
        "${FAKE_WORKER_REPORTED_STATUS:-DONE}"
    fi
    printf '%s\n' "Composer 2.5 | dotfiles | main +25 | ctx 34%"
    ;;
  "pane run")
    # Surface the generated prompt so marker injection on the run path is
    # observable; the job dir is removed once the run succeeds.
    _fake_launcher=$(printf '%s\n' "$4" | sed -n "s/^sh '\(.*\)'$/\1/p")
    if [ -r "$_fake_launcher" ]; then
      _fake_prompt=$(sed -n "s/.*'\([^']*prompt\.md\)'.*/\1/p" "$_fake_launcher")
      if [ -r "$_fake_prompt" ]; then
        printf 'PROMPT_BEGIN\n' >>"$FAKE_LOG"
        cat "$_fake_prompt" >>"$FAKE_LOG"
        printf 'PROMPT_END\n' >>"$FAKE_LOG"
      fi
    fi
    ;;
  "agent wait"|"agent prompt"|"pane close")
    ;;
  *)
    printf '%s\n' "unexpected fake herdr command: $*" >&2
    exit 1
    ;;
esac
EOF

chmod +x "$FAKE_BIN/cursor-agent" "$FAKE_BIN/mise" "$FAKE_BIN/herdr"
printf '%s\n' "worker prompt" >"$TMP_DIR/worker-prompt.md"

: >"$FAKE_LOG"
PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_WORKER_CURSOR_BIN=cursor-agent \
  "$RUNNER" cursor explorer "$TMP_DIR/repo" "$TMP_DIR/worker-prompt.md"
runner_log=$(cat "$FAKE_LOG")
assert_contains "$runner_log" "cursor-agent --workspace $TMP_DIR/repo --model composer-2.5 --mode ask"
assert_not_contains "$runner_log" "mise exec -- opencode"

: >"$FAKE_LOG"
PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_WORKER_CURSOR_BIN=cursor-agent \
  FAKE_CURSOR_PREFLIGHT_STATUS=1 "$RUNNER" cursor implementer "$TMP_DIR/repo" "$TMP_DIR/worker-prompt.md"
fallback_log=$(cat "$FAKE_LOG")
assert_contains "$fallback_log" "cursor-agent status"
assert_contains "$fallback_log" "mise exec -- opencode $TMP_DIR/repo --agent implementer --mini"

: >"$FAKE_LOG"
if PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_WORKER_CURSOR_BIN=cursor-agent \
  FAKE_CURSOR_PREFLIGHT_STATUS=129 "$RUNNER" cursor implementer "$TMP_DIR/repo" "$TMP_DIR/worker-prompt.md"; then
  printf '%s\n' "signal-derived Cursor status preflight returned success" >&2
  exit 1
fi
preflight_signal_log=$(cat "$FAKE_LOG")
assert_not_contains "$preflight_signal_log" "mise exec -- opencode"

: >"$FAKE_LOG"
if PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_WORKER_CURSOR_BIN=cursor-agent \
  FAKE_CURSOR_MODELS_STATUS=129 "$RUNNER" cursor implementer "$TMP_DIR/repo" "$TMP_DIR/worker-prompt.md"; then
  printf '%s\n' "signal-derived Cursor models preflight returned success" >&2
  exit 1
fi
models_signal_log=$(cat "$FAKE_LOG")
assert_not_contains "$models_signal_log" "mise exec -- opencode"

: >"$FAKE_LOG"
if PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_WORKER_CURSOR_BIN=cursor-agent \
  FAKE_CURSOR_RUN_STATUS=75 "$RUNNER" cursor reviewer "$TMP_DIR/repo" "$TMP_DIR/worker-prompt.md"; then
  printf '%s\n' "post-launch Cursor failure returned success" >&2
  exit 1
fi
unchanged_log=$(cat "$FAKE_LOG")
assert_contains "$unchanged_log" "cursor-agent --workspace $TMP_DIR/repo --model composer-2.5 --mode ask"
assert_not_contains "$unchanged_log" "mise exec -- opencode"

: >"$FAKE_LOG"
if PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_WORKER_CURSOR_BIN=cursor-agent \
  FAKE_CURSOR_RUN_STATUS=129 "$RUNNER" cursor reviewer "$TMP_DIR/repo" "$TMP_DIR/worker-prompt.md"; then
  printf '%s\n' "signal-derived Cursor exit returned success" >&2
  exit 1
fi
signal_log=$(cat "$FAKE_LOG")
assert_not_contains "$signal_log" "mise exec -- opencode"

git -C "$TMP_DIR/repo" checkout -- docs/superpowers/plans/task.md
: >"$FAKE_LOG"
if PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_WORKER_CURSOR_BIN=cursor-agent \
  FAKE_CURSOR_RUN_STATUS=75 FAKE_CURSOR_EDIT_PATH="$TMP_DIR/repo/docs/superpowers/plans/task.md" \
  "$RUNNER" cursor implementer "$TMP_DIR/repo" "$TMP_DIR/worker-prompt.md"; then
  printf '%s\n' "runner fell back after Cursor changed the worktree" >&2
  exit 1
fi
changed_log=$(cat "$FAKE_LOG")
assert_not_contains "$changed_log" "mise exec -- opencode"
git -C "$TMP_DIR/repo" checkout -- docs/superpowers/plans/task.md

: >"$FAKE_LOG"
PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  FAKE_HERDR_STATUS_SEQUENCE_FILE="$TMP_DIR/herdr-status-sequence" \
  "$SCRIPT" run explorer --task-id task --brief "find files" >/dev/null
explorer_runtime_log=$(cat "$FAKE_LOG")
assert_contains "$explorer_runtime_log" "herdr pane layout --pane pane-focus"
assert_contains "$explorer_runtime_log" "herdr pane split --pane pane-focus --direction right --cwd $TMP_DIR/repo --no-focus"
assert_contains "$explorer_runtime_log" "herdr agent wait pane-new --until idle --until done --until blocked"
assert_contains "$explorer_runtime_log" "herdr pane close pane-new"
assert_not_contains "$explorer_runtime_log" "herdr tab"
first_agent_get_line=$(printf '%s\n' "$explorer_runtime_log" | grep -n -F "herdr agent get pane-new" | head -n 1 | cut -d: -f1)
agent_wait_line=$(printf '%s\n' "$explorer_runtime_log" | grep -n -F "herdr agent wait pane-new" | head -n 1 | cut -d: -f1)
if [ "$first_agent_get_line" -ge "$agent_wait_line" ]; then
  printf '%s\n' "worker did not wait for agent recognition before lifecycle wait" >&2
  exit 1
fi

: >"$FAKE_LOG"
sliced_report=$(
  PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
    "$SCRIPT" run explorer --task-id task --brief "find files"
)
assert_contains "$sliced_report" "FILES_CHANGED: none"
assert_not_contains "$sliced_report" "Welcome to fish"
assert_not_contains "$sliced_report" "Composer 2.5"
assert_not_contains "$sliced_report" "REPORT[test-turn]: BEGIN"
assert_not_contains "$sliced_report" "STATUS[test-turn]: DONE"
sliced_log=$(cat "$FAKE_LOG")
assert_contains "$sliced_log" "herdr agent read pane-new --source recent-unwrapped --lines 100000"
assert_not_contains "$sliced_log" "--lines 200"
assert_contains "$sliced_log" "REPORT[test-turn]: BEGIN"
assert_contains "$sliced_log" "STATUS[test-turn]: <result>"

: >"$FAKE_LOG"
if PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  FAKE_OMIT_BEGIN=1 "$SCRIPT" run explorer --task-id task --brief "find files" \
  >"$TMP_DIR/no-begin.out" 2>"$TMP_DIR/no-begin.err"; then
  printf '%s\n' "report without a start marker returned success" >&2
  exit 1
fi
no_begin_log=$(cat "$FAKE_LOG")
assert_not_contains "$no_begin_log" "herdr pane close pane-new"
assert_contains "$(cat "$TMP_DIR/no-begin.out")" "FAILURE_SIGNATURE: worker/report/truncated-or-malformed"

: >"$FAKE_LOG"
duplicate_begin_report=$(
  PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
    FAKE_DUPLICATE_BEGIN=1 "$SCRIPT" run explorer --task-id task --brief "find files"
)
assert_contains "$duplicate_begin_report" "FILES_CHANGED: none"
assert_not_contains "$duplicate_begin_report" "DISCARDED_BY_LATER_BEGIN"

: >"$FAKE_LOG"
PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_PANE_ID=pane-focus HERDR_TAB_ID=tab-focus \
  FAKE_LAYOUT_WIDTH=100 FAKE_LAYOUT_HEIGHT=50 HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  "$SCRIPT" run explorer --task-id task --brief "find files" >/dev/null
down_split_log=$(cat "$FAKE_LOG")
assert_contains "$down_split_log" "herdr pane split --pane pane-focus --direction down --cwd $TMP_DIR/repo --no-focus"

: >"$FAKE_LOG"
PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_PANE_ID=pane-focus HERDR_TAB_ID=tab-focus \
  FAKE_LAYOUT_WIDTH=180 FAKE_LAYOUT_HEIGHT=100 HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  "$SCRIPT" run explorer --task-id task --brief "find files" >/dev/null
tall_split_log=$(cat "$FAKE_LOG")
assert_contains "$tall_split_log" "herdr pane split --pane pane-focus --direction down --cwd $TMP_DIR/repo --no-focus"

: >"$FAKE_LOG"
if PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= \
  HERDR_WORKER_STARTUP_ATTEMPTS=1 HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  FAKE_HERDR_GET_STATUS=1 "$SCRIPT" run explorer --task-id task --brief "find files" \
  >"$TMP_DIR/startup.out" 2>"$TMP_DIR/startup.err"; then
  printf '%s\n' "undetected agent startup returned success" >&2
  exit 1
fi
startup_log=$(cat "$FAKE_LOG")
assert_not_contains "$startup_log" "herdr pane close pane-new"
assert_contains "$(cat "$TMP_DIR/startup.out")" "FAILURE_SIGNATURE: herdr/agent/startup-not-detected"

: >"$FAKE_LOG"
if PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= \
  HERDR_WORKER_STARTUP_ATTEMPTS=1 HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  FAKE_HERDR_STATUS=idle "$SCRIPT" run explorer --task-id task --brief "find files" \
  >"$TMP_DIR/startup-idle.out" 2>"$TMP_DIR/startup-idle.err"; then
  printf '%s\n' "startup idle was treated as completed work" >&2
  exit 1
fi
startup_idle_log=$(cat "$FAKE_LOG")
assert_not_contains "$startup_idle_log" "herdr agent wait pane-new"
assert_not_contains "$startup_idle_log" "herdr pane close pane-new"

assert_fails_with "an implementer pane already exists for task: task" \
  env PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= \
  FAKE_PANE_LIST=task HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  "$SCRIPT" run implementer --task-id task --plan docs/superpowers/plans/task.md

: >"$FAKE_LOG"
PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  "$SCRIPT" run implementer --task-id task --plan docs/superpowers/plans/task.md >/dev/null
implementer_runtime_log=$(cat "$FAKE_LOG")
assert_not_contains "$implementer_runtime_log" "herdr pane close pane-new"

: >"$FAKE_LOG"
if PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  FAKE_HERDR_STATUS=blocked "$SCRIPT" run reviewer --task-id task \
  --plan docs/superpowers/plans/task.md >"$TMP_DIR/blocked.out" 2>"$TMP_DIR/blocked.err"; then
  printf '%s\n' "blocked reviewer returned success" >&2
  exit 1
fi
blocked_log=$(cat "$FAKE_LOG")
assert_not_contains "$blocked_log" "herdr pane close pane-new"
assert_contains "$(cat "$TMP_DIR/blocked.out")" "AGENT_STATUS: blocked"

: >"$FAKE_LOG"
if PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  FAKE_HERDR_STATUS_SEQUENCE_FILE="$TMP_DIR/herdr-unknown-sequence" FAKE_HERDR_FINAL_STATUS=unknown \
  "$SCRIPT" run reviewer --task-id task \
  --plan docs/superpowers/plans/task.md >"$TMP_DIR/unknown.out" 2>"$TMP_DIR/unknown.err"; then
  printf '%s\n' "unknown reviewer status returned success" >&2
  exit 1
fi
unknown_log=$(cat "$FAKE_LOG")
assert_not_contains "$unknown_log" "herdr pane close pane-new"
assert_contains "$(cat "$TMP_DIR/unknown.out")" "AGENT_STATUS: unknown"

: >"$FAKE_LOG"
if PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  FAKE_HERDR_STATUS=done FAKE_WORKER_REPORTED_STATUS=BLOCKED "$SCRIPT" run reviewer --task-id task \
  --plan docs/superpowers/plans/task.md >"$TMP_DIR/semantic-blocked.out" 2>"$TMP_DIR/semantic-blocked.err"; then
  printf '%s\n' "semantic worker blocker returned success" >&2
  exit 1
fi
semantic_blocked_log=$(cat "$FAKE_LOG")
assert_not_contains "$semantic_blocked_log" "herdr pane close pane-new"
assert_contains "$semantic_blocked_log" "herdr pane rename pane-new"

: >"$FAKE_LOG"
PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= FAKE_PANE_LIST=task HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  "$SCRIPT" follow-up implementer --task-id task --brief "apply accepted finding" >/dev/null
follow_up_log=$(cat "$FAKE_LOG")
assert_contains "$follow_up_log" "herdr agent prompt pane-impl apply accepted finding"
assert_contains "$follow_up_log" "--until idle --until done --until blocked"
assert_contains "$follow_up_log" "REPORT[test-turn]: BEGIN"
assert_contains "$follow_up_log" "herdr agent read pane-impl --source recent-unwrapped --lines 100000"

: >"$FAKE_LOG"
follow_up_report=$(
  PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= FAKE_PANE_LIST=task \
    HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" FAKE_PRIOR_TURN=1 \
    "$SCRIPT" follow-up implementer --task-id task --brief "apply accepted finding"
)
assert_contains "$follow_up_report" "FILES_CHANGED: none"
assert_not_contains "$follow_up_report" "PRIOR_TURN_BODY"
assert_not_contains "$follow_up_report" "REPORT[old-turn]: BEGIN"
assert_not_contains "$follow_up_report" "STATUS[old-turn]: DONE"

: >"$FAKE_LOG"
if PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= FAKE_PANE_LIST=task \
  HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" FAKE_HERDR_STATUS=blocked \
  "$SCRIPT" follow-up implementer --task-id task --brief "apply accepted finding" \
  >"$TMP_DIR/follow-up-blocked.out" 2>"$TMP_DIR/follow-up-blocked.err"; then
  printf '%s\n' "blocked implementer follow-up returned success" >&2
  exit 1
fi
assert_contains "$(cat "$TMP_DIR/follow-up-blocked.out")" "AGENT_STATUS: blocked"

: >"$FAKE_LOG"
if PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= FAKE_PANE_LIST=task \
  HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" FAKE_HERDR_STATUS=done FAKE_OMIT_STATUS=1 \
  "$SCRIPT" follow-up implementer --task-id task --brief "apply accepted finding" \
  >"$TMP_DIR/follow-up-stale.out" 2>"$TMP_DIR/follow-up-stale.err"; then
  printf '%s\n' "follow-up reused a stale completion marker" >&2
  exit 1
fi
follow_up_stale_log=$(cat "$FAKE_LOG")
assert_contains "$follow_up_stale_log" "herdr pane rename pane-impl"

: >"$FAKE_LOG"
status_output=$(
  PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= FAKE_PANE_LIST=task HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
    "$SCRIPT" status --task-id task
)
assert_contains "$status_output" '"task_id": "task"'
assert_contains "$status_output" '"tab_id": "tab-focus"'
assert_contains "$status_output" '"panes"'
assert_not_contains "$status_output" 'pane-other-tab'

: >"$FAKE_LOG"
PATH="$FAKE_BIN:$PATH" FAKE_LOG="$FAKE_LOG" HERDR_ENV=1 HERDR_WORKSPACE_ID= FAKE_PANE_LIST=task HERDR_WORKER_REPO_ROOT="$TMP_DIR/repo" \
  "$SCRIPT" close --task-id task --role reviewer
close_log=$(cat "$FAKE_LOG")
assert_contains "$close_log" "herdr pane close pane-review"
assert_not_contains "$close_log" "herdr pane close pane-impl"
assert_not_contains "$close_log" "herdr pane close pane-blocked"
assert_not_contains "$close_log" "herdr pane close pane-other-tab"

printf '%s\n' "PASS: orchestrating-herdr-workers"
