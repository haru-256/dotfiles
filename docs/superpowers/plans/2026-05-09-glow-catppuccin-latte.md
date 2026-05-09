# Glow Catppuccin Latte Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Manage Glow configuration in this dotfiles repository and configure Glow markdown syntax highlighting with Catppuccin Latte.

**Architecture:** Use Glow's standard `glow.yml` config path and point its `style` setting at a repository-managed Glamour JSON theme. Install `~/.config/glow/glow.yml` as a symlink to the repository file so Glow reads the managed config directly.

**Tech Stack:** Glow, Glamour JSON style files, YAML, POSIX shell, dotfiles symlinks.

---

## File Structure

- Create: `.config/glow/glow.yml` — Glow user configuration; sets the custom style file path.
- Create: `.config/glow/styles/catppuccin-latte.json` — Catppuccin Latte Glamour style copied from the official `catppuccin/glamour` theme.
- Modify: `README.md` — list the Glow config and add the symlink command to the usage instructions.
- External symlink: `~/.config/glow/glow.yml` — symlink to `/Users/haru256/Documents/projects/dotfiles/.config/glow/glow.yml`.

## References

- Glow config accepts `style: "~/.config/glow/styles/custom.json"` in `glow.yml`.
- Official Catppuccin Glamour Latte theme URL: `https://raw.githubusercontent.com/catppuccin/glamour/main/themes/catppuccin-latte.json`.

## Task 1: Add repository-managed Glow config and theme

**Files:**
- Create: `.config/glow/glow.yml`
- Create: `.config/glow/styles/catppuccin-latte.json`

- [ ] **Step 1: Create Glow directories**

Run:

```bash
mkdir -p .config/glow/styles
```

Expected: command succeeds with no output.

- [ ] **Step 2: Fetch the official Catppuccin Latte Glamour style**

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/catppuccin/glamour/main/themes/catppuccin-latte.json -o .config/glow/styles/catppuccin-latte.json
```

Expected: command succeeds and creates `.config/glow/styles/catppuccin-latte.json`.

- [ ] **Step 3: Validate the downloaded JSON**

Run:

```bash
python -m json.tool .config/glow/styles/catppuccin-latte.json >/dev/null
```

Expected: command succeeds with no output.

- [ ] **Step 4: Create Glow config**

Write `.config/glow/glow.yml` exactly as:

```yaml
# style name or JSON path (default "auto")
style: "~/.config/glow/styles/catppuccin-latte.json"
```

- [ ] **Step 5: Validate YAML shape by reading it**

Run:

```bash
python - <<'PY'
from pathlib import Path
p = Path('.config/glow/glow.yml')
text = p.read_text()
assert 'style: "~/.config/glow/styles/catppuccin-latte.json"' in text
PY
```

Expected: command succeeds with no output.

## Task 2: Install home symlinks for Glow

**Files:**
- External create/replace: `~/.config/glow/glow.yml`
- External create/replace: `~/.config/glow/styles/catppuccin-latte.json`

- [ ] **Step 1: Ensure the home Glow directories exist**

Run:

```bash
mkdir -p "$HOME/.config/glow/styles"
```

Expected: command succeeds with no output.

- [ ] **Step 2: Replace existing home Glow config with a symlink**

Run:

```bash
rm -f "$HOME/.config/glow/glow.yml" && ln -s "/Users/haru256/Documents/projects/dotfiles/.config/glow/glow.yml" "$HOME/.config/glow/glow.yml"
```

Expected: command succeeds. Existing real file may be discarded per user instruction.

- [ ] **Step 3: Replace existing home Catppuccin Latte style with a symlink**

Run:

```bash
rm -f "$HOME/.config/glow/styles/catppuccin-latte.json" && ln -s "/Users/haru256/Documents/projects/dotfiles/.config/glow/styles/catppuccin-latte.json" "$HOME/.config/glow/styles/catppuccin-latte.json"
```

Expected: command succeeds. Existing real file may be discarded per user instruction.

- [ ] **Step 4: Verify symlink targets**

Run:

```bash
test "$(readlink "$HOME/.config/glow/glow.yml")" = "/Users/haru256/Documents/projects/dotfiles/.config/glow/glow.yml" && test "$(readlink "$HOME/.config/glow/styles/catppuccin-latte.json")" = "/Users/haru256/Documents/projects/dotfiles/.config/glow/styles/catppuccin-latte.json"
```

Expected: command succeeds with no output.

## Task 3: Update README usage notes

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add Glow to the configuration list**

In `README.md`, add a Glow section near the other terminal tools:

```md
### Glow

- **Glow Configuration**: [`.config/glow/glow.yml`](.config/glow/glow.yml)
- **Glow Catppuccin Latte Style**: [`.config/glow/styles/catppuccin-latte.json`](.config/glow/styles/catppuccin-latte.json)
```

- [ ] **Step 2: Add Glow symlink commands to Usage**

In the usage shell block, add:

```sh
mkdir -p ~/.config/glow/styles
ln -s ~/dotfiles/.config/glow/glow.yml ~/.config/glow/glow.yml
ln -s ~/dotfiles/.config/glow/styles/catppuccin-latte.json ~/.config/glow/styles/catppuccin-latte.json
```

## Task 4: Verify Glow configuration

**Files:**
- Read: `.config/glow/glow.yml`
- Read: `.config/glow/styles/catppuccin-latte.json`
- Read: `~/.config/glow/glow.yml`

- [ ] **Step 1: Validate repository files**

Run:

```bash
test -f .config/glow/glow.yml && python -m json.tool .config/glow/styles/catppuccin-latte.json >/dev/null
```

Expected: command succeeds with no output.

- [ ] **Step 2: Validate home symlink**

Run:

```bash
test -L "$HOME/.config/glow/glow.yml" && test -L "$HOME/.config/glow/styles/catppuccin-latte.json"
```

Expected: command succeeds with no output.

- [ ] **Step 3: If Glow is installed, smoke test rendering**

Run:

```bash
if command -v glow >/dev/null 2>&1; then glow --style "$HOME/.config/glow/styles/catppuccin-latte.json" README.md >/dev/null; else printf 'glow not installed; skipped smoke test\n'; fi
```

Expected: either Glow renders successfully with no output, or the command prints `glow not installed; skipped smoke test`.

- [ ] **Step 4: Confirm unrelated working tree changes are untouched**

Run:

```bash
git status --short
```

Expected: Glow files and README are changed/added. Pre-existing unrelated changes such as `.codex/config.toml` and `.config/zed/prompts/prompts-library-db.0.mdb/lock.mdb` may still appear and must not be modified by this work.

## Implementation Log
<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N → STATUS | commit-or-failure-signature -->

- [2026-05-09] attempt #1 → SUCCESS | created Glow config/theme, installed symlinks, verification passed

## Review Findings
<!-- This template is also defined in commands/plan.md. Keep them in sync on every edit. -->

### Reviewer Raw Findings
<!-- Orchestrator copies @reviewer's structured findings verbatim here when invoking @reviewer
     during a workflow. Direct /review-* calls do not write here.
     Raw findings are review input (audit history), not implementation instructions. -->

### Orchestrator Adjudication
<!-- Orchestrator appends adjudication tables for orchestrated workflow reviews.
     Only ACCEPT rows are implementation instructions:
     | ID | Severity | Decision | Reason | Action | -->

## Deviations from Plan
<!-- Implementer documents intentional deviations and reasons -->

- Task 3 README update was completed by the orchestrator before implementation delegation, so the implementer skipped README edits.

## Open Questions
<!-- Any agent adds questions for orchestrator or arbiter -->

- None.
