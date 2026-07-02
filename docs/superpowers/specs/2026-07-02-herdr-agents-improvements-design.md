# Design Spec: `using-herdr-agents` Improvements

**Date:** 2026-07-02  
**Status:** Approved  
**Topic:** Resolving library variable scoping issues, automating syntax verification, and clarifying skill documentation paths.

---

## 1. Goal & Context

The `using-herdr-agents` skill package contains specialist wrappers, prompts, and installers for Herdr task delegation. The goals of this update are:
1. **Resolve global variable pollution** in the shell helper library to guarantee POSIX `sh` safety under all calling environments.
2. **Automate shell syntax verification** (`sh -n`) in the regression test suite.
3. **Clarify directory installation paths** in the skill instruction file (`SKILL.md`).

---

## 2. File Changes

- **Modify:** [herdr-agent-lib](file:///Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/scripts/herdr-agent-lib)
  - Scope helper variable `value` to a unique temporary prefix `_ha_val` and `unset` it at function termination.
- **Modify:** [tests/herdr-agent.sh](file:///Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/tests/herdr-agent.sh)
  - Add an automated loop running `sh -n` for all package scripts.
- **Modify:** [SKILL.md](file:///Users/haru256/Documents/projects/dotfiles/.agents/skills/using-herdr-agents/SKILL.md)
  - Revise the prerequisite run path to clearly distinguish between running from the workspace and running from a globally installed location.

---

## 3. Design Details

### 3.1. POSIX Scope Protection in `herdr-agent-lib`

The variable `value` in `herdr_agent_sanitize_part()` is globally visible. To prevent global scope corruption without using the non-standard `local` keyword:
1. Rename the variable to `_ha_val` (unique prefix).
2. Explicitly calling `unset _ha_val` at the end of the function.

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

### 3.2. Automated Syntax Verification in `tests/herdr-agent.sh`

Add a test step validating POSIX syntax compliance before running regression tests.

```sh
for sh_file in "$SCRIPT" "$SESSION_SCRIPT" "$INSTALL_SCRIPT" "$LIB_SCRIPT" "$0"; do
  if ! sh -n "$sh_file"; then
    printf 'Syntax validation failed for: %s\n' "$sh_file" >&2
    exit 1
  fi
done
```

### 3.3. Installer Path Documentation in `SKILL.md`

Clarify the two distinct run modes for the installer:

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

---

## 4. Verification Plan

1. **Syntax Checks:** Run `sh -n` manually on all modified scripts.
2. **Regression Test:** Execute `sh tests/herdr-agent.sh` and verify it exits 0 with `PASS: using-herdr-agents`.
3. **Scope verification:** Ensure calling `herdr_agent_sanitize_part` does not leave any active global variables in the shell environment.
