# Herdr Agent Skill Script Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the `using-herdr-agents` skill package as a skill-plus-script workflow before considering Codex plugin packaging.

**Architecture:** Keep `herdr-agent` as the role dispatcher and prompt assembler. Move Agy-specific execution into a package-local runner so timeout, permission mode, empty-output checks, and failure classification are centralized. Add a package-local doctor command that verifies scripts, prompts, symlinks, and backend command availability without changing user configuration.

**Tech Stack:** POSIX shell, markdown, existing shell regression test.

## Global Constraints

- Keep the work scoped to `.agents/skills/using-herdr-agents`, `tests/herdr-agent.sh`, and the Herdr section of `README.md`.
- Do not introduce Codex plugin packaging in this pass.
- Do not add new external dependencies.
- Keep all shell scripts POSIX `sh`.
- Preserve existing role defaults: Scout uses OpenCode Go by default, Coder and Auditor use Agy, Advisor uses Codex.
- Preserve the current activation gate: the `using-herdr-agents` skill is used only when explicitly named.
- Do not commit, push, tag, merge, rebase, reset, or revert user changes.

---

## File Structure

- Create `.agents/skills/using-herdr-agents/scripts/herdr-agent-agy-run`: Agy backend runner for `coder` and `auditor`. Owns Agy flags, timeout, prompt-file loading, stdout/stderr capture for one-shot mode, empty-output detection, and stable failure classification.
- Create `.agents/skills/using-herdr-agents/scripts/herdr-agent-doctor`: health check command for the package. Verifies package files, prompt files, installed symlinks, and runtime commands. It must report `OK`, `WARN`, and `FAIL`, and exit nonzero only when at least one `FAIL` exists.
- Modify `.agents/skills/using-herdr-agents/scripts/herdr-agent`: keep prompt assembly and non-Agy backend dispatch; write the assembled prompt to a temporary file and call `herdr-agent-agy-run` for Agy roles.
- Modify `.agents/skills/using-herdr-agents/scripts/install`: install a `herdr-agent-doctor` symlink alongside existing user-facing commands. Do not install `herdr-agent-agy-run` as a user-facing command.
- Modify `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`: cover the new scripts, install symlink, Agy runner behavior, doctor behavior, and runner delegation.
- Modify `.agents/skills/using-herdr-agents/SKILL.md`: document the doctor command, Agy runner boundary, and cost/decision discipline.
- Modify `README.md`: update Herdr operational contract and validation examples.
- Modify root `tests/herdr-agent.sh` only if the package-local test path changes. Expected outcome: no root-wrapper change.

---

### Task 1: Add Regression Coverage for New Script Boundaries

**Files:**
- Modify: `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`

**Interfaces:**
- Consumes: existing `SCRIPT`, `SESSION_SCRIPT`, `INSTALL_SCRIPT`, `LIB_SCRIPT`, `PROMPT_DIR`, `TMP_DIR`, `assert_contains`, `assert_not_contains`, and `assert_fails_with`.
- Produces: failing assertions that define the new scripts and install surface before implementation.

- [ ] **Step 1: Define new script paths in the package test**

In `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`, replace the variable block near the top:

```sh
SCRIPT="$SKILL_DIR/scripts/herdr-agent"
SESSION_SCRIPT="$SKILL_DIR/scripts/herdr-agent-session"
INSTALL_SCRIPT="$SKILL_DIR/scripts/install"
LIB_SCRIPT="$SKILL_DIR/scripts/herdr-agent-lib"
PROMPT_DIR="$SKILL_DIR/prompts"
```

with:

```sh
SCRIPT="$SKILL_DIR/scripts/herdr-agent"
SESSION_SCRIPT="$SKILL_DIR/scripts/herdr-agent-session"
INSTALL_SCRIPT="$SKILL_DIR/scripts/install"
LIB_SCRIPT="$SKILL_DIR/scripts/herdr-agent-lib"
AGY_RUN_SCRIPT="$SKILL_DIR/scripts/herdr-agent-agy-run"
DOCTOR_SCRIPT="$SKILL_DIR/scripts/herdr-agent-doctor"
PROMPT_DIR="$SKILL_DIR/prompts"
```

- [ ] **Step 2: Include the new scripts in syntax and readability checks**

Replace the existing syntax-check loop:

```sh
for script in "$SCRIPT" "$SESSION_SCRIPT" "$INSTALL_SCRIPT" "$LIB_SCRIPT" "$0"
do
  if ! sh -n "$script"; then
    printf '%s\n' "syntax validation failed for: $script" >&2
    exit 1
  fi
done
```

with:

```sh
for script in "$SCRIPT" "$SESSION_SCRIPT" "$INSTALL_SCRIPT" "$LIB_SCRIPT" "$AGY_RUN_SCRIPT" "$DOCTOR_SCRIPT" "$0"
do
  if ! sh -n "$script"; then
    printf '%s\n' "syntax validation failed for: $script" >&2
    exit 1
  fi
done
```

Replace the readable-file list:

```sh
for file in "$SKILL_FILE" "$SCRIPT" "$SESSION_SCRIPT" "$INSTALL_SCRIPT" "$LIB_SCRIPT" \
  "$PROMPT_DIR/shared.md" "$PROMPT_DIR/scout.md" "$PROMPT_DIR/coder.md" \
  "$PROMPT_DIR/auditor.md" "$PROMPT_DIR/advisor.md"
```

with:

```sh
for file in "$SKILL_FILE" "$SCRIPT" "$SESSION_SCRIPT" "$INSTALL_SCRIPT" "$LIB_SCRIPT" \
  "$AGY_RUN_SCRIPT" "$DOCTOR_SCRIPT" \
  "$PROMPT_DIR/shared.md" "$PROMPT_DIR/scout.md" "$PROMPT_DIR/coder.md" \
  "$PROMPT_DIR/auditor.md" "$PROMPT_DIR/advisor.md"
```

- [ ] **Step 3: Add failing install assertions for the doctor symlink**

After the existing dry-run install assertions:

```sh
assert_contains "$install_output" "$TMP_DIR/bin/herdr-agent -> $SKILL_DIR/scripts/herdr-agent"
assert_contains "$install_output" "$TMP_DIR/bin/herdr-agent-session -> $SKILL_DIR/scripts/herdr-agent-session"
assert_contains "$install_output" "$TMP_DIR/config/herdr/agents -> $SKILL_DIR/prompts"
assert_contains "$install_output" "$TMP_DIR/skills/using-herdr-agents -> $SKILL_DIR"
```

add:

```sh
assert_contains "$install_output" "$TMP_DIR/bin/herdr-agent-doctor -> $SKILL_DIR/scripts/herdr-agent-doctor"
```

After the installed session dry-run assertion:

```sh
assert_contains "$installed_session_output" "RUNNER=$SKILL_DIR/scripts/herdr-agent"
```

add:

```sh
if [ "$(readlink "$TMP_DIR/installed/bin/herdr-agent-doctor")" != "$SKILL_DIR/scripts/herdr-agent-doctor" ]; then
  printf '%s\n' "install did not create the herdr-agent-doctor symlink" >&2
  exit 1
fi
```

- [ ] **Step 4: Add failing Agy runner dry-run assertions**

After the existing auditor dry-run assertions:

```sh
auditor_output=$(run_dry auditor "review diff")
assert_contains "$auditor_output" "ROLE=auditor"
assert_contains "$auditor_output" "BACKEND=agy"
assert_contains "$auditor_output" "MODEL=Gemini 3.5 Flash (Medium)"
```

add:

```sh
printf '%s\n' "prompt body" >"$TMP_DIR/prompt.md"

agy_coder_dry_output=$(
  HERDR_AGENT_AGY_RUN_DRY_RUN=1 "$AGY_RUN_SCRIPT" coder oneshot "Gemini 3.5 Flash (Medium)" "$ROOT_DIR" "$TMP_DIR/prompt.md"
)
assert_contains "$agy_coder_dry_output" "ROLE=coder"
assert_contains "$agy_coder_dry_output" "MODE=oneshot"
assert_contains "$agy_coder_dry_output" "PERMISSION=dangerously-skip-permissions"
assert_contains "$agy_coder_dry_output" "PROMPT_FILE=$TMP_DIR/prompt.md"

agy_auditor_dry_output=$(
  HERDR_AGENT_AGY_RUN_DRY_RUN=1 "$AGY_RUN_SCRIPT" auditor interactive "Gemini 3.5 Flash (Medium)" "$ROOT_DIR" "$TMP_DIR/prompt.md"
)
assert_contains "$agy_auditor_dry_output" "ROLE=auditor"
assert_contains "$agy_auditor_dry_output" "MODE=interactive"
assert_contains "$agy_auditor_dry_output" "PERMISSION=sandbox"
```

- [ ] **Step 5: Add failing Agy runner validation assertions**

After the dry-run assertions from Step 4, add:

```sh
assert_fails_with "herdr-agent-agy-run: role must be coder or auditor" \
  "$AGY_RUN_SCRIPT" scout oneshot "Gemini 3.5 Flash (Medium)" "$ROOT_DIR" "$TMP_DIR/prompt.md"

assert_fails_with "herdr-agent-agy-run: mode must be oneshot or interactive" \
  "$AGY_RUN_SCRIPT" coder bad "Gemini 3.5 Flash (Medium)" "$ROOT_DIR" "$TMP_DIR/prompt.md"

assert_fails_with "herdr-agent-agy-run: prompt file not readable" \
  "$AGY_RUN_SCRIPT" coder oneshot "Gemini 3.5 Flash (Medium)" "$ROOT_DIR" "$TMP_DIR/missing.md"
```

- [ ] **Step 6: Add failing doctor dry-run assertions**

Before the final `printf '%s\n' "PASS: using-herdr-agents"` line, add:

```sh
doctor_output=$(
  HERDR_AGENT_DOCTOR_DRY_RUN=1 \
    HERDR_AGENT_DOCTOR_HOME="$TMP_DIR/doctor-home" \
    HERDR_AGENT_DOCTOR_PATH="$TMP_DIR/installed/bin:$PATH" \
    "$DOCTOR_SCRIPT"
)
assert_contains "$doctor_output" "OK package file: scripts/herdr-agent"
assert_contains "$doctor_output" "OK package file: scripts/herdr-agent-agy-run"
assert_contains "$doctor_output" "OK package file: scripts/herdr-agent-doctor"
assert_contains "$doctor_output" "OK prompt file: prompts/shared.md"
assert_contains "$doctor_output" "WARN symlink not installed: herdr-agent"
assert_contains "$doctor_output" "WARN runtime command not checked in dry-run: agy"
assert_contains "$doctor_output" "SUMMARY:"
```

- [ ] **Step 7: Run the package test and verify it fails for missing scripts**

Run:

```sh
sh tests/herdr-agent.sh
```

Expected: fails before `PASS: using-herdr-agents`, with a readable error that references `.agents/skills/using-herdr-agents/scripts/herdr-agent-agy-run` or `.agents/skills/using-herdr-agents/scripts/herdr-agent-doctor`.

---

### Task 2: Implement the Package-Local Agy Runner

**Files:**
- Create: `.agents/skills/using-herdr-agents/scripts/herdr-agent-agy-run`
- Modify: `.agents/skills/using-herdr-agents/scripts/herdr-agent`

**Interfaces:**
- Consumes: `herdr-agent-agy-run <coder|auditor> <oneshot|interactive> <model> <repo_root> <prompt_file>`.
- Produces: a centralized Agy runner used by `herdr-agent` for Agy-backed roles.

- [ ] **Step 1: Create `herdr-agent-agy-run`**

Create `.agents/skills/using-herdr-agents/scripts/herdr-agent-agy-run` with:

```sh
#!/bin/sh
set -eu

usage() {
  printf '%s\n' "usage: $(basename "$0") <coder|auditor> <oneshot|interactive> <model> <repo_root> <prompt_file>" >&2
}

classify_failure() {
  status="$1"
  stderr_file="$2"
  if grep -E -i 'quota|rate limit|429|resource exhausted' "$stderr_file" >/dev/null 2>&1; then
    printf '%s\n' "herdr-agent-agy-run: FAILURE_CLASS=quota exit_status=$status" >&2
  elif grep -E -i 'auth|login|credential|api key|permission denied|unauthorized|forbidden' "$stderr_file" >/dev/null 2>&1; then
    printf '%s\n' "herdr-agent-agy-run: FAILURE_CLASS=auth exit_status=$status" >&2
  elif grep -E -i 'timeout|timed out|deadline' "$stderr_file" >/dev/null 2>&1; then
    printf '%s\n' "herdr-agent-agy-run: FAILURE_CLASS=timeout exit_status=$status" >&2
  else
    printf '%s\n' "herdr-agent-agy-run: FAILURE_CLASS=agy-exit-$status exit_status=$status" >&2
  fi
}

if [ "$#" -ne 5 ]; then
  usage
  exit 64
fi

role="$1"
mode="$2"
model="$3"
repo_root="$4"
prompt_file="$5"

case "$role" in
  coder)
    permission="dangerously-skip-permissions"
    permission_flag="--dangerously-skip-permissions"
    ;;
  auditor)
    permission="sandbox"
    permission_flag="--sandbox"
    ;;
  *)
    printf '%s\n' "herdr-agent-agy-run: role must be coder or auditor: $role" >&2
    exit 64
    ;;
esac

case "$mode" in
  oneshot|interactive) ;;
  *)
    printf '%s\n' "herdr-agent-agy-run: mode must be oneshot or interactive: $mode" >&2
    exit 65
    ;;
esac

if [ ! -d "$repo_root" ]; then
  printf '%s\n' "herdr-agent-agy-run: repo root not found: $repo_root" >&2
  exit 66
fi

if [ ! -r "$prompt_file" ]; then
  printf '%s\n' "herdr-agent-agy-run: prompt file not readable: $prompt_file" >&2
  exit 66
fi

prompt_bytes=$(wc -c <"$prompt_file" | tr -d ' ')

if [ "${HERDR_AGENT_AGY_RUN_DRY_RUN:-0}" = "1" ]; then
  printf 'ROLE=%s\n' "$role"
  printf 'MODE=%s\n' "$mode"
  printf 'MODEL=%s\n' "$model"
  printf 'REPO_ROOT=%s\n' "$repo_root"
  printf 'PROMPT_FILE=%s\n' "$prompt_file"
  printf 'PROMPT_BYTES=%s\n' "$prompt_bytes"
  printf 'PERMISSION=%s\n' "$permission"
  printf 'TIMEOUT=%s\n' "${HERDR_AGENT_AGY_TIMEOUT:-10m}"
  exit 0
fi

if ! command -v agy >/dev/null 2>&1; then
  printf '%s\n' "herdr-agent-agy-run: agy is required on PATH" >&2
  exit 127
fi

CDPATH= cd -- "$repo_root"
prompt=$(cat "$prompt_file")

if [ "$mode" = "interactive" ]; then
  exec agy \
    --model "$model" \
    --new-project \
    --add-dir "$repo_root" \
    "$permission_flag" \
    --prompt-interactive "$prompt"
fi

stdout_file=$(mktemp "${TMPDIR:-/tmp}/herdr-agent-agy-run.out.XXXXXX")
stderr_file=$(mktemp "${TMPDIR:-/tmp}/herdr-agent-agy-run.err.XXXXXX")
trap 'rm -f "$stdout_file" "$stderr_file"' EXIT HUP INT TERM

if agy \
  --model "$model" \
  --new-project \
  --add-dir "$repo_root" \
  "$permission_flag" \
  --print-timeout "${HERDR_AGENT_AGY_TIMEOUT:-10m}" \
  --print "$prompt" >"$stdout_file" 2>"$stderr_file" < /dev/null; then
  if [ ! -s "$stdout_file" ]; then
    printf '%s\n' "herdr-agent-agy-run: FAILURE_CLASS=empty-output exit_status=0" >&2
    if [ -s "$stderr_file" ]; then
      cat "$stderr_file" >&2
    fi
    exit 70
  fi
  cat "$stdout_file"
  if [ -s "$stderr_file" ]; then
    cat "$stderr_file" >&2
  fi
  exit 0
fi

status="$?"
classify_failure "$status" "$stderr_file"
if [ -s "$stderr_file" ]; then
  cat "$stderr_file" >&2
fi
if [ -s "$stdout_file" ]; then
  cat "$stdout_file"
fi
exit "$status"
```

- [ ] **Step 2: Make the new runner executable**

Run:

```sh
chmod +x .agents/skills/using-herdr-agents/scripts/herdr-agent-agy-run
```

Expected: no output, exit 0.

- [ ] **Step 3: Update `herdr-agent` to write prompt content to a temporary file**

In `.agents/skills/using-herdr-agents/scripts/herdr-agent`, after:

```sh
role_system_prompt=$(cat "$shared_prompt"; printf '\n\n'; cat "$role_prompt")
full_prompt=$(printf '%s\n\n# Repository Root\n\n%s\n\n# Task Brief\n\n%s\n' "$role_system_prompt" "$repo_root" "$task_prompt")
mode="${HERDR_AGENT_MODE:-oneshot}"
```

insert:

```sh
prompt_file=
cleanup_prompt_file() {
  if [ -n "${prompt_file:-}" ]; then
    rm -f "$prompt_file"
  fi
}
```

- [ ] **Step 4: Replace the Agy case in `herdr-agent`**

Replace the entire `agy)` case in `.agents/skills/using-herdr-agents/scripts/herdr-agent`:

```sh
  agy)
    CDPATH= cd -- "$repo_root"
    if [ "$mode" = "interactive" ]; then
      if [ "$role" = "coder" ]; then
        exec agy \
          --model "$model" \
          --new-project \
          --add-dir "$repo_root" \
          --dangerously-skip-permissions \
          --prompt-interactive "$full_prompt"
      fi
      exec agy \
        --model "$model" \
        --new-project \
        --add-dir "$repo_root" \
        --sandbox \
        --prompt-interactive "$full_prompt"
    fi
    if [ "$role" = "coder" ]; then
      exec agy \
        --model "$model" \
        --new-project \
        --add-dir "$repo_root" \
        --dangerously-skip-permissions \
        --print-timeout "${HERDR_AGENT_AGY_TIMEOUT:-10m}" \
        --print "$full_prompt" < /dev/null
    fi
    exec agy \
      --model "$model" \
      --new-project \
      --add-dir "$repo_root" \
      --sandbox \
      --print-timeout "${HERDR_AGENT_AGY_TIMEOUT:-10m}" \
      --print "$full_prompt" < /dev/null
    ;;
```

with:

```sh
  agy)
    agy_runner="$script_dir/herdr-agent-agy-run"
    if [ ! -x "$agy_runner" ]; then
      printf '%s\n' "herdr-agent: agy runner not executable: $agy_runner" >&2
      exit 127
    fi
    prompt_file=$(mktemp "${TMPDIR:-/tmp}/herdr-agent-prompt.XXXXXX")
    trap cleanup_prompt_file EXIT HUP INT TERM
    printf '%s\n' "$full_prompt" >"$prompt_file"
    "$agy_runner" "$role" "$mode" "$model" "$repo_root" "$prompt_file"
    status="$?"
    cleanup_prompt_file
    trap - EXIT HUP INT TERM
    exit "$status"
    ;;
```

- [ ] **Step 5: Run syntax validation**

Run:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-agy-run
```

Expected: no output, exit 0.

- [ ] **Step 6: Run the package test and verify Task 1 Agy assertions pass**

Run:

```sh
sh tests/herdr-agent.sh
```

Expected: still fails because `herdr-agent-doctor` and install symlink changes are not implemented yet. The failure must no longer mention `herdr-agent-agy-run` syntax or dry-run assertions.

---

### Task 3: Add the Doctor Command and Install Symlink

**Files:**
- Create: `.agents/skills/using-herdr-agents/scripts/herdr-agent-doctor`
- Modify: `.agents/skills/using-herdr-agents/scripts/install`

**Interfaces:**
- Consumes: package-local scripts and prompts.
- Produces: `herdr-agent-doctor`, installed as `~/.local/bin/herdr-agent-doctor` by `scripts/install`.

- [ ] **Step 1: Create `herdr-agent-doctor`**

Create `.agents/skills/using-herdr-agents/scripts/herdr-agent-doctor` with:

```sh
#!/bin/sh
set -eu

physical_dirname() {
  CDPATH= cd -- "$(dirname -- "$1")" && pwd -P
}

physical_path() {
  CDPATH= cd -- "$(dirname -- "$1")" && printf '%s/%s\n' "$(pwd -P)" "$(basename -- "$1")"
}

resolve_path() {
  target="$1"

  while [ -L "$target" ]; do
    link_target=$(readlink "$target")
    case "$link_target" in
      /*)
        target="$link_target"
        ;;
      *)
        target=$(physical_dirname "$target")/"$link_target"
        ;;
    esac
  done

  physical_path "$target"
}

ok_count=0
warn_count=0
fail_count=0

ok() {
  ok_count=$((ok_count + 1))
  printf 'OK %s\n' "$1"
}

warn() {
  warn_count=$((warn_count + 1))
  printf 'WARN %s\n' "$1"
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL %s\n' "$1"
}

script_path=$(resolve_path "$0")
script_dir=$(physical_dirname "$script_path")
skill_dir=$(CDPATH= cd -- "$script_dir/.." && pwd -P)

doctor_home="${HERDR_AGENT_DOCTOR_HOME:-$HOME}"
doctor_path="${HERDR_AGENT_DOCTOR_PATH:-$PATH}"
dry_run="${HERDR_AGENT_DOCTOR_DRY_RUN:-0}"

check_file() {
  rel="$1"
  path="$skill_dir/$rel"
  if [ -r "$path" ]; then
    ok "package file: $rel"
  else
    fail "package file not readable: $rel"
  fi
}

check_executable() {
  rel="$1"
  path="$skill_dir/$rel"
  if [ -x "$path" ]; then
    ok "executable: $rel"
  elif [ -r "$path" ]; then
    fail "script is readable but not executable: $rel"
  else
    fail "script not readable: $rel"
  fi
}

check_prompt() {
  rel="$1"
  path="$skill_dir/$rel"
  if [ -r "$path" ]; then
    ok "prompt file: $rel"
  else
    fail "prompt file not readable: $rel"
  fi
}

check_symlink_command() {
  name="$1"
  expected="$2"
  found=$(PATH="$doctor_path" command -v "$name" 2>/dev/null || true)
  if [ -z "$found" ]; then
    warn "symlink not installed: $name"
    return 0
  fi
  resolved=$(resolve_path "$found")
  if [ "$resolved" = "$expected" ]; then
    ok "symlink: $name -> $expected"
  else
    warn "command resolves outside this package: $name -> $resolved"
  fi
}

check_runtime_command() {
  name="$1"
  if [ "$dry_run" = "1" ]; then
    warn "runtime command not checked in dry-run: $name"
    return 0
  fi
  if PATH="$doctor_path" command -v "$name" >/dev/null 2>&1; then
    ok "runtime command on PATH: $name"
  else
    fail "runtime command missing from PATH: $name"
  fi
}

check_file "SKILL.md"
check_executable "scripts/herdr-agent"
check_executable "scripts/herdr-agent-session"
check_executable "scripts/herdr-agent-agy-run"
check_executable "scripts/herdr-agent-doctor"
check_executable "scripts/install"
check_file "scripts/herdr-agent-lib"
check_prompt "prompts/shared.md"
check_prompt "prompts/scout.md"
check_prompt "prompts/coder.md"
check_prompt "prompts/auditor.md"
check_prompt "prompts/advisor.md"

check_symlink_command "herdr-agent" "$skill_dir/scripts/herdr-agent"
check_symlink_command "herdr-agent-session" "$skill_dir/scripts/herdr-agent-session"
check_symlink_command "herdr-agent-doctor" "$skill_dir/scripts/herdr-agent-doctor"

agents_path="$doctor_home/.config/herdr/agents"
if [ -L "$agents_path" ]; then
  agents_resolved=$(resolve_path "$agents_path")
  if [ "$agents_resolved" = "$skill_dir/prompts" ]; then
    ok "Herdr agents symlink: $agents_path"
  else
    warn "Herdr agents symlink points elsewhere: $agents_resolved"
  fi
elif [ -e "$agents_path" ]; then
  warn "Herdr agents path exists but is not a symlink: $agents_path"
else
  warn "Herdr agents symlink not installed: $agents_path"
fi

check_runtime_command "herdr"
check_runtime_command "mise"
check_runtime_command "agy"
check_runtime_command "codex"

printf 'SUMMARY: ok=%s warn=%s fail=%s\n' "$ok_count" "$warn_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi

exit 0
```

- [ ] **Step 2: Make the doctor executable**

Run:

```sh
chmod +x .agents/skills/using-herdr-agents/scripts/herdr-agent-doctor
```

Expected: no output, exit 0.

- [ ] **Step 3: Install the doctor symlink**

In `.agents/skills/using-herdr-agents/scripts/install`, after:

```sh
link_pair "$skill_dir/scripts/herdr-agent-session" "$bin_dir/herdr-agent-session"
```

insert:

```sh
link_pair "$skill_dir/scripts/herdr-agent-doctor" "$bin_dir/herdr-agent-doctor"
```

- [ ] **Step 4: Run syntax validation**

Run:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent-doctor \
  .agents/skills/using-herdr-agents/scripts/install
```

Expected: no output, exit 0.

- [ ] **Step 5: Run the package test and verify all new script assertions pass**

Run:

```sh
sh tests/herdr-agent.sh
```

Expected: `PASS: using-herdr-agents`.

---

### Task 4: Document the Skill and Script Workflow

**Files:**
- Modify: `.agents/skills/using-herdr-agents/SKILL.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: `herdr-agent`, `herdr-agent-session`, `herdr-agent-doctor`, `herdr-agent-agy-run`.
- Produces: user-facing guidance for operating the skill-plus-script workflow.

- [ ] **Step 1: Update the command boundary in `SKILL.md`**

In `.agents/skills/using-herdr-agents/SKILL.md`, replace the command boundary table:

```markdown
| Need | Command | Lifecycle |
| --- | --- | --- |
| single task, fresh context, routing check | `herdr-agent <role> "<brief>"` | one-shot |
| follow-up likely, context map useful, startup overhead matters | `herdr-agent-session <role> "<brief>"` | persistent |
| non-persistent pane run | `HERDR_AGENT_SESSION_MODE=oneshot herdr-agent-session <role> "<brief>"` | one-shot in Herdr |
```

with:

```markdown
| Need | Command | Lifecycle |
| --- | --- | --- |
| single task, fresh context, routing check | `herdr-agent <role> "<brief>"` | one-shot |
| follow-up likely, context map useful, startup overhead matters | `herdr-agent-session <role> "<brief>"` | persistent |
| non-persistent pane run | `HERDR_AGENT_SESSION_MODE=oneshot herdr-agent-session <role> "<brief>"` | one-shot in Herdr |
| installation and backend health check | `herdr-agent-doctor` | read-only diagnostic |
```

- [ ] **Step 2: Add an execution boundary section to `SKILL.md`**

After the command boundary table, add:

```markdown
## Script Boundary

`herdr-agent` owns role validation, prompt assembly, prompt directory resolution, and backend routing.
`herdr-agent-agy-run` owns Agy-specific execution for `coder` and `auditor`: `--new-project`, repository attachment, permission mode, timeout, empty-output checks, and failure classification.
`herdr-agent-doctor` is read-only. Use it before debugging routing problems, missing command errors, broken symlinks, or backend availability issues.

Failure classes emitted by `herdr-agent-agy-run` are operational evidence for the parent orchestrator. Treat `FAILURE_CLASS=quota`, `FAILURE_CLASS=auth`, `FAILURE_CLASS=timeout`, and `FAILURE_CLASS=empty-output` as reasons to stop retrying blindly and either fix the environment or escalate.
```

- [ ] **Step 3: Add cost and context discipline to `SKILL.md`**

After the existing line:

```markdown
Do not delegate when the parent agent can answer faster by reading a small file, making a trivial local edit, or running a simple check.
```

add:

```markdown
Keep delegation above the decision boundary: the parent orchestrator should send a compact brief and receive a compact report. Do not pass long chat history, unrelated diffs, or broad repository dumps to workers. Prefer one Scout pass plus direct parent reads over repeated worker rediscovery.
```

- [ ] **Step 4: Update validation commands in `SKILL.md`**

Replace the validation block in `.agents/skills/using-herdr-agents/SKILL.md`:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-lib \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-session \
  .agents/skills/using-herdr-agents/scripts/install \
  .agents/skills/using-herdr-agents/tests/herdr-agent.sh \
  tests/herdr-agent.sh
sh tests/herdr-agent.sh
HERDR_AGENT_DRY_RUN=1 herdr-agent scout "find files"
HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_REUSE=never herdr-agent-session scout "find files"
```

with:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-lib \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-session \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-agy-run \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-doctor \
  .agents/skills/using-herdr-agents/scripts/install \
  .agents/skills/using-herdr-agents/tests/herdr-agent.sh \
  tests/herdr-agent.sh
sh tests/herdr-agent.sh
HERDR_AGENT_DRY_RUN=1 herdr-agent scout "find files"
HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_REUSE=never herdr-agent-session scout "find files"
herdr-agent-doctor
```

- [ ] **Step 5: Update README operational contract**

In `README.md`, replace:

```markdown
- OpenCode and Cline are launched through `mise exec --`; Agy and Codex are launched directly.
- `scripts/install` only creates or updates symlinks for the package commands, prompts, and skill. It does not copy files or edit shell startup files.
- The root `tests/herdr-agent.sh` wrapper is the repo-level validation entrypoint.
```

with:

```markdown
- OpenCode and Cline are launched through `mise exec --`; Codex is launched directly.
- Agy execution is centralized in the package-local `scripts/herdr-agent-agy-run` runner so permission mode, timeout, empty-output checks, and failure classification stay consistent.
- `scripts/install` only creates or updates symlinks for the package commands, prompts, and skill. It does not copy files or edit shell startup files.
- `herdr-agent-doctor` is the read-only health check for symlinks, package files, prompts, and backend commands.
- The root `tests/herdr-agent.sh` wrapper is the repo-level validation entrypoint.
```

- [ ] **Step 6: Update README validation block**

Replace the README validation command block:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-lib \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-session \
  .agents/skills/using-herdr-agents/scripts/install \
  .agents/skills/using-herdr-agents/tests/herdr-agent.sh \
  tests/herdr-agent.sh
sh tests/herdr-agent.sh
```

with:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-lib \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-session \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-agy-run \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-doctor \
  .agents/skills/using-herdr-agents/scripts/install \
  .agents/skills/using-herdr-agents/tests/herdr-agent.sh \
  tests/herdr-agent.sh
sh tests/herdr-agent.sh
herdr-agent-doctor
```

- [ ] **Step 7: Run tests after docs updates**

Run:

```sh
sh tests/herdr-agent.sh
```

Expected: `PASS: using-herdr-agents`.

---

### Task 5: Final Verification

**Files:**
- Verify: `.agents/skills/using-herdr-agents/scripts/herdr-agent`
- Verify: `.agents/skills/using-herdr-agents/scripts/herdr-agent-lib`
- Verify: `.agents/skills/using-herdr-agents/scripts/herdr-agent-session`
- Verify: `.agents/skills/using-herdr-agents/scripts/herdr-agent-agy-run`
- Verify: `.agents/skills/using-herdr-agents/scripts/herdr-agent-doctor`
- Verify: `.agents/skills/using-herdr-agents/scripts/install`
- Verify: `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`
- Verify: `tests/herdr-agent.sh`
- Verify: `.agents/skills/using-herdr-agents/SKILL.md`
- Verify: `README.md`

**Interfaces:**
- Consumes: all changed package scripts and docs.
- Produces: final evidence that the skill-plus-script workflow is internally consistent.

- [ ] **Step 1: Run POSIX syntax checks**

Run:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-lib \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-session \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-agy-run \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-doctor \
  .agents/skills/using-herdr-agents/scripts/install \
  .agents/skills/using-herdr-agents/tests/herdr-agent.sh \
  tests/herdr-agent.sh
```

Expected: no output, exit 0.

- [ ] **Step 2: Run package regression tests**

Run:

```sh
sh tests/herdr-agent.sh
```

Expected: `PASS: using-herdr-agents`.

- [ ] **Step 3: Run dry-run checks for all public routes**

Run:

```sh
HERDR_AGENT_DRY_RUN=1 herdr-agent scout "find files"
HERDR_AGENT_DRY_RUN=1 herdr-agent coder "implement"
HERDR_AGENT_DRY_RUN=1 herdr-agent auditor "review"
HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_ADVISOR_THINKING=xhigh herdr-agent advisor "decide"
HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_REUSE=never herdr-agent-session scout "find files"
HERDR_AGENT_DOCTOR_DRY_RUN=1 herdr-agent-doctor
```

Expected:

```text
scout dry-run includes BACKEND=opencode and OPENCODE_AGENT=scout_v2
coder dry-run includes BACKEND=agy
auditor dry-run includes BACKEND=agy
advisor dry-run includes BACKEND=codex and THINKING=xhigh
session dry-run includes REUSE=never
doctor dry-run includes SUMMARY:
```

- [ ] **Step 4: Inspect final diff**

Run:

```sh
git diff -- .agents/skills/using-herdr-agents tests/herdr-agent.sh README.md
```

Expected:

```text
Diff is limited to the Herdr skill package, root Herdr test wrapper only if needed, and README Herdr documentation.
No unrelated formatting or user preference changes are present.
No Codex plugin manifest or marketplace file is added.
```

- [ ] **Step 5: Report outcome without committing**

Report:

```text
Changed files:
- .agents/skills/using-herdr-agents/scripts/herdr-agent-agy-run
- .agents/skills/using-herdr-agents/scripts/herdr-agent-doctor
- .agents/skills/using-herdr-agents/scripts/herdr-agent
- .agents/skills/using-herdr-agents/scripts/install
- .agents/skills/using-herdr-agents/tests/herdr-agent.sh
- .agents/skills/using-herdr-agents/SKILL.md
- README.md

Verification:
- sh -n ... -> pass
- sh tests/herdr-agent.sh -> pass
- dry-run route checks -> pass

Not done:
- Codex plugin packaging
- commit
```

---

## Self-Review

**Spec coverage:** The plan covers the requested skill-plus-script approach, Agy execution hardening, doctor diagnostics, skill guidance, README guidance, and regression tests. It intentionally excludes Codex plugin packaging.

**Placeholder scan:** The plan contains exact file paths, shell snippets, and verification commands. There are no deferred implementation markers.

**Interface consistency:** `herdr-agent-agy-run` has one interface throughout: `<coder|auditor> <oneshot|interactive> <model> <repo_root> <prompt_file>`. `herdr-agent-doctor` has no required arguments and uses environment variables only for dry-run and test isolation.
