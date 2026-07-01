# Cline Adaptive Coding Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Cline CLI workflow that saves tokens while improving coding performance by using cheap single-session work by default and escalating to Agent Teams, reviewer, or oracle only when useful.

**Architecture:** Keep the always-on context small with one project rule file. Store longer role prompts under `.config/cline/prompts/` and load them only during escalation workflows. Add `scripts/cline-team` as the explicit Agent Teams escalation entrypoint while leaving normal `cline` resolution to the installed Cline executable.

**Tech Stack:** POSIX `sh`, Cline CLI, Markdown prompts/rules/docs, existing dotfiles symlink workflow.

## Global Constraints

- Do not replace or modify the existing OpenCode setup.
- Do not add or keep a `scripts/cline` palette wrapper.
- Do not introduce unverified `.cline/agents.yaml` schema usage.
- Do not create role-specific config directories such as `~/.cline-reviewer` in this initial implementation.
- Do not commit changes automatically; the repository `AGENTS.md` forbids commits unless explicitly requested.
- Keep `.cline/rules/adaptive-coding.md` short because it is always-on context.
- Role prompts are escalation prompts and should not be loaded by default.
- Use `orchestrator` and `explorer` spellings, not `orchestorator` or `exploter`.

---

## File structure

- Create `.cline/rules/adaptive-coding.md`: compact always-on routing policy for normal Cline sessions.
- Create `.config/cline/prompts/orchestrator.md`: escalation coordinator prompt loaded by `scripts/cline-team`.
- Create `.config/cline/prompts/explorer.md`: read-only research prompt used by the orchestrator when broad context is needed.
- Create `.config/cline/prompts/implementer.md`: scoped implementation prompt with ambiguity gate and compact report format.
- Create `.config/cline/prompts/reviewer.md`: read-only evidence-backed review prompt.
- Create `.config/cline/prompts/oracle.md`: rare high-context decision prompt.
- Create `scripts/cline-team`: POSIX wrapper that resolves the real Cline executable and starts Agent Teams with the orchestrator system prompt.
- Modify `README.md`: document the default cheap path, escalation path, symlinks, and validation/override examples.
- Do not manage normal `cline`; use the installed Cline executable directly.

---

### Task 1: Add compact adaptive project rule

**Files:**
- Create: `/Users/haru256/Documents/projects/dotfiles/.cline/rules/adaptive-coding.md`

**Interfaces:**
- Consumes: Cline project rules mechanism reads `.cline/rules/*.md`.
- Produces: Always-on concise routing policy for normal `cline` sessions.

- [x] **Step 1: Create the rule directory**

Run:

```sh
mkdir -p /Users/haru256/Documents/projects/dotfiles/.cline/rules
```

Expected: command exits 0.

- [x] **Step 2: Write the adaptive coding rule**

Create `/Users/haru256/Documents/projects/dotfiles/.cline/rules/adaptive-coding.md` with exactly:

```md
# Adaptive coding workflow

Optimize for correct useful code per token.

## Default path

- Use the current Cline session for small, local, low-risk tasks.
- Do not load broad repository context unless it is needed for correctness.
- Prefer targeted reads/searches and user-provided paths.
- Keep summaries and handoffs compact.

## Escalate to Agent Teams when

- the task needs broad exploration before implementation;
- the change spans multiple files or subsystems;
- implementation and review should be independent;
- the task may span multiple turns or sessions;
- the same failure pattern repeats.

## Use reviewer when

- a meaningful implementation diff exists;
- behavior, tests, scripts, config loading, security, or public UX changed;
- implementation deviates from the plan;
- the user explicitly asks for review.

## Use oracle only when

- reviewer escalates a strategic issue;
- the same failure signature repeats;
- API, schema, state, IAM, security, data model, or long-lived architecture decisions are involved;
- two plausible approaches have unclear trade-offs.

Do not use oracle for routine implementation judgment.

## Handoff format

When delegating, include only:

1. goal;
2. acceptance criteria;
3. relevant paths;
4. constraints;
5. commands to run;
6. expected report format.
```

Expected: file exists and is intentionally short.

- [x] **Step 3: Verify the rule file content**

Run:

```sh
sed -n '1,120p' /Users/haru256/Documents/projects/dotfiles/.cline/rules/adaptive-coding.md
```

Expected: output matches Step 2 content.

---

### Task 2: Add Cline escalation role prompts

**Files:**
- Create: `/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/orchestrator.md`
- Create: `/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/explorer.md`
- Create: `/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/implementer.md`
- Create: `/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/reviewer.md`
- Create: `/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/oracle.md`

**Interfaces:**
- Consumes: `scripts/cline-team` reads `~/.config/cline/prompts/orchestrator.md` as the system prompt.
- Produces: Prompt files that can be symlinked to `~/.config/cline/prompts/` and used manually for headless review/oracle workflows.

- [x] **Step 1: Create the prompt directory**

Run:

```sh
mkdir -p /Users/haru256/Documents/projects/dotfiles/.config/cline/prompts
```

Expected: command exits 0.

- [x] **Step 2: Write orchestrator prompt**

Create `/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/orchestrator.md` with exactly:

```md
# Role

You are `orchestrator`, the coordinator for the Cline adaptive coding workflow.

Your goal is correct useful code per token. Do not maximize delegation. Start with the cheapest adequate workflow and escalate only when the task needs context isolation, independent review, multi-step coordination, or architectural judgment.

## Default policy

- Keep user-facing responses compact.
- Clarify scope when the request lacks target behavior, relevant paths, or acceptance criteria.
- Avoid broad repository exploration in your own context unless the task is small and focused.
- Do not invoke `oracle` for routine implementation judgment.

## Escalation policy

Use Agent Teams teammates when the task needs them:

- `explorer`: broad read-only repository or external research.
- `implementer`: scoped implementation and checks.
- `reviewer`: independent read-only review of meaningful diffs, plans, docs, or scripts.
- `oracle`: rare high-context decision support for blocked loops or architecture/security/schema/API decisions.

Escalate to Agent Teams when:

- the task needs broad exploration before implementation;
- the change spans multiple files or subsystems;
- implementation and review should be independent;
- the work may span multiple turns or sessions;
- the same failure pattern repeats.

## Delegation handoff

When delegating, pass only:

1. goal;
2. acceptance criteria;
3. relevant paths;
4. constraints;
5. commands to run;
6. expected report format.

Do not paste large file contents when paths and concise findings are enough.

## Review and oracle gates

Ask `reviewer` to review meaningful implementation changes, especially behavior, tests, scripts, config loading, security, public UX, or plan deviations.

Ask `oracle` only when reviewer escalates a strategic issue, the same failure signature repeats, a decision affects API/schema/state/IAM/security/data model, or two plausible approaches have unclear trade-offs.
```

Expected: prompt is concise and adaptive, not a verbatim OpenCode copy.

- [x] **Step 3: Write explorer prompt**

Create `/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/explorer.md` with exactly:

```md
# Role

You are `explorer`, a read-only research agent for Cline escalation workflows.

Find the smallest amount of context needed for the orchestrator or implementer to act correctly.

## Rules

- Do not edit files.
- Do not implement changes.
- Do not write plans or ADRs.
- Do not decide implementation order.
- Prefer targeted search and focused file reads.
- Avoid generated, vendored, cache, and lock files unless they are directly relevant.

## Find

- relevant files and entry points;
- existing patterns and constraints;
- likely affected tests or docs;
- hidden coupling and concrete risks;
- open questions requiring orchestration judgment.

## Output

Return a compact report:

1. Relevant paths;
2. Key findings, 3-7 bullets;
3. Likely affected files or areas;
4. Tests or checks likely affected;
5. Risks tied to concrete evidence;
6. Open questions;
7. Files the orchestrator or implementer should read directly.
```

Expected: prompt is read-only and compact.

- [x] **Step 4: Write implementer prompt**

Create `/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/implementer.md` with exactly:

```md
# Role

You are `implementer`, a scoped coding agent for Cline escalation workflows.

Make the smallest coherent change that satisfies the brief. Preserve existing style and do not broaden scope.

## Pre-tool ambiguity gate

Before reading broadly or editing, return `NEEDS_CONTEXT` if the brief lacks:

- concrete target behavior or acceptance criteria;
- relevant path, plan path, or sufficiently specific impact area;
- scope boundaries that separate required work from optional cleanup.

## Rules

- Do not create plans or ADRs.
- Do not make broad design decisions.
- Do not delegate to other agents.
- Read provided plan or report paths before implementing.
- Add or update tests when behavior changes and the repository has a relevant test pattern.
- Run relevant checks when possible.
- If the same failure class happens twice, stop with `BLOCKED` and a `failure_signature`.

## Report format

End with:

1. Status: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED;
2. Files changed;
3. Summary of changes;
4. Commands run;
5. Test result;
6. Deviations from brief or plan;
7. Remaining risks;
8. Failure signature, only if BLOCKED;
9. Suggested next action.
```

Expected: prompt includes the ambiguity gate and compact implementation report.

- [x] **Step 5: Write reviewer prompt**

Create `/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/reviewer.md` with exactly:

```md
# Role

You are `reviewer`, a read-only critical reviewer for Cline escalation workflows.

Review only the requested artifact type: plan, ADR, README, docs, script, configuration, or implementation diff.

## Rules

- Do not edit files.
- Do not implement fixes.
- Judge goal fit, not only instruction compliance.
- Use concrete evidence: paths, diff hunks, command output, or quoted requirements.
- Do not inflate severity beyond evidence.
- Preferences and style nits are not blockers.

## Check

- correctness;
- scope control;
- tests and validation;
- security and destructive-command risk;
- maintainability;
- compatibility with existing patterns;
- whether docs or README updates are needed.

## Output

1. Verdict: APPROVE / REQUEST_CHANGES / NEEDS_CONTEXT / ESCALATE;
2. Artifact type;
3. Goal fit;
4. Critical issues, each with ID, severity, confidence, evidence, why it matters, recommended action, and must-fix yes/no;
5. Non-blocking suggestions with the same fields;
6. Missing context or tests;
7. Whether oracle should be consulted, with one-line reason.
```

Expected: prompt is read-only and evidence-backed.

- [x] **Step 6: Write oracle prompt**

Create `/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/oracle.md` with exactly:

```md
# Role

You are `oracle`, a rare high-context decision consultant for Cline escalation workflows.

Do not implement. Do not review everything again. Decide the narrow next approach when ordinary implementation or review is insufficient.

## Use only when

- reviewer escalated a strategic issue;
- the same failure signature repeated;
- the decision affects API, schema, state, IAM, security, data model, or long-lived architecture;
- two plausible approaches have unclear trade-offs;
- the current direction appears to conflict with inherited constraints.

## Rules

- Do not edit files.
- Do not perform broad exploration.
- Prefer consistency over novelty.
- Prefer reversible decisions when uncertainty is high.
- Recommend narrow corrections before broad pivots.
- Explicitly state what not to do.

## Output

Keep the response under 600 tokens:

1. Inherited constraints;
2. Confidence: HIGH / MEDIUM / LOW;
3. Diagnosis;
4. Drift or contradiction check;
5. Recommended next approach;
6. What to ask implementer to do;
7. What not to do;
8. Remaining risks;
9. Whether reviewer is required after the next implementation.
```

Expected: prompt is short and reserved for rare escalation.

- [x] **Step 7: Verify prompt files exist**

Run:

```sh
find /Users/haru256/Documents/projects/dotfiles/.config/cline/prompts -maxdepth 1 -type f | sort
```

Expected output includes exactly these files:

```text
/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/explorer.md
/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/implementer.md
/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/oracle.md
/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/orchestrator.md
/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/reviewer.md
```

---

### Task 3: Add Agent Teams escalation wrapper

**Files:**
- Create: `/Users/haru256/Documents/projects/dotfiles/scripts/cline-team`

**Interfaces:**
- Consumes: real Cline executable resolved by `CLINE_BIN_PATH`, `mise which cline`, or known fallback paths.
- Consumes: symlinked prompt at `$HOME/.config/cline/prompts/orchestrator.md`.
- Produces: `cline-team [prompt...]`, an escalation entrypoint that starts Cline with `--team-name`, `--provider`, `--model`, `--thinking`, and `--system`.

- [x] **Step 1: Write wrapper script**

Create `/Users/haru256/Documents/projects/dotfiles/scripts/cline-team` with exactly:

```sh
#!/bin/sh
set -eu

# Launch Cline Agent Teams with the adaptive orchestrator prompt.
#
# Use normal `cline` for small/local tasks. Use this wrapper when the task
# benefits from multi-step coordination, independent implementation/review,
# or rare oracle-style decision support.

physical_path() {
  CDPATH= cd -- "$(dirname -- "$1")" && printf '%s/%s\n' "$(pwd -P)" "$(basename -- "$1")"
}

find_real_cline() {
  self=$(physical_path "$0")

  if [ -n "${CLINE_BIN_PATH:-}" ] && [ -x "$CLINE_BIN_PATH" ]; then
    candidate=$(physical_path "$CLINE_BIN_PATH")
    if [ "$candidate" != "$self" ]; then
      printf '%s\n' "$CLINE_BIN_PATH"
      return 0
    fi
  fi

  if command -v mise >/dev/null 2>&1; then
    real=$(mise which cline 2>/dev/null || true)
    if [ -n "${real:-}" ] && [ -x "$real" ]; then
      candidate=$(physical_path "$real")
      if [ "$candidate" != "$self" ]; then
        printf '%s\n' "$real"
        return 0
      fi
    fi
  fi

  for candidate in \
    "$HOME/.local/share/mise/installs/npm-cline/latest/bin/cline" \
    "$HOME/.local/share/mise/installs/npm-cline/3.0.34/lib/node_modules/cline/bin/cline" \
    "$HOME/.local/share/mise/installs/npm-cline/3.0.31/lib/node_modules/cline/bin/cline" \
    "$HOME/.npm-global/bin/cline" \
    "$HOME/.bun/bin/cline" \
    "/opt/homebrew/bin/cline" \
    "/usr/local/bin/cline"
  do
    if [ -x "$candidate" ]; then
      candidate_physical=$(physical_path "$candidate")
      if [ "$candidate_physical" != "$self" ]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    fi
  done

  printf '%s\n' "cline-team: real Cline executable not found" >&2
  exit 127
}

prompt_path="${CLINE_ORCHESTRATOR_PROMPT:-$HOME/.config/cline/prompts/orchestrator.md}"

if [ ! -r "$prompt_path" ]; then
  printf '%s\n' "cline-team: orchestrator prompt not readable: $prompt_path" >&2
  printf '%s\n' "cline-team: symlink ~/dotfiles/.config/cline/prompts to ~/.config/cline/prompts first" >&2
  exit 66
fi

exec "$(find_real_cline)" \
  --team-name "${CLINE_TEAM_NAME:-dotfiles-agents}" \
  --provider "${CLINE_PROVIDER:-openai-codex}" \
  --model "${CLINE_MODEL:-gpt-5.5}" \
  --thinking "${CLINE_THINKING:-medium}" \
  --system "$(cat "$prompt_path")" \
  "$@"
```

Expected: file exists and is POSIX shell.

- [x] **Step 2: Make wrapper executable**

Run:

```sh
chmod +x /Users/haru256/Documents/projects/dotfiles/scripts/cline-team
```

Expected: command exits 0.

- [x] **Step 3: Run shell syntax check**

Run:

```sh
sh -n /Users/haru256/Documents/projects/dotfiles/scripts/cline-team
```

Expected: command exits 0 and prints nothing.

---

### Task 4: Update README Cline usage

**Files:**
- Modify: `/Users/haru256/Documents/projects/dotfiles/README.md`

**Interfaces:**
- Consumes: new `.config/cline/prompts`, `.cline/rules/adaptive-coding.md`, and `scripts/cline-team` files from earlier tasks.
- Produces: setup and usage documentation for the adaptive workflow.

- [x] **Step 1: Replace the Cline section with adaptive workflow documentation**

In `/Users/haru256/Documents/projects/dotfiles/README.md`, replace the current `### Cline` section body with:

```md
### Cline

token を節約しつつコーディング性能を上げるため、Cline は adaptive workflow で使います。

- 小さく局所的な作業: 通常の `cline`
- 複数 step、広い調査、独立レビュー、失敗ループがある作業: `cline-team`
- 常時読むルール: `.cline/rules/adaptive-coding.md`
- escalation 時だけ読む role prompt: `.config/cline/prompts/*.md`

```sh
mkdir -p ~/.local/bin ~/.config/cline
ln -s ~/dotfiles/scripts/cline-team ~/.local/bin/cline-team
ln -s ~/dotfiles/.config/cline/prompts ~/.config/cline/prompts
chmod +x ~/dotfiles/scripts/cline-team
```

通常は安い single-session path を使います。

```sh
cline "小さな修正を実装して"
```

複雑な作業だけ Agent Teams に escalation します。

```sh
cline-team "調査して、必要なら実装してレビューして"
```

`cline-team` の既定値は環境変数で上書きできます。

```sh
CLINE_TEAM_NAME=my-task CLINE_THINKING=high cline-team "..."
```

通常の `cline` は mise などでインストールした実体をそのまま使います。
```

Expected: README documents default path, escalation path, symlinks, and overrides.

- [x] **Step 2: Verify README section**

Run:

```sh
sed -n '86,135p' /Users/haru256/Documents/projects/dotfiles/README.md
```

Expected: output shows the updated Cline section and no duplicated old Cline setup block.

---

### Task 5: Validate integrated workflow files

**Files:**
- Read: `/Users/haru256/Documents/projects/dotfiles/.cline/rules/adaptive-coding.md`
- Read: `/Users/haru256/Documents/projects/dotfiles/.config/cline/prompts/*.md`
- Read: `/Users/haru256/Documents/projects/dotfiles/scripts/cline-team`
- Read: `/Users/haru256/Documents/projects/dotfiles/README.md`

**Interfaces:**
- Consumes: all files created or modified by Tasks 1-4.
- Produces: verified final diff and validation results.

- [x] **Step 1: Run shell syntax check**

Run:

```sh
sh -n /Users/haru256/Documents/projects/dotfiles/scripts/cline-team
```

Expected: command exits 0 and prints nothing.

- [x] **Step 2: Check for forbidden placeholders and typo role names**

Run:

```sh
grep -R -nE 'TBD|TODO|orchestorator|exploter' \
  /Users/haru256/Documents/projects/dotfiles/.cline/rules/adaptive-coding.md \
  /Users/haru256/Documents/projects/dotfiles/.config/cline/prompts \
  /Users/haru256/Documents/projects/dotfiles/scripts/cline-team \
  /Users/haru256/Documents/projects/dotfiles/README.md || true
```

Expected: no matches from the new Cline workflow files. Existing unrelated matches elsewhere do not matter.

- [x] **Step 3: Inspect final diff**

Run:

```sh
git diff -- \
  /Users/haru256/Documents/projects/dotfiles/.cline/rules/adaptive-coding.md \
  /Users/haru256/Documents/projects/dotfiles/.config/cline \
  /Users/haru256/Documents/projects/dotfiles/scripts/cline-team \
  /Users/haru256/Documents/projects/dotfiles/README.md \
  /Users/haru256/Documents/projects/dotfiles/docs/superpowers/specs/2026-06-30-cline-agent-team-design.md \
  /Users/haru256/Documents/projects/dotfiles/docs/superpowers/plans/2026-06-30-cline-adaptive-coding-workflow.md
```

Expected: diff only contains the adaptive Cline workflow changes and does not modify `.config/opencode/`.

- [x] **Step 4: Optionally test wrapper help**

Run only if Cline hub daemon is not known to be failing:

```sh
/Users/haru256/Documents/projects/dotfiles/scripts/cline-team --help
```

Expected: Cline help output. If it fails with a hub daemon port conflict, record the failure and rely on `sh -n` for script syntax validation.

---

## Review Findings

### Reviewer Raw Findings

No reviewer findings yet.

### Orchestrator Adjudication

No adjudication yet.

## Deviations

No deviations yet.

## Open Questions

- Whether to add separate headless wrapper scripts for `reviewer` and `oracle` later. This is intentionally out of scope for the initial adaptive workflow.

## Implementation Log

- [2026-06-30] Task 1 -> DONE | created `.cline/rules/adaptive-coding.md`; task review approved spec compliance and quality.
- [2026-06-30] Task 2 -> DONE | created five Cline escalation prompts under `.config/cline/prompts/`; task review approved spec compliance and quality.
- [2026-06-30] Task 3 -> DONE | created executable `scripts/cline-team`; `sh -n scripts/cline-team` passed; task review approved spec compliance and quality.
- [2026-06-30] Task 4 -> DONE | updated README Cline section for adaptive workflow; task review approved spec compliance and quality.
- [2026-06-30] Task 5 -> DONE_WITH_CONCERNS | integrated validation passed; `scripts/cline-team --help` could not reach Cline because `~/.config/cline/prompts/orchestrator.md` is not symlinked yet, which is expected before installation.

## Self-review

- Spec coverage: Tasks cover compact project rule, escalation prompts, `cline-team`, README, and validation. Out-of-scope role-specific config directories and `.cline/agents.yaml` are not implemented.
- Placeholder scan: no `TBD`, `TODO`, `implement later`, or unspecified implementation steps are intentionally left in this plan.
- Type/interface consistency: paths and environment variable names are consistent across tasks and README instructions.