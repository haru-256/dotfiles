# Herdr Agents Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve variable scope pollution in `herdr-agent-lib`, automate syntax validation (`sh -n`) in regression tests, and clarify run paths in `SKILL.md`.

**Architecture:** Use a unique prefix `_ha_val` and call `unset` for shell helpers to keep scope clean in POSIX `sh`. Add an automated `sh -n` loop to `tests/herdr-agent.sh`. Adjust path notes in `SKILL.md`.

**Tech Stack:** POSIX Shell, markdown.

---

### Task 1: Automate Syntax Validation in Tests

**Files:**
- Modify: `.agents/skills/using-herdr-agents/tests/herdr-agent.sh:56-65`

- [ ] **Step 1: Add syntax validation check to test script**

Modify [tests/herdr-agent.sh](file:///Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/tests/herdr-agent.sh#L56-L65) to include the `sh -n` loop right before checking file readability.

Target replacement:
```sh
for file in "$SKILL_FILE" "$SCRIPT" "$SESSION_SCRIPT" "$INSTALL_SCRIPT" "$LIB_SCRIPT" \
  "$PROMPT_DIR/shared.md" "$PROMPT_DIR/scout.md" "$PROMPT_DIR/coder.md" \
  "$PROMPT_DIR/auditor.md" "$PROMPT_DIR/advisor.md"
do
  if [ ! -r "$file" ]; then
    printf '%s\n' "missing readable package file: $file" >&2
    exit 1
  fi
done
```

Replacement content:
```sh
# Syntax validation check for all package shell scripts
for sh_file in "$SCRIPT" "$SESSION_SCRIPT" "$INSTALL_SCRIPT" "$LIB_SCRIPT" "$0"; do
  if ! sh -n "$sh_file"; then
    printf 'Syntax validation failed for: %s\n' "$sh_file" >&2
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
```

- [ ] **Step 2: Run test suite to verify syntax check passes**

Run:
```sh
sh tests/herdr-agent.sh
```
Expected: `PASS: using-herdr-agents` (exits 0, as scripts currently have valid syntax).

- [ ] **Step 3: Stage changes**

Note: Commits are skipped as per repository guidelines `AGENTS.md` unless explicitly requested. Stage changes to verify status.
Run:
```sh
git add .agents/skills/using-herdr-agents/tests/herdr-agent.sh
```

---

### Task 2: Scope Variables in `herdr-agent-lib`

**Files:**
- Modify: `.agents/skills/using-herdr-agents/scripts/herdr-agent-lib:25-32`

- [ ] **Step 1: Modify variable names and add unset in `herdr-agent-lib`**

In [.agents/skills/using-herdr-agents/scripts/herdr-agent-lib](file:///Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/scripts/herdr-agent-lib#L25-L32), replace `value` with `_ha_val` and add `unset _ha_val`.

Target content:
```sh
herdr_agent_sanitize_part() {
  value=$(printf '%s' "$1" | tr -c '[:alnum:]_.-' '-')
  value=$(printf '%s' "$value" | sed 's/--*/-/g; s/^-//; s/-$//')
  if [ -z "$value" ]; then
    value="default"
  fi
  printf '%s\n' "$value"
}
```

Replacement content:
```sh
herdr_agent_sanitize_part() {
  _ha_val=$(printf '%s' "$1" | tr -c '[:alnum:]_.-' '-')
  _ha_val=$(printf '%s' "$_ha_val" | sed 's/--*/-/g; s/^-//; s/-$//')
  if [ -z "$_ha_val" ]; then
    _ha_val="default"
  fi
  printf '%s\n' "$_ha_val"
  unset _ha_val
}
```

- [ ] **Step 2: Run tests to ensure syntax and regression tests pass**

Run:
```sh
sh tests/herdr-agent.sh
```
Expected: `PASS: using-herdr-agents` (exits 0).

- [ ] **Step 3: Stage changes**

Run:
```sh
git add .agents/skills/using-herdr-agents/scripts/herdr-agent-lib
```

---

### Task 3: Update `SKILL.md` Path Descriptions

**Files:**
- Modify: `.agents/skills/using-herdr-agents/SKILL.md:16-22`

- [ ] **Step 1: Clarify installation paths in `SKILL.md`**

In [.agents/skills/using-herdr-agents/SKILL.md](file:///Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/SKILL.md#L16-L22), replace path description block.

Target content:
```markdown
If `herdr-agent` or `herdr-agent-session` is not on `PATH`, run:

```sh
./.agents/skills/using-herdr-agents/scripts/install
# or, after the skill symlink exists:
~/.agents/skills/using-herdr-agents/scripts/install
```
```

Replacement content:
```markdown
If `herdr-agent` or `herdr-agent-session` is not on `PATH`, run from the repository root:

```sh
./.agents/skills/using-herdr-agents/scripts/install
```

Or, if the global/home skill symlink already exists, you can run it from anywhere:

```sh
~/.agents/skills/using-herdr-agents/scripts/install
```
```

- [ ] **Step 2: Run tests to verify skill text assertions pass**

Run:
```sh
sh tests/herdr-agent.sh
```
Expected: `PASS: using-herdr-agents` (assert_contains checks for `scripts/install` should pass).

- [ ] **Step 3: Stage changes**

Run:
```sh
git add .agents/skills/using-herdr-agents/SKILL.md
```
