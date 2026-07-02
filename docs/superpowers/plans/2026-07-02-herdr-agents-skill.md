# Herdr Agents Skill Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package the Herdr agent workflow as a reusable skill bundle that owns its guidance, scripts, prompts, install script, and tests together.

**Architecture:** `.agents/skills/using-herdr-agents/` becomes the canonical package root. Runtime entrypoints remain easy to call from any repository through optional symlinks created by the package-local `scripts/install`; the symlinks point back into the skill package, so the package remains the source of truth. The skill teaches context-lifecycle decisions: use one-shot by default, use persistent sessions when retained context is valuable, consider reuse when a matching idle session exists, and close sessions once their context is no longer useful.

**Tech Stack:** Markdown skill file, POSIX shell scripts, Herdr CLI, OpenCode, Agy, Codex CLI, Cline CLI, existing shell test style.

## Global Constraints

- Preserve existing user changes in `.codex/config.toml`, `.config/mise/config.toml`, `.config/opencode/opencode.json`, `.config/zed/settings.json`, `.agent/`, and `.codex/hooks.json`.
- Do not change the current role/model mapping unless validation proves it is necessary.
- Use `.agents/skills/using-herdr-agents/` as the canonical root for skill guidance, prompts, scripts, install script, and package-local tests.
- Keep `herdr-agent` for one-shot execution and `herdr-agent-session` for retained-context Herdr sessions.
- Do not make persistent sessions mandatory. Decide based on context lifecycle.
- Do not hard-code volatile model inventory or subscription quota estimates into the skill. Include current defaults and tell future agents to verify model availability when needed.
- `scripts/install` may create or update symlinks only. It must not copy files, edit shell startup files, or mutate unrelated config.
- Avoid unrelated cleanup or refactors while moving files.

---

## Critical Design Review

The strongest design is a self-contained skill package, not scattered files. The current split keeps prompts under `.config/herdr/agents`, scripts under `scripts/`, and process guidance in a future skill. That creates version drift: a future agent can read the skill but miss the exact scripts or prompts it describes. Moving prompts and scripts under the skill package makes the bundle portable and easier to reason about.

The package still needs stable entrypoints outside the repo. Requiring long paths such as `.agents/skills/using-herdr-agents/scripts/herdr-agent` is too awkward from arbitrary repositories. A package-local `scripts/install` solves this without making symlinks the source of truth.

The main risk is overfitting around persistent sessions. The skill must say that persistence is a context decision, not the default goal. Coder and Auditor especially should favor one-shot or fresh runs unless follow-up context clearly helps.

The second risk is moving too much at once. This plan deliberately keeps existing behavior while relocating the source files and updating discovery logic. It does not redesign role prompts or model choices.

## File Structure

- Create: `.agents/skills/using-herdr-agents/SKILL.md`
  - Responsibility: triggerable skill guidance for Herdr delegation and context lifecycle decisions.
- Create: `.agents/skills/using-herdr-agents/prompts/shared.md`
- Create: `.agents/skills/using-herdr-agents/prompts/scout.md`
- Create: `.agents/skills/using-herdr-agents/prompts/coder.md`
- Create: `.agents/skills/using-herdr-agents/prompts/auditor.md`
- Create: `.agents/skills/using-herdr-agents/prompts/advisor.md`
  - Responsibility: canonical Herdr worker role prompts.
- Move: `scripts/herdr-agent` -> `.agents/skills/using-herdr-agents/scripts/herdr-agent`
  - Responsibility: one-shot or interactive role runner.
- Move: `scripts/herdr-agent-session` -> `.agents/skills/using-herdr-agents/scripts/herdr-agent-session`
  - Responsibility: retained-context Herdr session launcher.
- Create: `.agents/skills/using-herdr-agents/scripts/install`
  - Responsibility: create symlinks for `~/.local/bin/herdr-agent`, `~/.local/bin/herdr-agent-session`, `~/.config/herdr/agents`, and `~/.agents/skills/using-herdr-agents`.
- Create: `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`
  - Responsibility: package-local regression tests for scripts, prompt discovery, install dry-run, and skill content.
- Modify: `tests/herdr-agent.sh`
  - Responsibility: thin repo-level wrapper that runs the package-local test.
- Modify: `README.md`
  - Responsibility: document the package root, install script, optional symlinks, and direct package paths.
- Modify: `docs/superpowers/plans/2026-07-01-herdr-multi-agent-system.md`
  - Responsibility: update historical notes to point at the skill package as canonical.

---

### Task 1: Add Package-Local Test Harness

**Files:**
- Create: `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`
- Modify: `tests/herdr-agent.sh`

**Interfaces:**
- Consumes: future package paths under `.agents/skills/using-herdr-agents`.
- Produces: test command `sh tests/herdr-agent.sh` that delegates to the package-local regression suite.

- [ ] **Step 1: Create the package test directory**

Run:

```sh
mkdir -p .agents/skills/using-herdr-agents/tests
```

Expected: command exits 0.

- [ ] **Step 2: Write the failing package-local test**

Create `.agents/skills/using-herdr-agents/tests/herdr-agent.sh` with exactly:

```sh
#!/bin/sh
set -eu

SKILL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
ROOT_DIR=$(CDPATH= cd -- "$SKILL_DIR/../../.." && pwd -P)
SCRIPT="$SKILL_DIR/scripts/herdr-agent"
SESSION_SCRIPT="$SKILL_DIR/scripts/herdr-agent-session"
INSTALL_SCRIPT="$SKILL_DIR/scripts/install"
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

for file in "$SKILL_FILE" "$SCRIPT" "$SESSION_SCRIPT" "$INSTALL_SCRIPT" \
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
assert_contains "$skill_text" "Close sessions"
assert_contains "$skill_text" "herdr agent list"
assert_contains "$skill_text" "herdr pane close"
assert_contains "$skill_text" "scripts/install"

scout_output=$(run_dry scout "find files")
assert_contains "$scout_output" "ROLE=scout"
assert_contains "$scout_output" "BACKEND=opencode"
assert_contains "$scout_output" "MODEL=opencode-go/deepseek-v4-flash"
assert_contains "$scout_output" "MODE=oneshot"
assert_contains "$scout_output" "OPENCODE_AGENT=scout_v2"
assert_contains "$scout_output" "PROMPT_DIR=$PROMPT_DIR"

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

session_output=$(
  HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_CONTEXT_KEY=test-context HERDR_AGENT_REUSE=never \
    "$SESSION_SCRIPT" scout "find files"
)
assert_contains "$session_output" "ROLE=scout"
assert_contains "$session_output" "BACKEND=opencode"
assert_contains "$session_output" "RUNNER_MODE=interactive"
assert_contains "$session_output" "REUSE=never"
assert_contains "$session_output" "RUNNER=$SCRIPT"

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

printf '%s\n' "PASS: using-herdr-agents"
```

- [ ] **Step 3: Replace the repo-level test with a wrapper**

Replace `tests/herdr-agent.sh` with exactly:

```sh
#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
exec "$ROOT_DIR/.agents/skills/using-herdr-agents/tests/herdr-agent.sh" "$@"
```

- [ ] **Step 4: Run the test to verify it fails for missing package files**

Run:

```sh
sh tests/herdr-agent.sh
```

Expected: fails with a line like:

```text
missing readable package file: /Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/SKILL.md
```

---

### Task 2: Move Prompts and Scripts into the Skill Package

**Files:**
- Move: `.config/herdr/agents/shared.md` -> `.agents/skills/using-herdr-agents/prompts/shared.md`
- Move: `.config/herdr/agents/scout.md` -> `.agents/skills/using-herdr-agents/prompts/scout.md`
- Move: `.config/herdr/agents/coder.md` -> `.agents/skills/using-herdr-agents/prompts/coder.md`
- Move: `.config/herdr/agents/auditor.md` -> `.agents/skills/using-herdr-agents/prompts/auditor.md`
- Move: `.config/herdr/agents/advisor.md` -> `.agents/skills/using-herdr-agents/prompts/advisor.md`
- Move: `scripts/herdr-agent` -> `.agents/skills/using-herdr-agents/scripts/herdr-agent`
- Move: `scripts/herdr-agent-session` -> `.agents/skills/using-herdr-agents/scripts/herdr-agent-session`

**Interfaces:**
- Consumes: current Herdr prompt and runner behavior.
- Produces: canonical package-local prompts and scripts.

- [ ] **Step 1: Create package directories**

Run:

```sh
mkdir -p .agents/skills/using-herdr-agents/prompts .agents/skills/using-herdr-agents/scripts
```

Expected: command exits 0.

- [ ] **Step 2: Move prompt files**

Run:

```sh
mv .config/herdr/agents/shared.md .agents/skills/using-herdr-agents/prompts/shared.md
mv .config/herdr/agents/scout.md .agents/skills/using-herdr-agents/prompts/scout.md
mv .config/herdr/agents/coder.md .agents/skills/using-herdr-agents/prompts/coder.md
mv .config/herdr/agents/auditor.md .agents/skills/using-herdr-agents/prompts/auditor.md
mv .config/herdr/agents/advisor.md .agents/skills/using-herdr-agents/prompts/advisor.md
```

Expected: each command exits 0.

- [ ] **Step 3: Move scripts**

Run:

```sh
mv scripts/herdr-agent .agents/skills/using-herdr-agents/scripts/herdr-agent
mv scripts/herdr-agent-session .agents/skills/using-herdr-agents/scripts/herdr-agent-session
```

Expected: each command exits 0.

- [ ] **Step 4: Update `herdr-agent` prompt fallback**

In `.agents/skills/using-herdr-agents/scripts/herdr-agent`, replace:

```sh
script_dir=$(physical_dirname "$0")
dotfiles_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)

prompt_dir="${HERDR_AGENT_PROMPT_DIR:-$HOME/.config/herdr/agents}"
if [ ! -d "$prompt_dir" ] && [ -d "$dotfiles_root/.config/herdr/agents" ]; then
  prompt_dir="$dotfiles_root/.config/herdr/agents"
fi
```

with:

```sh
script_dir=$(physical_dirname "$0")
skill_dir=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
dotfiles_root=$(CDPATH= cd -- "$skill_dir/../../.." && pwd -P)

prompt_dir="${HERDR_AGENT_PROMPT_DIR:-$skill_dir/prompts}"
if [ ! -d "$prompt_dir" ] && [ -d "$HOME/.config/herdr/agents" ]; then
  prompt_dir="$HOME/.config/herdr/agents"
fi
if [ ! -d "$prompt_dir" ] && [ -d "$dotfiles_root/.config/herdr/agents" ]; then
  prompt_dir="$dotfiles_root/.config/herdr/agents"
fi
```

- [ ] **Step 5: Update `herdr-agent-session` runner discovery**

In `.agents/skills/using-herdr-agents/scripts/herdr-agent-session`, replace:

```sh
if command -v herdr-agent >/dev/null 2>&1; then
  runner=$(command -v herdr-agent)
else
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
  runner="$script_dir/herdr-agent"
fi
```

with:

```sh
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
runner="$script_dir/herdr-agent"
if [ ! -x "$runner" ] && command -v herdr-agent >/dev/null 2>&1; then
  runner=$(command -v herdr-agent)
fi
```

- [ ] **Step 6: Verify moved script syntax**

Run:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent-session
```

Expected: no output and exit 0.

---

### Task 3: Create the Skill Guidance and Install Script

**Files:**
- Create: `.agents/skills/using-herdr-agents/SKILL.md`
- Create: `.agents/skills/using-herdr-agents/scripts/install`

**Interfaces:**
- Consumes: package-local scripts and prompts from Task 2.
- Produces: discoverable skill guidance and a repeatable symlink installer.

- [ ] **Step 1: Create `SKILL.md`**

Create `.agents/skills/using-herdr-agents/SKILL.md` with exactly:

```md
---
name: using-herdr-agents
description: Use when Codex is delegating repository exploration, implementation, review, or advisor work through Herdr-managed external agents
---

# Using Herdr Agents

## Overview

Codex stays Planner/Judge. Herdr agents are specialist workers used only when delegation beats doing the work inline.

Core rule: Default to one-shot execution. Use a persistent session only when future context is likely valuable.

This skill package is the source of truth for its scripts and prompts:
- `scripts/herdr-agent`
- `scripts/herdr-agent-session`
- `prompts/*.md`
- `scripts/install`

If `herdr-agent` or `herdr-agent-session` is not on `PATH`, run:

```sh
~/.agents/skills/using-herdr-agents/scripts/install
```

The install script only creates or updates symlinks. It does not copy files or edit shell startup files.

## Command Boundary

| Need | Command | Lifecycle |
| --- | --- | --- |
| single task, fresh context, routing check | `herdr-agent <role> "<brief>"` | one-shot |
| follow-up likely, context map useful, startup overhead matters | `herdr-agent-session <role> "<brief>"` | persistent |
| explicit non-persistent pane run | `HERDR_AGENT_SESSION_MODE=oneshot herdr-agent-session <role> "<brief>"` | one-shot in Herdr |

## Role Selection

| Need | Role | Default |
| --- | --- | --- |
| missing repo context | `scout` | cheap read-only exploration |
| scoped implementation | `coder` | one-shot unless follow-up context clearly helps |
| diff or artifact review | `auditor` | fresh one-shot preferred |
| repeated failure or hard judgment | `advisor` | escalation-only, high or xhigh reasoning |

## Session Lifecycle

Before choosing a command, decide whether retained context is useful.

Default to one-shot when:
- the task is small or self-contained
- freshness matters more than startup overhead
- reviewing Coder output
- the existing session may contain stale or unrelated context

Use a persistent session when:
- follow-up questions are likely
- Scout is building a repo or feature context map
- the same investigation will continue across multiple prompts
- startup overhead is larger than context contamination risk

Reuse only when role, repository/worktree, backend/model class, and `HERDR_AGENT_CONTEXT_KEY` all still match. Otherwise start fresh with `HERDR_AGENT_REUSE=never`.

Close sessions when the context is no longer useful:

```sh
herdr agent list
herdr pane close <pane_id>
```

## Recipes

One-shot Scout:

```sh
herdr-agent scout "Find the relevant files for ..."
```

Persistent Scout:

```sh
HERDR_AGENT_CONTEXT_KEY=feature-auth herdr-agent-session scout "Map the auth-related files. Do not edit."
```

Fresh Auditor:

```sh
HERDR_AGENT_REUSE=never herdr-agent auditor "Review the current git diff against ..."
```

Advisor escalation:

```sh
HERDR_AGENT_ADVISOR_THINKING=xhigh herdr-agent advisor "Judge these conflicting reports and choose the next narrow action ..."
```

## Reading and Reusing Sessions

Inspect sessions before reuse:

```sh
herdr agent list
herdr agent read <agent-name-or-pane-id> --source recent-unwrapped --lines 160 --format text
```

If Herdr reports `working` but the pane appears complete, read the pane before assuming the task is still active.

## Common Mistakes

- Using `herdr-agent-session` just because it exists. Persistence is a context decision, not the default goal.
- Reusing Coder or Auditor sessions across unrelated tasks.
- Letting Scout plan, Coder broaden scope, or Auditor decide final action.
- Escalating to Advisor before cheaper Scout/Coder/Auditor evidence exists.
- Leaving task-specific sessions open after their context is no longer useful.
```

- [ ] **Step 2: Create `scripts/install`**

Create `.agents/skills/using-herdr-agents/scripts/install` with exactly:

```sh
#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
skill_dir=$(CDPATH= cd -- "$script_dir/.." && pwd -P)

bin_dir="${HERDR_AGENT_INSTALL_PREFIX:-$HOME/.local/bin}"
config_dir="${HERDR_AGENT_INSTALL_CONFIG_DIR:-$HOME/.config/herdr}"
skills_dir="${HERDR_AGENT_INSTALL_SKILLS_DIR:-$HOME/.agents/skills}"
dry_run="${HERDR_AGENT_INSTALL_DRY_RUN:-0}"

link_pair() {
  source_path="$1"
  target_path="$2"
  if [ "$dry_run" = "1" ]; then
    printf '%s -> %s\n' "$target_path" "$source_path"
    return 0
  fi
  mkdir -p "$(dirname -- "$target_path")"
  ln -sfn "$source_path" "$target_path"
}

if [ "$dry_run" != "1" ]; then
  mkdir -p "$bin_dir" "$config_dir" "$skills_dir"
fi

link_pair "$skill_dir/scripts/herdr-agent" "$bin_dir/herdr-agent"
link_pair "$skill_dir/scripts/herdr-agent-session" "$bin_dir/herdr-agent-session"
link_pair "$skill_dir/prompts" "$config_dir/agents"
link_pair "$skill_dir" "$skills_dir/using-herdr-agents"

if [ "$dry_run" != "1" ]; then
  printf '%s\n' "Installed using-herdr-agents symlinks."
fi
```

- [ ] **Step 3: Make package scripts executable**

Run:

```sh
chmod +x .agents/skills/using-herdr-agents/scripts/herdr-agent
chmod +x .agents/skills/using-herdr-agents/scripts/herdr-agent-session
chmod +x .agents/skills/using-herdr-agents/scripts/install
chmod +x .agents/skills/using-herdr-agents/tests/herdr-agent.sh
```

Expected: each command exits 0.

- [ ] **Step 4: Verify package test passes**

Run:

```sh
sh tests/herdr-agent.sh
```

Expected:

```text
PASS: using-herdr-agents
```

---

### Task 4: Install Symlinks and Remove Old Runtime Paths

**Files:**
- Modify home symlinks:
  - `~/.local/bin/herdr-agent`
  - `~/.local/bin/herdr-agent-session`
  - `~/.config/herdr/agents`
  - `~/.agents/skills/using-herdr-agents`
- Delete or leave empty after move:
  - `scripts/herdr-agent`
  - `scripts/herdr-agent-session`
  - `.config/herdr/agents/*`

**Interfaces:**
- Consumes: package-local `scripts/install`.
- Produces: stable PATH entrypoints pointing into the skill package.

- [ ] **Step 1: Preview install symlinks**

Run:

```sh
HERDR_AGENT_INSTALL_DRY_RUN=1 .agents/skills/using-herdr-agents/scripts/install
```

Expected output contains:

```text
/Users/haru256/.local/bin/herdr-agent -> /Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/scripts/herdr-agent
/Users/haru256/.local/bin/herdr-agent-session -> /Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/scripts/herdr-agent-session
/Users/haru256/.config/herdr/agents -> /Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/prompts
/Users/haru256/.agents/skills/using-herdr-agents -> /Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents
```

- [ ] **Step 2: Run install**

Run:

```sh
.agents/skills/using-herdr-agents/scripts/install
```

Expected:

```text
Installed using-herdr-agents symlinks.
```

- [ ] **Step 3: Verify symlinks**

Run:

```sh
ls -l "$HOME/.local/bin/herdr-agent"
ls -l "$HOME/.local/bin/herdr-agent-session"
ls -l "$HOME/.config/herdr/agents"
ls -l "$HOME/.agents/skills/using-herdr-agents"
```

Expected: all four paths point into `/Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents`.

- [ ] **Step 4: Remove empty legacy directories only if safe**

Run:

```sh
find scripts -maxdepth 1 -type f \( -name 'herdr-agent' -o -name 'herdr-agent-session' \) -print
find .config/herdr/agents -maxdepth 1 -type f -print 2>/dev/null || true
```

Expected: no files are printed. If `.config/herdr/agents` is empty, remove it with:

```sh
rmdir .config/herdr/agents
```

If the directory is not empty, stop and inspect rather than deleting.

---

### Task 5: Update Documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-07-01-herdr-multi-agent-system.md`

**Interfaces:**
- Consumes: final package paths and install script from Tasks 2-4.
- Produces: documentation that points users and future agents at the package root.

- [ ] **Step 1: Update README symlink instructions**

In `README.md`, replace the Herdr symlink lines:

```sh
mkdir -p ~/.config/herdr ~/.local/bin
ln -s ~/dotfiles/.config/herdr/config.toml ~/.config/herdr/config.toml
ln -s ~/dotfiles/.config/herdr/agents ~/.config/herdr/agents
ln -s ~/dotfiles/scripts/herdr-agent ~/.local/bin/herdr-agent
ln -s ~/dotfiles/scripts/herdr-agent-session ~/.local/bin/herdr-agent-session
```

with:

```sh
mkdir -p ~/.config/herdr
ln -s ~/dotfiles/.config/herdr/config.toml ~/.config/herdr/config.toml
~/dotfiles/.agents/skills/using-herdr-agents/scripts/install
```

- [ ] **Step 2: Update README package description**

In the “Herdr Multi-Agent System” section, replace the command-boundary paragraphs with:

```md
The Herdr agent package lives at `.agents/skills/using-herdr-agents`.
It owns the skill guidance, prompts, scripts, install script, and package-local tests.

`herdr-agent` is the one-shot runner used for direct execution and routing checks.
`herdr-agent-session` is the Herdr launcher for retained context. Use it only when follow-up or startup-overhead savings are worth the context-contamination risk.
```

- [ ] **Step 3: Update README examples**

Keep the existing examples but add this direct-path example before the dry-run examples:

```sh
.agents/skills/using-herdr-agents/scripts/herdr-agent scout "find the relevant files for ..."
```

- [ ] **Step 4: Update historical plan file structure**

In `docs/superpowers/plans/2026-07-01-herdr-multi-agent-system.md`, add a note near the file structure section:

```md
Superseded packaging note: the Herdr prompts and runner scripts now live under `.agents/skills/using-herdr-agents/` so the skill, prompts, scripts, installer, and tests move together. `~/.local/bin` and `~/.config/herdr/agents` are symlink entrypoints created by the package installer.
```

- [ ] **Step 5: Update validation commands in historical plan**

Replace references to:

```sh
sh -n scripts/herdr-agent
sh -n scripts/herdr-agent-session
```

with:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent-session
```

- [ ] **Step 6: Verify no stale canonical paths remain**

Run:

```sh
rg -n "scripts/herdr-agent|scripts/herdr-agent-session|\\.config/herdr/agents/(shared|scout|coder|auditor|advisor)\\.md" README.md docs/superpowers/plans/2026-07-01-herdr-multi-agent-system.md
```

Expected: no output for canonical file ownership. References to `~/.config/herdr/agents` as a symlink entrypoint are allowed.

---

### Task 6: Pressure-Test the Skill Package

**Files:**
- Possible modify: `.agents/skills/using-herdr-agents/SKILL.md`
- Possible modify: `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`

**Interfaces:**
- Consumes: installed package and symlinks.
- Produces: evidence that the skill drives correct one-shot/session/reuse/cleanup decisions.

- [ ] **Step 1: Run structural validation**

Run:

```sh
sh tests/herdr-agent.sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent-session
sh -n .agents/skills/using-herdr-agents/scripts/install
sh -n .agents/skills/using-herdr-agents/tests/herdr-agent.sh
```

Expected: `PASS: using-herdr-agents`; syntax checks produce no output.

- [ ] **Step 2: Verify PATH entrypoints route to package scripts**

Run:

```sh
HERDR_AGENT_DRY_RUN=1 herdr-agent scout "find files"
HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_REUSE=never herdr-agent-session scout "find files"
```

Expected: first output includes `PROMPT_DIR=/Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/prompts`; second output includes `RUNNER=/Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/scripts/herdr-agent`.

- [ ] **Step 3: Pressure scenario A: simple one-shot Scout**

Ask a fresh evaluator to read `.agents/skills/using-herdr-agents/SKILL.md` and answer which command it would run for:

```text
User asks: "関連ファイルだけ軽く見て。follow-up はなさそう。"
```

Expected answer:

```sh
herdr-agent scout "..."
```

It should not choose `herdr-agent-session`.

- [ ] **Step 4: Pressure scenario B: retained-context Scout**

Ask a fresh evaluator:

```text
User asks: "この repository の auth 周りを調べて。あとで follow-up するので session は残して。"
```

Expected answer:

```sh
HERDR_AGENT_CONTEXT_KEY=auth-investigation herdr-agent-session scout "..."
```

It should mention checking or reusing a matching idle session if one exists.

- [ ] **Step 5: Pressure scenario C: fresh Auditor**

Ask a fresh evaluator:

```text
User asks: "この diff を fresh context で review して。"
```

Expected answer:

```sh
HERDR_AGENT_REUSE=never herdr-agent auditor "..."
```

Acceptable alternate:

```sh
HERDR_AGENT_REUSE=never HERDR_AGENT_SESSION_MODE=oneshot herdr-agent-session auditor "..."
```

It should not reuse an existing Coder or Scout session.

- [ ] **Step 6: Pressure scenario D: cleanup**

Ask a fresh evaluator:

```text
User asks: "もうこの Scout session は不要なので閉じて。"
```

Expected actions:

```sh
herdr agent list
herdr pane close <pane_id>
```

It should not leave the session open.

- [ ] **Step 7: Patch wording if any pressure scenario fails**

If a fresh evaluator chooses the wrong lifecycle, update only the smallest ambiguous section in `.agents/skills/using-herdr-agents/SKILL.md`, then rerun the failing pressure scenario.

---

## Self-Review

**Spec coverage:** The plan covers skill package root, bundled prompts, bundled scripts, package-local install script, optional symlink entrypoints, one-shot/session/reuse/cleanup policy, README updates, historical plan updates, and pressure scenarios.

**Placeholder scan:** No placeholder red flags are present. The word “Expected” is used only for concrete command outcomes.

**Type/name consistency:** The package name is `using-herdr-agents`; the canonical root is `.agents/skills/using-herdr-agents`; commands are `herdr-agent` and `herdr-agent-session`; env vars are `HERDR_AGENT_SESSION_MODE`, `HERDR_AGENT_SESSION_DRY_RUN`, `HERDR_AGENT_INSTALL_DRY_RUN`, `HERDR_AGENT_INSTALL_PREFIX`, `HERDR_AGENT_INSTALL_CONFIG_DIR`, and `HERDR_AGENT_INSTALL_SKILLS_DIR`.
