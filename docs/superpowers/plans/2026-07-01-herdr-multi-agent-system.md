# Herdr Multi-Agent System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Superseded historical plan:** the current Herdr packaging lives under `.agents/skills/using-herdr-agents/`. References below to `.config/herdr/agents` or manual `~/.local/bin` symlinks are legacy move notes only, not the canonical setup.

**Goal:** Add a simple Herdr-launched multi-agent workflow where Codex plans and judges, OpenCode Go or Cline scouts, Agy implements and audits, and Codex handles rare high-reasoning advice.

**Architecture:** Keep the first version small: four specialist roles (`scout`, `coder`, `auditor`, `advisor`) plus Codex as the parent planner/judge. Store shared role prompts in one dotfiles-managed prompt directory, add only a new OpenCode `scout_v2` agent, add a Cline `scout_v2` runner route that reuses the same scout prompt, and launch all roles through two shell wrappers that support dry-run validation before spending model quota. Reuse an existing Herdr agent session only when a stable context key matches and the agent is idle; otherwise start a fresh session.

**Tech Stack:** POSIX `sh`, Herdr CLI, OpenCode CLI, Cline CLI, Agy/Antigravity CLI, Codex CLI, Markdown prompts, JSONC OpenCode config, shell tests.

---

## Global Constraints

- Do not change existing OpenCode `explorer`, `implementer`, `reviewer`, `orchestrator`, or `oracle` agents.
- Add only a new OpenCode `scout_v2` agent.
- Do not create duplicate Cline prompt content for Scout; Cline `scout_v2` must reuse `.agents/skills/using-herdr-agents/prompts/scout.md`.
- Keep the initial runtime model mapping simple:
  - Planner/Judge: Codex `gpt-5.5`, `model_reasoning_effort = medium`
  - Scout default: OpenCode Go `opencode-go/deepseek-v4-flash`
  - Scout fallback: Cline Pass `deepseek-v4-flash` through `HERDR_AGENT_SCOUT_BACKEND=cline`
  - Coder: Agy `Gemini 3.5 Flash (Medium)`
  - Auditor: Agy `Gemini 3.5 Flash (Medium)`
  - Advisor: Codex `gpt-5.5`, `model_reasoning_effort = high` by default, `xhigh` by environment override
- Do not add Light/Strong role variants in the first version.
- Do not blindly reuse agent sessions. Reuse is allowed only when the role, repository/worktree, backend, model class, and task context are still aligned.
- Codex Planner/Judge owns session reuse decisions through `HERDR_AGENT_CONTEXT_KEY` and `HERDR_AGENT_REUSE`; workers must not decide to reuse or fork themselves.
- Escalation is a policy, not a separate agent: after repeated failure, API/schema/security risk, or contradictory review, Codex invokes Advisor with `high` or `xhigh`.
- Do not commit changes. The repository `AGENTS.md` forbids commits unless explicitly requested by the user.
- Preserve existing user changes in `.codex/config.toml`, `.config/mise/config.toml`, `.config/zed/settings.json`, `README.md`, and `.config/herdr/`.

## File Structure

- Create `.agents/skills/using-herdr-agents/prompts/shared.md`: common constraints loaded by the runner for every role.
- Create `.agents/skills/using-herdr-agents/prompts/scout.md`: read-only scout role prompt.
- Create `.agents/skills/using-herdr-agents/prompts/coder.md`: scoped implementation role prompt.
- Create `.agents/skills/using-herdr-agents/prompts/auditor.md`: read-only review role prompt.
- Create `.agents/skills/using-herdr-agents/prompts/advisor.md`: rare high-reasoning decision role prompt.
- Modify `.config/opencode/opencode.json`: add new `scout_v2` agent only.
- Create `.agents/skills/using-herdr-agents/scripts/herdr-agent`: role runner that chooses OpenCode, Cline, Agy, or Codex and supports dry-run output. It supports `HERDR_AGENT_MODE=oneshot|interactive`.
- Create `.agents/skills/using-herdr-agents/scripts/herdr-agent-session`: Herdr launcher for `.agents/skills/using-herdr-agents/scripts/herdr-agent`, with context-keyed session reuse. It defaults to persistent interactive sessions and supports `HERDR_AGENT_SESSION_MODE=oneshot` for explicit non-persistent runs.
- Create `tests/herdr-agent.sh`: dry-run regression tests for role-to-harness/model mapping.
- Modify `README.md`: document symlinks, roles, model mapping, usage, and validation commands.

Superseded packaging note: the Herdr prompts and runner scripts now live under `.agents/skills/using-herdr-agents/` so the skill, prompts, scripts, installer, and tests move together. Older `~/.config/herdr/agents` references below are move-source notes only.

## Runtime Flow

1. User asks Codex for work.
2. Codex Planner/Judge decides the minimal workflow:
   - small, clear edit: `coder`
   - unknown repository context: `scout`, then Codex writes a tight coder brief
   - meaningful diff: `auditor`, then Codex adjudicates findings
   - repeated failure or high-risk design decision: `advisor`
3. Codex starts workers through Herdr:
   - `HERDR_AGENT_CONTEXT_KEY=herdr-multi-agent .agents/skills/using-herdr-agents/scripts/herdr-agent-session scout "brief"`
   - `HERDR_AGENT_CONTEXT_KEY=herdr-multi-agent HERDR_AGENT_SCOUT_BACKEND=cline .agents/skills/using-herdr-agents/scripts/herdr-agent-session scout "brief"` when OpenCode Go quota should be preserved
   - `HERDR_AGENT_CONTEXT_KEY=herdr-multi-agent .agents/skills/using-herdr-agents/scripts/herdr-agent-session coder "brief"`
   - `HERDR_AGENT_CONTEXT_KEY=herdr-multi-agent .agents/skills/using-herdr-agents/scripts/herdr-agent-session auditor "brief"`
   - `HERDR_AGENT_CONTEXT_KEY=herdr-multi-agent HERDR_AGENT_ADVISOR_THINKING=xhigh .agents/skills/using-herdr-agents/scripts/herdr-agent-session advisor "brief"`
4. Workers report structured output. Codex is the only component that decides next action.

---

## Session Reuse Policy

Session reuse is a latency optimization, not a correctness requirement.

Use an existing session when all of these are true:

- Same repository or worktree.
- Same role and backend, for example `scout` + `opencode` or `scout` + `cline`.
- Same model class and reasoning tier.
- Same feature, bug, or investigation thread, represented by `HERDR_AGENT_CONTEXT_KEY`.
- Existing agent is `idle`.
- Previous output was accepted or is still useful evidence.

Start a fresh session when any of these are true:

- Different repository, worktree, branch purpose, or feature context.
- Role or backend changes.
- Scout context moves from broad discovery to unrelated discovery.
- Coder or Auditor previously returned `BLOCKED`, repeated failure, or bad assumptions.
- Security-sensitive files, credentials, destructive operations, or external account state are involved.
- Prompt contracts changed during the current work.
- Codex needs an independent reviewer with fresh context.

The launcher supports:

- `HERDR_AGENT_CONTEXT_KEY=<slug>`: stable context name chosen by Codex for the work item.
- `HERDR_AGENT_REUSE=auto`: default; reuse an idle matching session, otherwise start a new one.
- `HERDR_AGENT_REUSE=never`: force a new session.
- `HERDR_AGENT_REUSE=require`: fail unless an idle matching session exists.

If `HERDR_AGENT_CONTEXT_KEY` is not set, the launcher falls back to a repository-and-branch key. Codex should set an explicit context key for multi-step work to avoid accidentally mixing unrelated tasks in the same repository.

---

### Task 1: Add Shared Herdr Agent Prompts

**Files:**
- Create: `.agents/skills/using-herdr-agents/prompts/shared.md`
- Create: `.agents/skills/using-herdr-agents/prompts/scout.md`
- Create: `.agents/skills/using-herdr-agents/prompts/coder.md`
- Create: `.agents/skills/using-herdr-agents/prompts/auditor.md`
- Create: `.agents/skills/using-herdr-agents/prompts/advisor.md`

- [ ] **Step 1: Create the prompt directory**

Run:

```sh
mkdir -p .agents/skills/using-herdr-agents/prompts
```

Expected: directory exists.

- [ ] **Step 2: Create the shared prompt**

Create `.agents/skills/using-herdr-agents/prompts/shared.md` with:

```md
# Herdr Multi-Agent Shared Rules

You are a specialist worker launched by Codex Planner/Judge through Herdr.

The parent Codex session owns planning, final judgment, and user-facing decisions.
Your job is to complete only your assigned role and return a compact report.

## Shared constraints

- Follow the task brief exactly.
- Preserve unrelated user changes.
- Do not commit, push, tag, release, merge, rebase, reset, or revert user changes.
- Do not run destructive commands.
- Keep output compact and structured.
- Do not invent product requirements.
- Ask for missing context by returning `NEEDS_CONTEXT` instead of guessing.
- If the same failure class repeats twice, stop and return `BLOCKED` with a stable `FAILURE_SIGNATURE`.

## Parent decision boundary

- Scout returns evidence, not a plan.
- Coder implements the brief, not a broader design.
- Auditor reports findings, not implementation instructions.
- Advisor recommends the next narrow approach, not a full re-plan.
- Codex Planner/Judge decides what to do with every report.
```

- [ ] **Step 3: Create the scout prompt**

Create `.agents/skills/using-herdr-agents/prompts/scout.md` with:

```md
# Scout Role

You are `scout`, a read-only repository exploration worker.

Default model/harness: OpenCode Go `opencode-go/deepseek-v4-flash`.
Fallback model/harness: Cline Pass `deepseek-v4-flash` through the Herdr `scout_v2` runner route.

## Mission

Find the smallest amount of repository context Codex Planner/Judge needs to write a safe brief.

## Rules

- Do not edit files.
- Do not implement changes.
- Do not write plans, ADRs, or README changes.
- Do not decide implementation order.
- Prefer `rg`, `git grep`, `git ls-files`, and focused file reads.
- Avoid generated files, vendored dependencies, lock files, and caches unless the brief names them.
- Return concrete paths and evidence.
- If external research is needed, say so under `OPEN_QUESTIONS`; do not browse unless the brief explicitly asks for external facts.

## Output format

STATUS: DONE | NEEDS_CONTEXT
RELEVANT_PATHS:
- path: one-line reason
KEY_FINDINGS:
- evidence-backed finding
RISKS:
- concrete risk tied to path or behavior
CHECKS:
- command likely relevant for this change
FILES_FOR_PLANNER:
- path Codex should read directly before briefing Coder
OPEN_QUESTIONS:
- question that must be answered before safe implementation
```

- [ ] **Step 4: Create the coder prompt**

Create `.agents/skills/using-herdr-agents/prompts/coder.md` with:

```md
# Coder Role

You are `coder`, a scoped implementation worker.

Model/harness: Agy `Gemini 3.5 Flash (Medium)`.

## Mission

Make the smallest coherent change that satisfies the brief, then run the most relevant check.

## Pre-tool ambiguity gate

Return `NEEDS_CONTEXT` before editing if the brief lacks any of:

- target behavior or acceptance criteria
- relevant files, plan path, or impact area
- scope boundaries that separate required work from optional cleanup
- validation command or enough repository context to choose one

## Rules

- Do not create plans or ADRs.
- Do not make broad design decisions.
- Do not refactor unrelated code.
- Do not change public API, schema, state, IAM, auth, security boundaries, or data model unless the brief explicitly says to.
- Preserve existing style and naming.
- Add or update tests only when behavior changes and a local test pattern is obvious.
- If validation fails and the cause is clear, make one narrow fix and rerun the same validation.
- If the same failure class happens twice, stop with `BLOCKED`.

## Output format

STATUS: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
FILES_CHANGED:
- path
SUMMARY:
- short change summary
COMMANDS_RUN:
- command -> result
TEST_RESULT:
- pass/fail/not-run with reason
DEVIATIONS:
- deviation from brief or `none`
RISKS:
- remaining concrete risk or `none`
FAILURE_SIGNATURE:
- stable one-line signature when BLOCKED, otherwise `none`
NEXT_ACTION:
- recommended next Codex action
```

- [ ] **Step 5: Create the auditor prompt**

Create `.agents/skills/using-herdr-agents/prompts/auditor.md` with:

```md
# Auditor Role

You are `auditor`, a read-only review worker.

Model/harness: Agy `Gemini 3.5 Flash (Medium)`.

## Mission

Review the requested artifact against the goal, scope, diff, and validation evidence.

## Rules

- Do not edit files.
- Do not implement fixes.
- Do not broaden the review beyond the requested artifact.
- Review goal fit, correctness, tests, security, compatibility, and scope control.
- Use concrete evidence: paths, diff hunks, command output, or quoted brief requirements.
- Do not turn style preferences into blockers.
- Do not request changes without evidence.
- If the artifact touches API, schema, state, IAM, auth, security, data model, or long-lived architecture, return `ESCALATE` unless the risk is clearly trivial.

## Severity calibration

- BLOCKER: likely data loss, credential exposure, broken auth, schema/state corruption, or severe goal mismatch.
- MAJOR: violates acceptance criteria, breaks compatibility, or leaves meaningful user-visible incorrect behavior.
- MINOR: valid maintainability, edge-case, test, or docs issue that does not block the stated goal.
- NIT: wording, formatting, naming, or local style preference.

## Output format

VERDICT: APPROVE | REQUEST_CHANGES | NEEDS_CONTEXT | ESCALATE
ARTIFACT:
- plan | docs | implementation | config | script
GOAL_FIT:
- one sentence
CRITICAL_FINDINGS:
- ID: A1
  Severity: BLOCKER | MAJOR | MINOR | NIT
  Confidence: HIGH | MEDIUM | LOW
  Evidence: path, diff hunk, or command output
  Why it matters: one sentence
  Recommended action: scoped action
  Must fix: yes | no | uncertain
NON_BLOCKING_FINDINGS:
- same structure, or `none`
MISSING_TESTS_OR_CONTEXT:
- concrete gap, or `none`
ADVISOR_NEEDED: yes | no
```

- [ ] **Step 6: Create the advisor prompt**

Create `.agents/skills/using-herdr-agents/prompts/advisor.md` with:

```md
# Advisor Role

You are `advisor`, a rare high-reasoning decision worker.

Model/harness: Codex `gpt-5.5` with `model_reasoning_effort = high` or `xhigh`.

## Mission

Resolve a narrow strategic question when ordinary scout/coder/auditor flow is insufficient.

## Use only when

- the same failure signature repeated
- Coder and Auditor reports conflict
- the decision affects API, schema, state, IAM, auth, security, data model, or long-lived architecture
- the current direction appears to conflict with inherited constraints
- Codex Planner/Judge needs a high-reasoning second pass before briefing Coder again

## Rules

- Do not edit files.
- Do not perform broad exploration.
- Do not become a second planner for the whole task.
- Prefer narrow corrections over broad pivots.
- Explicitly state what not to do.
- If repository facts are missing, ask for a Scout pass instead of guessing.

## Output format

CONFIDENCE: HIGH | MEDIUM | LOW
DIAGNOSIS:
- concise diagnosis
RECOMMENDED_NEXT_APPROACH:
- narrow next approach
WHAT_TO_ASK_CODER:
- exact brief Codex should pass to Coder
WHAT_NOT_TO_DO:
- concrete anti-action
RISKS:
- remaining assumptions or risks
ADVISOR_THINKING_USED:
- high | xhigh
```

- [ ] **Step 7: Verify prompt files exist**

Run:

```sh
find .agents/skills/using-herdr-agents/prompts -maxdepth 1 -type f -print | sort
```

Expected output:

```text
.agents/skills/using-herdr-agents/prompts/advisor.md
.agents/skills/using-herdr-agents/prompts/auditor.md
.agents/skills/using-herdr-agents/prompts/coder.md
.agents/skills/using-herdr-agents/prompts/scout.md
.agents/skills/using-herdr-agents/prompts/shared.md
```

---

### Task 2: Add OpenCode `scout_v2`

**Files:**
- Modify: `.config/opencode/opencode.json`

This task registers the OpenCode side only. Cline does not need a separate prompt file or OpenCode-style agent entry; the Cline `scout_v2` route is implemented in `.agents/skills/using-herdr-agents/scripts/herdr-agent` in Task 3 and uses the same `.agents/skills/using-herdr-agents/prompts/scout.md` prompt.

- [ ] **Step 1: Add only the new `scout_v2` agent**

In `.config/opencode/opencode.json`, inside the top-level `"agent"` object, add this entry after `"scout": { "disable": true },` and before `"orchestrator": { ... }`:

```jsonc
    "scout_v2": {
      "description": "Herdr v2 read-only scout. Finds relevant files, existing patterns, impact radius, risks, and validation commands. Returns evidence only.",
      "mode": "all",
      "model": "opencode-go/deepseek-v4-flash",
      "temperature": 0.1,
      "prompt": "{file:~/.agents/skills/using-herdr-agents/prompts/scout.md}",
      "permission": {
        "edit": "deny",
        "read": "allow",
        "bash": {
          "*": "allow",
          "rm -rf *": "deny",
          "sudo *": "ask"
        },
        "external_directory": "allow",
        "webfetch": "deny",
        "websearch": "deny",
        "question": "allow",
        "codesearch": "allow",
        "skill": "deny",
        "todowrite": "deny",
        "grep": "allow",
        "lsp": "allow",
        "task": "deny",
        "glob": "allow",
        "list": "allow"
      }
    },
```

Do not modify the existing `explorer`, `implementer`, `reviewer`, `orchestrator`, or `oracle` entries.

- [ ] **Step 2: Verify the new agent is present and existing agents still exist**

Run:

```sh
rg -n '"(scout_v2|explorer|implementer|reviewer|orchestrator|oracle)"' .config/opencode/opencode.json
```

Expected: output includes `scout_v2` and the five existing role names.

- [ ] **Step 3: Verify OpenCode can see `scout_v2` without launching a model call**

Run:

```sh
mise exec -- opencode agent list | rg 'scout_v2'
```

Expected: output contains `scout_v2`.

If this command does not read the repository-managed config because the home symlink is missing, finish Task 6 first and rerun this step.

---

### Task 3: Add the Role Runner Script

**Files:**
- Create: `.agents/skills/using-herdr-agents/scripts/herdr-agent`

- [ ] **Step 1: Create `.agents/skills/using-herdr-agents/scripts/herdr-agent`**

Create `.agents/skills/using-herdr-agents/scripts/herdr-agent` with:

```sh
#!/bin/sh
set -eu

usage() {
  printf '%s\n' "usage: $(basename "$0") <scout|coder|auditor|advisor> <task prompt>" >&2
}

physical_dirname() {
  CDPATH= cd -- "$(dirname -- "$1")" && pwd -P
}

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

  printf '%s\n' "herdr-agent: real Cline executable not found" >&2
  exit 127
}

if [ "$#" -lt 2 ]; then
  usage
  exit 64
fi

role="$1"
shift
task_prompt="$*"

if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
  repo_root="$git_root"
else
  repo_root=$(pwd -P)
fi

script_dir=$(physical_dirname "$0")
dotfiles_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)

prompt_dir="${HERDR_AGENT_PROMPT_DIR:-$SKILL_DIR/prompts}"
if [ ! -d "$prompt_dir" ] && [ -d "$dotfiles_root/.agents/skills/using-herdr-agents/prompts" ]; then
  prompt_dir="$dotfiles_root/.agents/skills/using-herdr-agents/prompts"
fi

shared_prompt="$prompt_dir/shared.md"
role_prompt="$prompt_dir/$role.md"

if [ ! -r "$shared_prompt" ]; then
  printf '%s\n' "herdr-agent: shared prompt not readable: $shared_prompt" >&2
  exit 66
fi

if [ ! -r "$role_prompt" ]; then
  printf '%s\n' "herdr-agent: role prompt not readable: $role_prompt" >&2
  exit 66
fi

case "$role" in
  scout)
    backend="${HERDR_AGENT_SCOUT_BACKEND:-opencode}"
    case "$backend" in
      opencode)
        model="${HERDR_AGENT_SCOUT_MODEL:-opencode-go/deepseek-v4-flash}"
        agent="${HERDR_AGENT_SCOUT_OPENCODE_AGENT:-scout_v2}"
        ;;
      cline)
        provider="${HERDR_AGENT_SCOUT_CLINE_PROVIDER:-cline-pass}"
        model="${HERDR_AGENT_SCOUT_CLINE_MODEL:-deepseek-v4-flash}"
        thinking="${HERDR_AGENT_SCOUT_CLINE_THINKING:-low}"
        ;;
      *)
        printf '%s\n' "herdr-agent: HERDR_AGENT_SCOUT_BACKEND must be opencode or cline: $backend" >&2
        exit 65
        ;;
    esac
    ;;
  coder)
    backend="agy"
    model="${HERDR_AGENT_CODER_MODEL:-Gemini 3.5 Flash (Medium)}"
    ;;
  auditor)
    backend="agy"
    model="${HERDR_AGENT_AUDITOR_MODEL:-Gemini 3.5 Flash (Medium)}"
    ;;
  advisor)
    backend="codex"
    model="${HERDR_AGENT_ADVISOR_MODEL:-gpt-5.5}"
    thinking="${HERDR_AGENT_ADVISOR_THINKING:-high}"
    case "$thinking" in
      high|xhigh) ;;
      *)
        printf '%s\n' "herdr-agent: advisor thinking must be high or xhigh: $thinking" >&2
        exit 65
        ;;
    esac
    ;;
  *)
    usage
    exit 64
    ;;
esac

role_system_prompt=$(cat "$shared_prompt"; printf '\n\n'; cat "$role_prompt")
full_prompt=$(printf '%s\n\n# Repository Root\n\n%s\n\n# Task Brief\n\n%s\n' "$role_system_prompt" "$repo_root" "$task_prompt")
mode="${HERDR_AGENT_MODE:-oneshot}"
case "$mode" in
  oneshot|interactive) ;;
  *)
    printf '%s\n' "herdr-agent: HERDR_AGENT_MODE must be oneshot or interactive: $mode" >&2
    exit 65
    ;;
esac

if [ "${HERDR_AGENT_DRY_RUN:-0}" = "1" ]; then
  printf 'ROLE=%s\n' "$role"
  printf 'BACKEND=%s\n' "$backend"
  printf 'MODEL=%s\n' "$model"
  printf 'MODE=%s\n' "$mode"
  printf 'REPO_ROOT=%s\n' "$repo_root"
  printf 'PROMPT_DIR=%s\n' "$prompt_dir"
  case "$role" in
    scout)
      case "$backend" in
        opencode)
          printf 'OPENCODE_AGENT=%s\n' "$agent"
          ;;
        cline)
          printf 'CLINE_PROVIDER=%s\n' "$provider"
          printf 'CLINE_THINKING=%s\n' "$thinking"
          ;;
      esac
      ;;
    advisor)
      printf 'THINKING=%s\n' "$thinking"
      ;;
  esac
  printf 'TASK_LENGTH=%s\n' "$(printf '%s' "$task_prompt" | wc -c | tr -d ' ')"
  exit 0
fi

case "$backend" in
  opencode)
    if ! command -v mise >/dev/null 2>&1; then
      printf '%s\n' "herdr-agent: mise is required for opencode" >&2
      exit 127
    fi
    if [ "$mode" = "interactive" ]; then
      exec mise exec -- opencode "$repo_root" \
        --model "$model" \
        --agent "$agent" \
        --mini \
        --prompt "$full_prompt"
    fi
    exec mise exec -- opencode run \
      --model "$model" \
      --agent "$agent" \
      --format default \
      --dir "$repo_root" \
      "$full_prompt"
    ;;
  cline)
    exec "$(find_real_cline)" \
      --provider "$provider" \
      --model "$model" \
      --thinking "$thinking" \
      --cwd "$repo_root" \
      --system "$role_system_prompt" \
      "$task_prompt"
    ;;
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
        --print "$full_prompt"
    fi
    exec agy \
      --model "$model" \
      --new-project \
      --add-dir "$repo_root" \
      --sandbox \
      --print-timeout "${HERDR_AGENT_AGY_TIMEOUT:-10m}" \
      --print "$full_prompt"
    ;;
  codex)
    if [ "$mode" = "interactive" ]; then
      exec codex \
        -m "$model" \
        -c "model_reasoning_effort=\"$thinking\"" \
        -C "$repo_root" \
        "$full_prompt"
    fi
    exec codex exec \
      -m "$model" \
      -c "model_reasoning_effort=\"$thinking\"" \
      -C "$repo_root" \
      "$full_prompt"
    ;;
esac
```

- [ ] **Step 2: Make the script executable**

Run:

```sh
chmod +x .agents/skills/using-herdr-agents/scripts/herdr-agent
```

Expected: command exits 0.

- [ ] **Step 3: Verify shell syntax**

Run:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent
```

Expected: no output and exit 0.

- [ ] **Step 4: Verify role-to-model mapping without spending quota**

Run:

```sh
HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PWD/.agents/skills/using-herdr-agents/prompts" .agents/skills/using-herdr-agents/scripts/herdr-agent scout "find relevant files"
HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PWD/.agents/skills/using-herdr-agents/prompts" HERDR_AGENT_SCOUT_BACKEND=cline .agents/skills/using-herdr-agents/scripts/herdr-agent scout "find relevant files"
HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PWD/.agents/skills/using-herdr-agents/prompts" .agents/skills/using-herdr-agents/scripts/herdr-agent coder "change one file"
HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PWD/.agents/skills/using-herdr-agents/prompts" .agents/skills/using-herdr-agents/scripts/herdr-agent auditor "review git diff"
HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PWD/.agents/skills/using-herdr-agents/prompts" HERDR_AGENT_ADVISOR_THINKING=xhigh .agents/skills/using-herdr-agents/scripts/herdr-agent advisor "decide next approach"
```

Expected:

```text
ROLE=scout
BACKEND=opencode
MODEL=opencode-go/deepseek-v4-flash
OPENCODE_AGENT=scout_v2
```

```text
ROLE=scout
BACKEND=cline
MODEL=deepseek-v4-flash
CLINE_PROVIDER=cline-pass
CLINE_THINKING=low
```

```text
ROLE=coder
BACKEND=agy
MODEL=Gemini 3.5 Flash (Medium)
```

```text
ROLE=auditor
BACKEND=agy
MODEL=Gemini 3.5 Flash (Medium)
```

```text
ROLE=advisor
BACKEND=codex
MODEL=gpt-5.5
THINKING=xhigh
```

---

### Task 4: Add the Herdr Launcher Script

**Files:**
- Create: `.agents/skills/using-herdr-agents/scripts/herdr-agent-session`

- [ ] **Step 1: Create `.agents/skills/using-herdr-agents/scripts/herdr-agent-session`**

Create `.agents/skills/using-herdr-agents/scripts/herdr-agent-session` with:

```sh
#!/bin/sh
set -eu

usage() {
  printf '%s\n' "usage: $(basename "$0") <scout|coder|auditor|advisor> <task prompt>" >&2
}

sanitize_agent_part() {
  value=$(printf '%s' "$1" | tr -c '[:alnum:]_.-' '-')
  value=$(printf '%s' "$value" | sed 's/--*/-/g; s/^-//; s/-$//')
  if [ -z "$value" ]; then
    value="default"
  fi
  printf '%s\n' "$value"
}

if [ "$#" -lt 2 ]; then
  usage
  exit 64
fi

role="$1"
shift
task_prompt="$*"

case "$role" in
  scout|coder|auditor|advisor) ;;
  *)
    usage
    exit 64
    ;;
esac

if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
  repo_root="$git_root"
else
  repo_root=$(pwd -P)
fi

branch=$(git -C "$repo_root" branch --show-current 2>/dev/null || true)
if [ -z "${branch:-}" ]; then
  branch="detached"
fi

case "$role" in
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
        model_name="unknown"
        ;;
    esac
    ;;
  coder)
    backend_name="agy"
    model_name="${HERDR_AGENT_CODER_MODEL:-Gemini 3.5 Flash (Medium)}"
    ;;
  auditor)
    backend_name="agy"
    model_name="${HERDR_AGENT_AUDITOR_MODEL:-Gemini 3.5 Flash (Medium)}"
    ;;
  advisor)
    backend_name="codex"
    model_name="${HERDR_AGENT_ADVISOR_MODEL:-gpt-5.5}-${HERDR_AGENT_ADVISOR_THINKING:-high}"
    ;;
esac

context_key="${HERDR_AGENT_CONTEXT_KEY:-$(basename "$repo_root")-$branch}"
context_key=$(sanitize_agent_part "$context_key")
backend_key=$(sanitize_agent_part "$backend_name-$model_name")
repo_key=$(printf '%s' "$repo_root" | cksum | awk '{print $1}')
default_agent_name="herdr-${role}-${repo_key}-${backend_key}-${context_key}"
agent_name="${HERDR_AGENT_NAME:-$default_agent_name}"

reuse="${HERDR_AGENT_REUSE:-auto}"
case "$reuse" in
  auto|never|require) ;;
  *)
    printf '%s\n' "herdr-agent-session: HERDR_AGENT_REUSE must be auto, never, or require: $reuse" >&2
    exit 65
    ;;
esac

if command -v herdr-agent >/dev/null 2>&1; then
  runner="herdr-agent"
else
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
  runner="$script_dir/herdr-agent"
fi

if [ ! -x "$runner" ]; then
  printf '%s\n' "herdr-agent-session: runner not executable: $runner" >&2
  exit 127
fi

runner_mode="${HERDR_AGENT_SESSION_MODE:-interactive}"
case "$runner_mode" in
  interactive|oneshot) ;;
  *)
    printf '%s\n' "herdr-agent-session: HERDR_AGENT_SESSION_MODE must be interactive or oneshot: $runner_mode" >&2
    exit 65
    ;;
esac

split="${HERDR_AGENT_SPLIT:-right}"

case "$split" in
  right|down) ;;
  *)
    printf '%s\n' "herdr-agent-session: HERDR_AGENT_SPLIT must be right or down: $split" >&2
    exit 65
    ;;
esac

focus="${HERDR_AGENT_FOCUS:-1}"
case "$focus" in
  1|true|yes)
    focus_flag="--focus"
    ;;
  0|false|no)
    focus_flag="--no-focus"
    ;;
  *)
    printf '%s\n' "herdr-agent-session: HERDR_AGENT_FOCUS must be 1 or 0: $focus" >&2
    exit 65
    ;;
esac

if [ "$reuse" != "never" ] && herdr agent get "$agent_name" >/dev/null 2>&1; then
  if herdr agent wait "$agent_name" --status idle --timeout "${HERDR_AGENT_REUSE_WAIT_MS:-1000}" >/dev/null 2>&1; then
    reuse_prompt=$(printf '[herdr-agent reuse]\nrole=%s\ncontext=%s\n\n%s' "$role" "$context_key" "$task_prompt")
    herdr agent send "$agent_name" "$reuse_prompt"
    if [ "$focus_flag" = "--focus" ]; then
      herdr agent focus "$agent_name" >/dev/null 2>&1 || true
    fi
    exit 0
  fi

  if [ "$reuse" = "require" ]; then
    printf '%s\n' "herdr-agent-session: matching agent exists but is not idle: $agent_name" >&2
    exit 69
  fi

  agent_name="${agent_name}-$(date +%H%M%S)"
elif [ "$reuse" = "require" ]; then
  printf '%s\n' "herdr-agent-session: matching reusable agent not found: $agent_name" >&2
  exit 69
fi

if [ "${HERDR_AGENT_SESSION_DRY_RUN:-0}" = "1" ]; then
  printf 'ROLE=%s\n' "$role"
  printf 'BACKEND=%s\n' "$backend_name"
  printf 'MODEL=%s\n' "$model_name"
  printf 'RUNNER_MODE=%s\n' "$runner_mode"
  printf 'AGENT_NAME=%s\n' "$agent_name"
  printf 'REPO_ROOT=%s\n' "$repo_root"
  printf 'RUNNER=%s\n' "$runner"
  printf 'REUSE=%s\n' "$reuse"
  exit 0
fi

exec herdr agent start "$agent_name" \
  --cwd "$repo_root" \
  --split "$split" \
  --env "HERDR_AGENT_MODE=$runner_mode" \
  "$focus_flag" \
  -- "$runner" "$role" "$task_prompt"
```

- [ ] **Step 2: Make the launcher executable**

Run:

```sh
chmod +x .agents/skills/using-herdr-agents/scripts/herdr-agent-session
```

Expected: command exits 0.

- [ ] **Step 3: Verify shell syntax**

Run:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent-session
```

Expected: no output and exit 0.

- [ ] **Step 4: Verify launcher argument validation without starting Herdr**

Run:

```sh
.agents/skills/using-herdr-agents/scripts/herdr-agent-session invalid "task" >/tmp/herdr-agent-session.out 2>/tmp/herdr-agent-session.err; printf '%s\n' "$?"
```

Expected output:

```text
64
```

Expected stderr contains:

```text
usage: herdr-agent-session <scout|coder|auditor|advisor> <task prompt>
```

- [ ] **Step 5: Verify session reuse option validation without starting Herdr**

Run:

```sh
HERDR_AGENT_REUSE=bad .agents/skills/using-herdr-agents/scripts/herdr-agent-session scout "task" >/tmp/herdr-agent-session-reuse.out 2>/tmp/herdr-agent-session-reuse.err; printf '%s\n' "$?"
```

Expected output:

```text
65
```

Expected stderr contains:

```text
HERDR_AGENT_REUSE must be auto, never, or require
```

---

### Task 5: Add Dry-Run Regression Tests

**Files:**
- Create: `tests/herdr-agent.sh`

- [ ] **Step 1: Create the shell test**

Create `tests/herdr-agent.sh` with:

```sh
#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
SCRIPT="$ROOT_DIR/.agents/skills/using-herdr-agents/scripts/herdr-agent"
PROMPT_DIR="$ROOT_DIR/.agents/skills/using-herdr-agents/prompts"

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

scout_output=$(run_dry scout "find files")
assert_contains "$scout_output" "ROLE=scout"
assert_contains "$scout_output" "BACKEND=opencode"
assert_contains "$scout_output" "MODEL=opencode-go/deepseek-v4-flash"
assert_contains "$scout_output" "OPENCODE_AGENT=scout_v2"

cline_scout_output=$(HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PROMPT_DIR" HERDR_AGENT_SCOUT_BACKEND=cline "$SCRIPT" scout "find files")
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

advisor_output=$(HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PROMPT_DIR" HERDR_AGENT_ADVISOR_THINKING=xhigh "$SCRIPT" advisor "decide")
assert_contains "$advisor_output" "ROLE=advisor"
assert_contains "$advisor_output" "BACKEND=codex"
assert_contains "$advisor_output" "MODEL=gpt-5.5"
assert_contains "$advisor_output" "THINKING=xhigh"

if HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_PROMPT_DIR="$PROMPT_DIR" HERDR_AGENT_ADVISOR_THINKING=medium "$SCRIPT" advisor "bad" >/tmp/herdr-agent-test.out 2>/tmp/herdr-agent-test.err; then
  printf '%s\n' "advisor accepted invalid thinking" >&2
  exit 1
fi

if ! grep -F "advisor thinking must be high or xhigh" /tmp/herdr-agent-test.err >/dev/null; then
  printf '%s\n' "invalid thinking error message was not clear" >&2
  cat /tmp/herdr-agent-test.err >&2
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

printf '%s\n' "PASS: herdr-agent"
```

- [ ] **Step 2: Make the test executable**

Run:

```sh
chmod +x tests/herdr-agent.sh
```

Expected: command exits 0.

- [ ] **Step 3: Run the test**

Run:

```sh
sh tests/herdr-agent.sh
```

Expected output:

```text
PASS: herdr-agent
```

- [ ] **Step 4: Run syntax checks**

Run:

```sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent-session
sh -n tests/herdr-agent.sh
```

Expected: no output and exit 0 for all commands.

---

### Task 6: Document Symlinks and Usage

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add configuration file entry**

In `README.md`, under `## Configuration Files`, after the existing `### Herdr` section, add:

```md
### Herdr Agent Prompts

- **Herdr Agent Prompts**: [`.agents/skills/using-herdr-agents/prompts`](.agents/skills/using-herdr-agents/prompts)
```

- [ ] **Step 2: Add usage symlinks**

In the main `Usage` shell block, after the Herdr config symlink lines, add:

```sh
sh .agents/skills/using-herdr-agents/scripts/install
```

- [ ] **Step 3: Add usage section**

After the `### Herdr` configuration entry or near the existing Cline/OpenCode sections, add:

```md
### Herdr Multi-Agent System

Codex remains the Planner/Judge. Herdr launches specialist worker panes only when they are useful.

| Role | Harness | Model | Use |
|------|---------|-------|-----|
| Scout | OpenCode Go by default, Cline Pass fallback | `opencode-go/deepseek-v4-flash` or `deepseek-v4-flash` | read-only repository exploration |
| Coder | Agy | `Gemini 3.5 Flash (Medium)` | scoped implementation and validation |
| Auditor | Agy | `Gemini 3.5 Flash (Medium)` | read-only diff or artifact review |
| Advisor | Codex | `gpt-5.5` with `high` or `xhigh` reasoning | rare failure-loop or architecture judgment |

Use dry-run first when checking routing without spending model quota:

```sh
HERDR_AGENT_DRY_RUN=1 herdr-agent scout "find the relevant files for ..."
HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_SCOUT_BACKEND=cline herdr-agent scout "find the relevant files for ..."
HERDR_AGENT_DRY_RUN=1 herdr-agent coder "implement the planned change ..."
HERDR_AGENT_DRY_RUN=1 herdr-agent auditor "review the current diff ..."
HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_ADVISOR_THINKING=xhigh herdr-agent advisor "decide the next approach ..."
```

Launch real workers in Herdr panes after the installer has exposed `herdr-agent` and `herdr-agent-session` on PATH. Use a stable `HERDR_AGENT_CONTEXT_KEY` when continuing the same feature or investigation so an idle matching agent session can be reused. Use `HERDR_AGENT_REUSE=never` when fresh context is more important than startup overhead.
`herdr-agent-session` defaults to interactive/TUI mode so the pane remains available for follow-up prompts. Use `HERDR_AGENT_SESSION_MODE=oneshot` only when the worker should run once and exit.

```sh
HERDR_AGENT_CONTEXT_KEY=herdr-multi-agent herdr-agent-session scout "find the relevant files for ..."
HERDR_AGENT_CONTEXT_KEY=herdr-multi-agent HERDR_AGENT_SCOUT_BACKEND=cline herdr-agent-session scout "find the relevant files for ..."
HERDR_AGENT_CONTEXT_KEY=herdr-multi-agent herdr-agent-session coder "implement the planned change ..."
HERDR_AGENT_CONTEXT_KEY=herdr-multi-agent herdr-agent-session auditor "review the current diff ..."
HERDR_AGENT_CONTEXT_KEY=herdr-multi-agent HERDR_AGENT_ADVISOR_THINKING=xhigh herdr-agent-session advisor "decide the next approach ..."
HERDR_AGENT_REUSE=never herdr-agent-session auditor "review this with fresh context ..."
HERDR_AGENT_SESSION_MODE=oneshot herdr-agent-session scout "run once and close when done ..."
```

The parent Codex session decides whether worker reports are accepted, rejected, or escalated.
```

- [ ] **Step 4: Verify README references**

Run:

```sh
rg -n "Herdr Multi-Agent|herdr-agent|scout_v2|HERDR_AGENT_CONTEXT_KEY|HERDR_AGENT_REUSE|Gemini 3.5 Flash|deepseek-v4-flash" README.md
```

Expected: output contains the new section, symlink commands, model mapping, context-keyed reuse examples, and usage examples.

---

### Task 7: Validate Runtime Surfaces Without Spending Quota

**Files:**
- No file changes.

- [ ] **Step 1: Check model availability**

Run:

```sh
opencode models opencode-go | rg '^opencode-go/deepseek-v4-flash$'
agy models | rg '^Gemini 3\.5 Flash \(Medium\)$'
codex exec --help | rg -- '--model|-m'
cline --help | rg -- '--provider|--model|--system|--cwd|--thinking'
```

Expected: all commands exit 0. OpenCode and Agy print matching model lines; Codex and Cline print the required CLI options.

- [ ] **Step 2: Check OpenCode agent registration**

Run:

```sh
mise exec -- opencode agent list | rg 'scout_v2'
```

Expected: output contains `scout_v2`.

- [ ] **Step 3: Check Herdr launcher availability**

Run:

```sh
herdr agent --help | rg 'agent (start|get|send|wait)'
```

Expected: output contains `herdr agent start <name>`, `herdr agent get <target>`, `herdr agent send <target> <text>`, and `herdr agent wait <target> --status`.

- [ ] **Step 4: Check dry-run output through the symlinked command**

After the installer exposes `herdr-agent` on PATH, run:

```sh
HERDR_AGENT_DRY_RUN=1 herdr-agent scout "find files"
HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_SCOUT_BACKEND=cline herdr-agent scout "find files"
HERDR_AGENT_DRY_RUN=1 herdr-agent coder "make one scoped edit"
HERDR_AGENT_DRY_RUN=1 herdr-agent auditor "review diff"
HERDR_AGENT_DRY_RUN=1 HERDR_AGENT_ADVISOR_THINKING=high herdr-agent advisor "decide next action"
```

Expected: each command prints the intended role, backend, and model without invoking a model. The Cline Scout dry-run prints `BACKEND=cline`, `MODEL=deepseek-v4-flash`, and `CLINE_PROVIDER=cline-pass`.

- [ ] **Step 5: Check session reuse naming through the launcher without reusing a live agent**

Run:

```sh
HERDR_AGENT_REUSE=require HERDR_AGENT_CONTEXT_KEY=herdr-multi-agent herdr-agent-session scout "find files" >/tmp/herdr-agent-require.out 2>/tmp/herdr-agent-require.err; printf '%s\n' "$?"
```

Expected output:

```text
69
```

Expected stderr contains:

```text
matching reusable agent not found: herdr-scout-2630320116-opencode-opencode-go-deepseek-v4-flash-herdr-multi-agent
```

---

### Task 8: Final Diff Review

**Files:**
- Review all changed files from Tasks 1-7.

- [ ] **Step 1: Show scoped diff**

Run:

```sh
git diff -- .agents/skills/using-herdr-agents/prompts .config/opencode/opencode.json .agents/skills/using-herdr-agents/scripts/herdr-agent .agents/skills/using-herdr-agents/scripts/herdr-agent-session tests/herdr-agent.sh README.md
```

Expected: diff includes only the planned prompt files, new scripts, new test, OpenCode `scout_v2`, the Cline `scout_v2` runner route, context-keyed session reuse, and README documentation.

- [ ] **Step 2: Check for accidental changes to existing OpenCode agents**

Run:

```sh
git diff -- .config/opencode/opencode.json | rg '"(explorer|implementer|reviewer|orchestrator|oracle)"|scout_v2'
```

Expected: diff shows `scout_v2`; existing agent names may appear only as surrounding context.

- [ ] **Step 3: Run all local validation commands**

Run:

```sh
sh tests/herdr-agent.sh
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent
sh -n .agents/skills/using-herdr-agents/scripts/herdr-agent-session
sh -n tests/herdr-agent.sh
opencode models opencode-go | rg '^opencode-go/deepseek-v4-flash$'
agy models | rg '^Gemini 3\.5 Flash \(Medium\)$'
cline --help | rg -- '--provider|--model|--system|--cwd|--thinking'
herdr agent --help | rg 'agent (start|get|send|wait)'
```

Expected: the test prints `PASS: herdr-agent`; all other commands exit 0.

---

## Self-Review

- Spec coverage: The plan covers prompt files, role mapping, Herdr launch, context-keyed session reuse, OpenCode `scout_v2`, Cline `scout_v2` fallback routing, Agy coder/auditor, Codex advisor, README, symlinks, and dry-run validation.
- Placeholder scan: The plan contains concrete file paths, prompt contents, script contents, commands, and expected outputs.
- Type and name consistency: Role names are `scout`, `coder`, `auditor`, `advisor`; OpenCode agent name is `scout_v2`; Cline Scout uses `HERDR_AGENT_SCOUT_BACKEND=cline`, provider `cline-pass`, and model `deepseek-v4-flash`; reusable Herdr session names use `herdr-<role>-<repo-key>-<backend-model>-<context>`; model strings match local CLI output or are guarded by env overrides.
- Scope control: Existing OpenCode `explorer`, `implementer`, `reviewer`, `orchestrator`, and `oracle` are explicitly preserved.
