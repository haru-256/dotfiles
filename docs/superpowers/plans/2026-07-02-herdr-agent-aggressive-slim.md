# Herdr Agent Aggressive Slim Implementation Plan

> **For agentic workers:** This document is retained as historical implementation context. The tasks are complete; do not treat it as an open implementation plan.

**Status:** Implemented and verified on 2026-07-02. The canonical current checks are `sh -n ...` for the package shell files and `sh tests/herdr-agent.sh`.

**Goal:** Slim the Herdr agent scripts so they rely on the skill package and mise-managed tool execution instead of old prompt fallbacks and Cline binary discovery.

**Architecture:** Keep the package root `.agents/skills/using-herdr-agents/` as the only normal runtime source. `herdr-agent` resolves itself through symlinks, reads package-local prompts, and launches tools through the chosen backend. `herdr-agent-session` remains a session lifecycle wrapper but validates Scout backend names before creating pane names or starting Herdr.

**Tech Stack:** POSIX shell, Herdr CLI, mise, OpenCode, Cline, Agy, Codex CLI, shell regression tests.

---

## Global Constraints

- Preserve unrelated dirty files: `.codex/config.toml`, `.config/mise/config.toml`, `.config/opencode/opencode.json`, `.config/zed/settings.json`, `.agent/`, and `.codex/hooks.json`.
- Do not change role/model defaults.
- Do not redesign prompts or OpenCode `scout_v2`.
- Do not change Herdr config/keybindings.
- Do not commit unless the user explicitly asks.
- Keep scripts POSIX `sh`.

## File Structure

- Modify: `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`
  - Responsibility: regression coverage for slim routing, removed fallbacks, invalid backend failures, and symlink entrypoints.
- Modify: `.agents/skills/using-herdr-agents/scripts/herdr-agent`
  - Responsibility: one-shot/interactive role runner with package-local prompt discovery and mise-owned Cline launch.
- Modify: `.agents/skills/using-herdr-agents/scripts/herdr-agent-session`
  - Responsibility: persistent Herdr session launcher with valid role/backend-derived naming.
- Read-only unless tests show docs drift: `.agents/skills/using-herdr-agents/SKILL.md`, `README.md`

---

### Task 1: Tighten Regression Tests First

**Files:**
- Modify: `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`

- [x] **Step 1: Add assertion helpers for absence and command failure**

In `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`, after `assert_contains()` add:

```sh
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
```

- [x] **Step 2: Update Cline dry-run expectations for hard-coded defaults**

Keep the existing Cline dry-run block, then add a second block immediately after it:

```sh
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
```

- [x] **Step 3: Add OpenCode agent override removal coverage**

After the default `scout_output` assertions, add:

```sh
scout_agent_override_output=$(
  HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PROMPT_DIR" \
    HERDR_AGENT_SCOUT_OPENCODE_AGENT=ignored_agent "$SCRIPT" scout "find files"
)
assert_contains "$scout_agent_override_output" "OPENCODE_AGENT=scout_v2"
assert_not_contains "$scout_agent_override_output" "ignored_agent"
```

- [x] **Step 4: Add invalid Scout backend failure coverage**

After the Cline dry-run assertions, add:

```sh
assert_fails_with "HERDR_AGENT_SCOUT_BACKEND must be opencode or cline" \
  env HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PROMPT_DIR" HERDR_AGENT_SCOUT_BACKEND=bad \
  "$SCRIPT" scout "find files"

assert_fails_with "HERDR_AGENT_SCOUT_BACKEND must be opencode or cline" \
  env HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_SCOUT_BACKEND=bad HERDR_AGENT_REUSE=never \
  "$SESSION_SCRIPT" scout "find files"
```

- [x] **Step 5: Add static removal checks**

Near the existing static checks for `# Repository Root`, `--add-dir`, and `--new-project`, add:

```sh
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
```

- [x] **Step 6: Run the test and confirm it fails before implementation**

Run:

```sh
sh tests/herdr-agent.sh
```

Expected: failure mentioning at least one of the removed compatibility strings or ignored override values. If the test passes before implementation, re-check that Steps 1-5 were applied.

---

### Task 2: Slim `herdr-agent`

**Files:**
- Modify: `.agents/skills/using-herdr-agents/scripts/herdr-agent`

- [x] **Step 1: Remove Cline binary discovery**

Delete the entire `find_real_cline()` function from `.agents/skills/using-herdr-agents/scripts/herdr-agent`. This removes `CLINE_BIN_PATH`, `mise which cline`, hard-coded version paths, npm/Bun/Homebrew fallbacks, and direct Cline binary execution.

- [x] **Step 2: Remove old prompt fallback state**

Remove the `dotfiles_root` assignment:

```sh
dotfiles_root=$(CDPATH= cd -- "$skill_dir/../../.." && pwd -P)
```

Then replace the prompt-dir block with exactly:

```sh
prompt_dir="${HERDR_AGENT_PROMPT_DIR:-$skill_dir/prompts}"
if [ ! -d "$prompt_dir" ]; then
  prompt_dir="$skill_dir/prompts"
fi
```

This keeps explicit test/debug override only when it points to an existing directory, and otherwise falls back to package prompts.

- [x] **Step 3: Hard-code Scout runner defaults while preserving model overrides**

In the `scout)` role block, replace the `opencode)` and `cline)` branches with:

```sh
      opencode)
        model="${HERDR_AGENT_SCOUT_MODEL:-opencode-go/deepseek-v4-flash}"
        agent="scout_v2"
        ;;
      cline)
        provider="cline-pass"
        model="${HERDR_AGENT_SCOUT_CLINE_MODEL:-deepseek-v4-flash}"
        thinking="low"
        ;;
```

Keep the existing invalid-backend branch:

```sh
      *)
        printf '%s\n' "herdr-agent: HERDR_AGENT_SCOUT_BACKEND must be opencode or cline: $backend" >&2
        exit 65
        ;;
```

- [x] **Step 4: Launch Cline through mise**

Replace the entire `cline)` backend execution branch with:

```sh
  cline)
    if ! command -v mise >/dev/null 2>&1; then
      printf '%s\n' "herdr-agent: mise is required for cline" >&2
      exit 127
    fi
    exec mise exec -- cline \
      --provider "$provider" \
      --model "$model" \
      --thinking "$thinking" \
      --cwd "$repo_root" \
      --system "$role_system_prompt" \
      "$task_prompt"
    ;;
```

- [x] **Step 5: Run focused syntax check**

Run:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent
```

Expected: exit 0 with no output.

- [x] **Step 6: Run package test**

Run:

```sh
sh tests/herdr-agent.sh
```

Expected: before Task 3, this command fails with `herdr-agent-session` invalid backend coverage still unmet. The output must not mention removed `herdr-agent` compatibility strings such as `CLINE_BIN_PATH` or `HERDR_AGENT_SCOUT_OPENCODE_AGENT`.

---

### Task 3: Validate Scout Backend in `herdr-agent-session`

**Files:**
- Modify: `.agents/skills/using-herdr-agents/scripts/herdr-agent-session`

- [x] **Step 1: Replace the Scout backend model derivation block**

In `.agents/skills/using-herdr-agents/scripts/herdr-agent-session`, replace the current `scout)` case block with:

```sh
  scout)
    backend_name="${HERDR_AGENT_SCOUT_BACKEND:-opencode}"
    case "$backend_name" in
      opencode)
        model_name="${HERDR_AGENT_SCOUT_MODEL:-opencode-go/deepseek-v4-flash}"
        ;;
      cline)
        model_name="${HERDR_AGENT_SCOUT_CLINE_MODEL:-deepseek-v4-flash}"
        ;;
      *)
        printf '%s\n' "herdr-agent-session: HERDR_AGENT_SCOUT_BACKEND must be opencode or cline: $backend_name" >&2
        exit 65
        ;;
    esac
    ;;
```

This removes the `unknown` backend name path before Herdr can create or reuse a pane.

- [x] **Step 2: Run focused syntax check**

Run:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent-session
```

Expected: exit 0 with no output.

- [x] **Step 3: Run package test**

Run:

```sh
sh tests/herdr-agent.sh
```

Expected: `PASS: using-herdr-agents`.

---

### Task 4: Verify Entry Points and Drift

**Files:**
- Modify only if drift is found: `.agents/skills/using-herdr-agents/SKILL.md`, `README.md`

- [x] **Step 1: Run all shell syntax checks**

Run:

```sh
sh -n \
  .agents/skills/using-herdr-agents/scripts/herdr-agent \
  .agents/skills/using-herdr-agents/scripts/herdr-agent-session \
  .agents/skills/using-herdr-agents/scripts/install \
  .agents/skills/using-herdr-agents/tests/herdr-agent.sh \
  tests/herdr-agent.sh
```

Expected: exit 0 with no output.

- [x] **Step 2: Run package regression suite**

Run:

```sh
sh tests/herdr-agent.sh
```

Expected:

```text
PASS: using-herdr-agents
```

- [x] **Step 3: Verify direct package dry-run**

Run:

```sh
HERDR_AGENT_DRY_RUN=1 .agents/skills/using-herdr-agents/scripts/herdr-agent scout "find files"
```

Expected output includes:

```text
ROLE=scout
BACKEND=opencode
MODEL=opencode-go/deepseek-v4-flash
MODE=oneshot
PROMPT_DIR=/Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/prompts
OPENCODE_AGENT=scout_v2
```

- [x] **Step 4: Verify direct package session dry-run**

Run:

```sh
HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_REUSE=never .agents/skills/using-herdr-agents/scripts/herdr-agent-session scout "find files"
```

Expected output includes:

```text
ROLE=scout
BACKEND=opencode
MODEL=opencode-go/deepseek-v4-flash
RUNNER_MODE=interactive
RUNNER=/Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/scripts/herdr-agent
REUSE=never
```

- [x] **Step 5: Verify installed symlink entrypoints**

Run:

```sh
HERDR_AGENT_DRY_RUN=1 herdr-agent scout "find files"
HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_REUSE=never herdr-agent-session scout "find files"
```

Expected:
- first output includes `PROMPT_DIR=/Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/prompts`
- second output includes `RUNNER=/Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/scripts/herdr-agent`

- [x] **Step 6: Search for removed compatibility surfaces**

Run:

```sh
rg -n 'CLINE_BIN_PATH|mise which cline|HERDR_AGENT_SCOUT_OPENCODE_AGENT|HERDR_AGENT_SCOUT_CLINE_PROVIDER|HERDR_AGENT_SCOUT_CLINE_THINKING|\\.config/herdr/agents|\\.npm-global/bin/cline|\\.bun/bin/cline|/opt/homebrew/bin/cline|/usr/local/bin/cline' .agents/skills/using-herdr-agents/scripts/herdr-agent
```

Expected: exit 1 with no matches.

- [x] **Step 7: Check docs for drift**

Run:

```sh
rg -n 'CLINE_BIN_PATH|HERDR_AGENT_SCOUT_OPENCODE_AGENT|HERDR_AGENT_SCOUT_CLINE_PROVIDER|HERDR_AGENT_SCOUT_CLINE_THINKING|mise which cline' README.md .agents/skills/using-herdr-agents/SKILL.md docs/superpowers/specs/2026-07-02-herdr-agent-aggressive-slim-design.md
```

Expected: either no matches or only historical/design text in the spec explaining removal. If `README.md` or `SKILL.md` documents a removed override, update that file to remove the stale instruction and rerun this step.

- [x] **Step 8: Final status check**

Run:

```sh
git status --short
```

Expected: only intended Herdr package, docs, README, and existing unrelated dirty files are shown. Do not revert unrelated dirty files.
