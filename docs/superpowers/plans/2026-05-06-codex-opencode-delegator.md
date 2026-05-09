# Codex OpenCode Delegator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure Codex to conserve GPT-5.5 usage by delegating implementation, codebase research, test fixing, diff summarization, refactoring, and docs work to OpenCode through `mise exec -- opencode run`, while keeping Codex responsible for orchestration, review, and next-step decisions.

**Architecture:** Codex runs as the parent orchestrator on GPT-5.5. A lightweight Codex delegator agent invokes a local wrapper script, and the wrapper runs OpenCode non-interactively with JSON output. OpenCode performs role-specific work through Kimi 2.6 CLI worker agents, while raw OpenCode JSON stays in repo-external log files. Codex reads only the compact wrapper report first, then selectively inspects raw logs or targeted `git diff` when needed.

**Tech Stack:** Codex CLI/Desktop config, OpenCode managed by mise, bash shell script, JSONL logs, git diff-based review.

---

## File Structure

- Create: `~/.codex/bin/codex-opencode-worker`
  - Single entrypoint used by Codex to invoke OpenCode.
  - Always calls `mise exec -- opencode run`.
  - Selects an OpenCode worker role through `OPENCODE_WORKER_AGENT`.
  - Writes raw JSON events outside the repository under `~/.codex/opencode-runs/<repo-slug>/<timestamp>.jsonl`.
  - Prints only a compact machine-readable report to stdout so GPT-5.5 does not ingest full OpenCode event logs.

- Create: `.codex/agents/opencode-delegator.toml`
  - Defines the Codex sub-agent that delegates implementation to `~/.codex/bin/codex-opencode-worker`.
  - Uses a lower-cost Codex model because this agent should not do deep implementation reasoning itself.
  - Restricts the sub-agent instructions to delegation, log reading, and diff summarization.

- Create: `.codex/agents/opencode-delegator-prompt.md`
  - Fallback prompt for the built-in Codex `worker` agent when custom `.codex/agents/*.toml` discovery is unavailable.
  - Contains the same delegation behavior as `opencode-delegator.toml`.

- Modify: `.agents/AGENTS.md`
  - Adds a short operating rule for Codex: use GPT-5.5 for orchestration and review, use OpenCode for implementation-heavy work.
  - Documents that OpenCode must be invoked through `mise exec -- opencode`.

- Modify: `/Users/haru256/.config/opencode/opencode.json`
  - Adds OpenCode worker agents: `codebase-researcher`, `implementer`, `test-fixer`, `diff-summarizer`, `refactor-worker`, and `docs-worker`.
  - Configures these agents as CLI-invoked `primary` agents because the wrapper calls them directly with `opencode run --agent <role>`.
  - Keeps destructive commands denied.
  - Uses a configurable implementation model through direct CLI `--model`; the config agent focuses on permissions and behavior.

- Verify only: `.config/mise/config.toml`
  - Already declares `opencode = "latest"`.
  - No change is planned unless `mise exec -- opencode --version` fails.

## Execution Rules

- Do not commit unless the user explicitly asks. This repository's AGENTS instructions forbid implicit commits.
- Do not use `--dangerously-skip-permissions` in the default wrapper.
- Use `OPENCODE_WORKER_MODEL` to switch implementation models without editing the wrapper.
- Default implementation model: `opencode-go/kimi-k2.6`.
- Verify `opencode-go/kimi-k2.6` is available and can complete a no-edit run before using the delegation flow.
- Use `OPENCODE_WORKER_AGENT` to select one of `codebase-researcher`, `implementer`, `test-fixer`, `diff-summarizer`, `refactor-worker`, or `docs-worker`.
- Default worker agent: `implementer`.
- Keep architecture, planning, final review, and merge-readiness decisions in Codex GPT-5.5.
- Codex parent must inspect `git diff` after every OpenCode run before deciding the next step.
- Codex parent must not read full OpenCode JSON logs by default. It should read the compact wrapper stdout and `git diff --stat` first, then inspect raw logs only for failures or ambiguity.

## Worker Role Policy

- `codebase-researcher`: read-only exploration before implementation. It identifies relevant files, existing patterns, test commands, and risks. It must not edit files.
- `implementer`: normal implementation worker. It edits files, runs relevant verification, and reports changes.
- `test-fixer`: failure-driven repair worker. It receives failing command output and changes only what is needed to make the failure pass.
- `diff-summarizer`: read-only change summarizer. It reads `git diff` and logs, then reports what changed, why it matters, and review focus areas. It must not edit files.
- `refactor-worker`: mechanical refactor worker. It performs scoped renames, moves, splits, or formatting-preserving structural changes after Codex defines the boundaries.
- `docs-worker`: documentation worker. It updates README, AGENTS, setup notes, or usage docs based on an already-decided implementation change.

### Task 1: Verify OpenCode Through mise

**Files:**
- Verify: `.config/mise/config.toml`
- No file changes

- [ ] **Step 1: Confirm mise resolves opencode**

Run:

```bash
mise which opencode
```

Expected:

```text
/Users/haru256/.local/share/mise/installs/opencode/<installed-version>/opencode
```

- [ ] **Step 2: Confirm OpenCode can run through mise**

Run:

```bash
mise exec -- opencode --version
```

Expected:

```text
1.14.39
```

or an equivalent OpenCode version string from the installed `opencode` binary.

- [ ] **Step 3: Confirm non-interactive run options**

Run:

```bash
mise exec -- opencode run --help | rg -- '--model|--agent|--format|--dir|--variant'
```

Expected output contains all of these option names:

```text
--model
--agent
--format
--dir
--variant
```

- [ ] **Step 4: Confirm the default Kimi 2.6 model is listed**

Run:

```bash
mise exec -- opencode models opencode-go | rg 'kimi-k2.6|kimi'
```

Expected output includes `kimi-k2.6`. If the provider name or model id differs, record the exact `provider/model` value and use it as `OPENCODE_WORKER_MODEL` in later tasks.

- [ ] **Step 5: Confirm the default Kimi 2.6 model can complete a no-edit run**

Run:

```bash
mise exec -- opencode run \
  --model "${OPENCODE_WORKER_MODEL:-opencode-go/kimi-k2.6}" \
  --format json \
  --dir "$PWD" \
  "Reply with exactly: kimi model available. Do not edit files." \
  > /tmp/codex-opencode-kimi-smoke.jsonl
```

Expected: command exits with status `0`.

- [ ] **Step 6: Confirm the no-edit model smoke test did not change the repository**

Run:

```bash
git status --short
```

Expected: no source changes from the model smoke test. Existing planned changes from this plan document are acceptable.

### Task 2: Add the OpenCode Worker Wrapper

**Files:**
- Create: `~/.codex/bin/codex-opencode-worker`
- Create runtime directory at execution time: `~/.codex/opencode-runs/<repo-slug>/`

- [ ] **Step 1: Create the script**

Create `~/.codex/bin/codex-opencode-worker` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "usage: ~/.codex/bin/codex-opencode-worker <task prompt>" >&2
  exit 64
fi

if ! command -v mise >/dev/null 2>&1; then
  echo "mise is required because opencode is managed by mise" >&2
  exit 127
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

model="${OPENCODE_WORKER_MODEL:-opencode-go/kimi-k2.6}"
agent="${OPENCODE_WORKER_AGENT:-implementer}"
variant="${OPENCODE_WORKER_VARIANT:-}"
repo_slug="$(printf '%s' "$repo_root" | sed 's#^/##; s#[^A-Za-z0-9._-]#-#g')"
run_dir="${OPENCODE_WORKER_LOG_DIR:-$HOME/.codex/opencode-runs/$repo_slug}"
mkdir -p "$run_dir"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$run_dir/$timestamp.jsonl"
stderr_file="$run_dir/$timestamp.stderr.log"
report_file="$run_dir/$timestamp.report.txt"

prompt="$*"

case "$agent" in
  codebase-researcher)
    role_instructions="You are a read-only codebase research worker called by Codex. Identify relevant files, existing patterns, likely tests, and implementation risks. Do not edit files."
    ;;
  implementer)
    role_instructions="You are an implementation worker called by Codex. Make narrow requested changes, run relevant verification, and preserve unrelated user changes."
    ;;
  test-fixer)
    role_instructions="You are a failure-driven test fixer called by Codex. Use the provided failing command output, change only what is needed to make the failure pass, and rerun the failing command."
    ;;
  diff-summarizer)
    role_instructions="You are a read-only diff summarizer called by Codex. Inspect git diff and relevant logs, summarize the change, and identify review focus areas. Do not edit files."
    ;;
  refactor-worker)
    role_instructions="You are a scoped refactor worker called by Codex. Perform only the requested mechanical refactor, preserve behavior, and run relevant verification."
    ;;
  docs-worker)
    role_instructions="You are a documentation worker called by Codex. Update only requested documentation files based on the provided implementation context, and preserve existing style."
    ;;
  *)
    echo "unknown OPENCODE_WORKER_AGENT: $agent" >&2
    echo "expected one of: codebase-researcher, implementer, test-fixer, diff-summarizer, refactor-worker, docs-worker" >&2
    exit 65
    ;;
esac

worker_prompt="$(cat <<EOF
$role_instructions

Shared rules:
- Make only the changes requested by Codex.
- Preserve unrelated user changes.
- Run the most relevant verification command available for changed files when the role edits files.
- Do not commit, push, tag, release, merge, rebase, or reset git history.
- Do not run destructive commands.
- End with this exact report format:
STATUS: success | partial | failed
ROLE: $agent
CHANGED_FILES:
TESTS_RUN:
SUMMARY:
RISKS:
NEXT_RECOMMENDATION:

Task:
$prompt
EOF
)"

cmd=(mise exec -- opencode run --model "$model" --agent "$agent" --format json --dir "$repo_root")
if [[ -n "$variant" ]]; then
  cmd+=(--variant "$variant")
fi

set +e
"${cmd[@]}" "$worker_prompt" >"$log_file" 2>"$stderr_file"
status="$?"
set -e

{
  echo "OPENCODE_EXIT_STATUS=$status"
  echo "OPENCODE_LOG_FILE=$log_file"
  echo "OPENCODE_STDERR_FILE=$stderr_file"
  echo "OPENCODE_REPORT_FILE=$report_file"
  echo "OPENCODE_MODEL=$model"
  echo "OPENCODE_AGENT=$agent"
  echo "FINAL_REPORT_LINES_BEGIN"
  grep -nE "STATUS:|ROLE:|CHANGED_FILES:|TESTS_RUN:|SUMMARY:|RISKS:|NEXT_RECOMMENDATION:" "$log_file" || true
  echo "FINAL_REPORT_LINES_END"
  echo "GIT_DIFF_STAT_BEGIN"
  git diff --stat
  echo "GIT_DIFF_STAT_END"
} >"$report_file"

cat "$report_file"

exit "$status"
```

- [ ] **Step 2: Make the script executable**

Run:

```bash
chmod +x ~/.codex/bin/codex-opencode-worker
```

Expected:

```bash
test -x ~/.codex/bin/codex-opencode-worker
```

exits with status `0`.

- [ ] **Step 3: Verify usage failure is explicit**

Run:

```bash
~/.codex/bin/codex-opencode-worker
```

Expected:

```text
usage: ~/.codex/bin/codex-opencode-worker <task prompt>
```

and exit status `64`.

- [ ] **Step 4: Verify the wrapper stores logs outside the repository**

Run:

```bash
rg -n 'HOME/.codex/opencode-runs|OPENCODE_WORKER_LOG_DIR|tee' ~/.codex/bin/codex-opencode-worker
```

Expected:

```text
HOME/.codex/opencode-runs
OPENCODE_WORKER_LOG_DIR
```

and no `tee` match. This confirms raw OpenCode JSON is written to a log file instead of streamed into Codex stdout.

### Task 3: Add the Codex Delegator Agent

**Files:**
- Create: `.codex/agents/opencode-delegator.toml`
- Create: `.codex/agents/opencode-delegator-prompt.md`

- [ ] **Step 1: Create the Codex agent directory**

Run:

```bash
mkdir -p .codex/agents
```

Expected: `.codex/agents` exists.

- [ ] **Step 2: Create the delegator agent config**

Create `.codex/agents/opencode-delegator.toml` with this exact content:

```toml
name = "opencode-delegator"
description = "Delegates implementation-heavy work to OpenCode through mise-managed opencode CLI, then summarizes logs and git diff for the Codex parent."
model = "gpt-5.4-mini"
model_reasoning_effort = "low"
sandbox_mode = "danger-full-access"

developer_instructions = """
You are a lightweight delegation agent. Your purpose is to conserve GPT-5.5 tokens by sending implementation-heavy work to OpenCode.

When given an implementation task:
1. Select the correct OpenCode worker role:
   - `codebase-researcher` for read-only exploration before implementation.
   - `implementer` for normal code changes.
   - `test-fixer` for fixing a known failing command.
   - `diff-summarizer` for read-only review of a large diff.
   - `refactor-worker` for scoped mechanical refactors.
   - `docs-worker` for documentation changes.
2. Convert the request into a concise, concrete worker prompt.
3. Run `OPENCODE_WORKER_AGENT="<role>" ~/.codex/bin/codex-opencode-worker "<prompt>"` from the repository root.
4. Read the command output, the reported OPENCODE_LOG_FILE, and `git diff --stat`.
5. If needed, inspect `git diff` for changed files.
6. Report back to the parent with:
   - OpenCode exit status
   - OpenCode log file path
   - worker role
   - changed files
   - tests run
   - risks
   - recommended next Codex action

Do not perform broad implementation yourself. Do not commit, push, tag, release, merge, rebase, reset, or revert user changes.
"""
```

- [ ] **Step 3: Verify the file is valid TOML**

Run:

```bash
mise exec -- python - <<'PY'
import tomllib
from pathlib import Path
path = Path(".codex/agents/opencode-delegator.toml")
tomllib.loads(path.read_text())
print("valid toml")
PY
```

Expected:

```text
valid toml
```

- [ ] **Step 4: Create the built-in worker fallback prompt**

Create `.codex/agents/opencode-delegator-prompt.md` with this exact content:

```markdown
# OpenCode Delegator Fallback Prompt

You are a lightweight delegation worker. Your purpose is to conserve GPT-5.5 tokens by sending implementation-heavy work to OpenCode.

When given a task:

1. Select the correct OpenCode worker role:
   - `codebase-researcher` for read-only exploration before implementation.
   - `implementer` for normal code changes.
   - `test-fixer` for fixing a known failing command.
   - `diff-summarizer` for read-only review of a large diff.
   - `refactor-worker` for scoped mechanical refactors.
   - `docs-worker` for documentation changes.
2. Convert the request into a concise, concrete worker prompt.
3. Run `OPENCODE_WORKER_AGENT="<role>" ~/.codex/bin/codex-opencode-worker "<prompt>"` from the repository root.
4. Read only the compact wrapper stdout first.
5. Read the raw `OPENCODE_LOG_FILE` only when the wrapper report is ambiguous or the command failed.
6. Inspect `git diff --stat`, and inspect targeted `git diff` only for files relevant to the task.
7. Report back to the Codex parent with:
   - OpenCode exit status
   - OpenCode log file path
   - worker role
   - changed files
   - tests run
   - risks
   - recommended next Codex action

Do not perform broad implementation yourself. Do not commit, push, tag, release, merge, rebase, reset, or revert user changes.
```

- [ ] **Step 5: Verify Codex custom delegator discovery or record fallback mode**

Run:

```bash
codex --cd "$PWD" debug prompt-input "Use opencode-delegator to report its role. Do not edit files." | rg 'opencode-delegator|opencode-delegator-prompt|spawn_agent|worker' || true
```

Expected: one of these outcomes is recorded in the implementation summary:

```text
custom-agent-available
```

if Codex exposes `.codex/agents/opencode-delegator.toml` to the current environment, or:

```text
fallback-to-built-in-worker
```

if the current Codex environment cannot directly spawn custom agent TOML files. In fallback mode, dispatch the built-in `worker` agent and include the content of `.codex/agents/opencode-delegator-prompt.md` in the worker task prompt.

### Task 4: Add the OpenCode Worker Agents

**Files:**
- Modify: `/Users/haru256/.config/opencode/opencode.json`

- [ ] **Step 1: Back up the current OpenCode config outside git**

Run:

```bash
cp /Users/haru256/.config/opencode/opencode.json /Users/haru256/.config/opencode/opencode.json.before-codex-opencode-workers
```

Expected: backup file exists.

- [ ] **Step 2: Add all worker agents under the top-level `agent` object**

Modify `/Users/haru256/.config/opencode/opencode.json` so the top-level `agent` object contains these entries alongside existing agents:

These OpenCode agents intentionally use `"mode": "primary"` because the wrapper invokes each role directly with `opencode run --agent <role>`. The "sub-agent" in this design is the Codex delegator. OpenCode's own `"mode": "subagent"` is reserved for agents that are called from inside an OpenCode primary session, which is not the default wrapper path.

```jsonc
"codebase-researcher": {
  "description": "Read-only codebase research worker called by Codex before implementation.",
  "mode": "primary",
  "permission": {
    "edit": "deny",
    "read": "allow",
    "bash": {
      "*": "ask",
      "pwd": "allow",
      "ls *": "allow",
      "find *": "allow",
      "rg *": "allow",
      "grep *": "allow",
      "sed -n *": "allow",
      "cat *": "allow",
      "git status*": "allow",
      "git diff*": "allow",
      "git log*": "allow",
      "mise exec -- * --help*": "allow"
    },
    "external_directory": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "question": "allow",
    "codesearch": "allow",
    "skill": "allow",
    "todowrite": "allow",
    "grep": "allow",
    "lsp": "allow",
    "task": "allow",
    "glob": "allow",
    "list": "allow"
  },
  "prompt": "You are a read-only codebase research worker called by Codex. Do not edit files. Identify relevant files, existing patterns, likely tests, dependencies, and implementation risks. End every run with STATUS, ROLE, CHANGED_FILES, TESTS_RUN, SUMMARY, RISKS, and NEXT_RECOMMENDATION."
},
"implementer": {
  "description": "Implementation worker called by Codex through ~/.codex/bin/codex-opencode-worker.",
  "mode": "primary",
  "permission": {
    "edit": "allow",
    "read": "allow",
    "bash": {
      "*": "allow",
      "rm -rf *": "deny",
      "sudo *": "ask",
      "git commit*": "deny",
      "git push*": "deny",
      "git tag*": "deny",
      "git merge*": "deny",
      "git rebase*": "deny",
      "git reset*": "deny"
    },
    "external_directory": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "question": "allow",
    "codesearch": "allow",
    "skill": "allow",
    "todowrite": "allow",
    "grep": "allow",
    "lsp": "allow",
    "task": "allow",
    "glob": "allow",
    "list": "allow"
  },
  "prompt": "You are an implementation worker called by Codex. Make narrow, requested changes only. Preserve unrelated user changes. Run relevant verification. Never commit, push, tag, release, merge, rebase, reset, or revert user work. End every run with STATUS, ROLE, CHANGED_FILES, TESTS_RUN, SUMMARY, RISKS, and NEXT_RECOMMENDATION."
},
"test-fixer": {
  "description": "Failure-driven test fixer called by Codex when a command fails.",
  "mode": "primary",
  "permission": {
    "edit": "allow",
    "read": "allow",
    "bash": {
      "*": "allow",
      "rm -rf *": "deny",
      "sudo *": "ask",
      "git commit*": "deny",
      "git push*": "deny",
      "git tag*": "deny",
      "git merge*": "deny",
      "git rebase*": "deny",
      "git reset*": "deny"
    },
    "external_directory": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "question": "allow",
    "codesearch": "allow",
    "skill": "allow",
    "todowrite": "allow",
    "grep": "allow",
    "lsp": "allow",
    "task": "allow",
    "glob": "allow",
    "list": "allow"
  },
  "prompt": "You are a test fixer called by Codex. Use the provided failing command and output. Change only what is needed to make that failure pass. Rerun the failing command. Never commit, push, tag, release, merge, rebase, reset, or revert user work. End every run with STATUS, ROLE, CHANGED_FILES, TESTS_RUN, SUMMARY, RISKS, and NEXT_RECOMMENDATION."
},
"diff-summarizer": {
  "description": "Read-only diff summarizer called by Codex before final review.",
  "mode": "primary",
  "permission": {
    "edit": "deny",
    "read": "allow",
    "bash": {
      "*": "ask",
      "git status*": "allow",
      "git diff*": "allow",
      "git log*": "allow",
      "rg *": "allow",
      "grep *": "allow",
      "sed -n *": "allow",
      "cat *": "allow"
    },
    "external_directory": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "question": "allow",
    "codesearch": "allow",
    "skill": "allow",
    "todowrite": "allow",
    "grep": "allow",
    "lsp": "allow",
    "task": "allow",
    "glob": "allow",
    "list": "allow"
  },
  "prompt": "You are a read-only diff summarizer called by Codex. Do not edit files. Summarize git diff, call out behavior changes, test coverage, review focus areas, and residual risks. End every run with STATUS, ROLE, CHANGED_FILES, TESTS_RUN, SUMMARY, RISKS, and NEXT_RECOMMENDATION."
},
"refactor-worker": {
  "description": "Scoped mechanical refactor worker called by Codex.",
  "mode": "primary",
  "permission": {
    "edit": "allow",
    "read": "allow",
    "bash": {
      "*": "allow",
      "rm -rf *": "deny",
      "sudo *": "ask",
      "git commit*": "deny",
      "git push*": "deny",
      "git tag*": "deny",
      "git merge*": "deny",
      "git rebase*": "deny",
      "git reset*": "deny"
    },
    "external_directory": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "question": "allow",
    "codesearch": "allow",
    "skill": "allow",
    "todowrite": "allow",
    "grep": "allow",
    "lsp": "allow",
    "task": "allow",
    "glob": "allow",
    "list": "allow"
  },
  "prompt": "You are a scoped refactor worker called by Codex. Perform only the requested mechanical refactor. Preserve behavior, naming intent, formatting style, and public interfaces unless Codex explicitly asks for a change. Run relevant verification. Never commit, push, tag, release, merge, rebase, reset, or revert user work. End every run with STATUS, ROLE, CHANGED_FILES, TESTS_RUN, SUMMARY, RISKS, and NEXT_RECOMMENDATION."
},
"docs-worker": {
  "description": "Documentation worker called by Codex after implementation decisions are made.",
  "mode": "primary",
  "permission": {
    "edit": "allow",
    "read": "allow",
    "bash": {
      "*": "allow",
      "rm -rf *": "deny",
      "sudo *": "ask",
      "git commit*": "deny",
      "git push*": "deny",
      "git tag*": "deny",
      "git merge*": "deny",
      "git rebase*": "deny",
      "git reset*": "deny"
    },
    "external_directory": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "question": "allow",
    "codesearch": "allow",
    "skill": "allow",
    "todowrite": "allow",
    "grep": "allow",
    "lsp": "allow",
    "task": "allow",
    "glob": "allow",
    "list": "allow"
  },
  "prompt": "You are a documentation worker called by Codex. Update only the requested documentation files. Match existing style and keep wording concise. Do not alter code unless Codex explicitly asks. Never commit, push, tag, release, merge, rebase, reset, or revert user work. End every run with STATUS, ROLE, CHANGED_FILES, TESTS_RUN, SUMMARY, RISKS, and NEXT_RECOMMENDATION."
}
```

- [ ] **Step 3: Validate OpenCode config still parses**

Run:

```bash
mise exec -- opencode agent list | rg 'codebase-researcher|implementer|test-fixer|diff-summarizer|refactor-worker|docs-worker'
```

Expected: command exits successfully and includes all six worker names:

```text
codebase-researcher
implementer
test-fixer
diff-summarizer
refactor-worker
docs-worker
```

### Task 5: Document Codex Parent Operating Rules

**Files:**
- Modify: `.agents/AGENTS.md`
  - This repository file is the source for the global Codex instructions because `~/.codex/AGENTS.md` is a symlink to `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md`.

- [ ] **Step 1: Add a Codex/OpenCode delegation section**

Append this section to `.agents/AGENTS.md`, which updates the global `~/.codex/AGENTS.md` through the symlink:

```markdown
---

## Codex / OpenCode 委譲運用

- GPT-5.5 を使う Codex は、要件整理・タスク分割・レビュー・統合判断を担当する
- 実装作業・テスト修正・反復的な編集は、可能な限り OpenCode worker に委譲する
- OpenCode は `mise` 管理のため、必ず `mise exec -- opencode` または `~/.codex/bin/codex-opencode-worker` 経由で呼び出す
- OpenCode worker の標準モデルは `OPENCODE_WORKER_MODEL` で切り替える。未指定時は `opencode-go/kimi-k2.6`
- OpenCode worker の役割は `OPENCODE_WORKER_AGENT` で切り替える。未指定時は `implementer`
- 利用可能な worker は `codebase-researcher`、`implementer`、`test-fixer`、`diff-summarizer`、`refactor-worker`、`docs-worker`
- 設計・計画・最終レビュー・統合判断は Codex が担当し、探索・編集・テスト修正・差分要約・機械的リファクタ・docs 更新は OpenCode worker に委譲する
- OpenCode 実行後、Codex は必ず `git diff --stat` と関連する `git diff` を読んでから次の行動を決める
- OpenCode worker も Codex も、明示的な依頼なしに commit・push・tag・release・merge・rebase・reset を行わない
```

- [ ] **Step 2: Verify there is only one delegation section**

Run:

```bash
rg -n "Codex / OpenCode 委譲運用" .agents/AGENTS.md
```

Expected: exactly one match.

- [ ] **Step 3: Verify the global symlink sees the same section**

Run:

```bash
readlink ~/.codex/AGENTS.md
rg -n "Codex / OpenCode 委譲運用|OPENCODE_WORKER_AGENT" ~/.codex/AGENTS.md
```

Expected:

```text
/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md
```

and the `rg` output shows the delegation section from the global AGENTS path.

### Task 6: Smoke Test Delegation With a No-Edit Task

**Files:**
- Runtime output: `~/.codex/opencode-runs/<repo-slug>/*.jsonl`
- No intended source changes

- [ ] **Step 1: Run a no-edit OpenCode task**

Run:

```bash
OPENCODE_WORKER_MODEL="${OPENCODE_WORKER_MODEL:-opencode-go/kimi-k2.6}" \
~/.codex/bin/codex-opencode-worker "Inspect this repository and report the purpose of .config/mise/config.toml. Do not edit files."
```

Expected:

```text
OPENCODE_EXIT_STATUS=0
OPENCODE_LOG_FILE=...
OPENCODE_STDERR_FILE=...
FINAL_REPORT_LINES_BEGIN
FINAL_REPORT_LINES_END
GIT_DIFF_STAT_BEGIN
GIT_DIFF_STAT_END
```

The diff stat should be empty.

- [ ] **Step 2: Confirm no source changes were made**

Run:

```bash
git status --short
```

Expected: only the planned implementation files from Tasks 2, 3, and 5 plus this plan file are present. No unexpected files are modified.

- [ ] **Step 3: Inspect the OpenCode log path**

Run the `OPENCODE_LOG_FILE` path from Step 1 through `wc`:

```bash
wc -l "$HOME"/.codex/opencode-runs/*/*.jsonl
```

Expected: at least one JSONL log has one or more lines.

### Task 7: Smoke Test Delegation With a Disposable Edit

**Files:**
- Temporary create: `.codex/opencode-smoke-test.txt`
- Runtime output: `~/.codex/opencode-runs/<repo-slug>/*.jsonl`

- [ ] **Step 1: Ask OpenCode to create a disposable file**

Run:

```bash
~/.codex/bin/codex-opencode-worker "Create .codex/opencode-smoke-test.txt containing exactly: opencode delegation smoke test"
```

Expected output includes:

```text
OPENCODE_EXIT_STATUS=0
GIT_DIFF_STAT_BEGIN
 .codex/opencode-smoke-test.txt | 1 +
GIT_DIFF_STAT_END
```

- [ ] **Step 2: Verify file content**

Run:

```bash
printf '%s\n' "opencode delegation smoke test" | diff -u - .codex/opencode-smoke-test.txt
```

Expected: no diff output and exit status `0`.

- [ ] **Step 3: Remove the disposable smoke file**

Run:

```bash
rm .codex/opencode-smoke-test.txt
```

Expected: file is removed. This is an explicit cleanup of a test artifact created by this task.

### Task 8: Smoke Test Worker Role Selection

**Files:**
- Runtime output: `~/.codex/opencode-runs/<repo-slug>/*.jsonl`
- No intended source changes

- [ ] **Step 1: Verify read-only codebase researcher**

Run:

```bash
OPENCODE_WORKER_AGENT=codebase-researcher \
~/.codex/bin/codex-opencode-worker "Identify the purpose of ~/.codex/bin/codex-opencode-worker and list the files it depends on. Do not edit files."
```

Expected output includes:

```text
OPENCODE_EXIT_STATUS=0
OPENCODE_AGENT=codebase-researcher
GIT_DIFF_STAT_BEGIN
GIT_DIFF_STAT_END
```

The diff stat should not include any file created by this step.

- [ ] **Step 2: Verify read-only diff summarizer**

Run:

```bash
OPENCODE_WORKER_AGENT=diff-summarizer \
~/.codex/bin/codex-opencode-worker "Summarize the current git diff and identify review focus areas. Do not edit files."
```

Expected output includes:

```text
OPENCODE_EXIT_STATUS=0
OPENCODE_AGENT=diff-summarizer
```

The diff stat after this command should be the same as before this command.

- [ ] **Step 3: Verify docs worker with disposable documentation**

Run:

```bash
OPENCODE_WORKER_AGENT=docs-worker \
~/.codex/bin/codex-opencode-worker "Create .codex/opencode-docs-worker-smoke.md containing exactly one Markdown heading: # docs worker smoke"
```

Expected output includes:

```text
OPENCODE_EXIT_STATUS=0
OPENCODE_AGENT=docs-worker
 .codex/opencode-docs-worker-smoke.md | 1 +
```

- [ ] **Step 4: Clean up disposable docs worker file**

Run:

```bash
rm .codex/opencode-docs-worker-smoke.md
```

Expected: file is removed. This is an explicit cleanup of a test artifact created by this task.

- [ ] **Step 5: Verify unknown worker names fail fast**

Run:

```bash
OPENCODE_WORKER_AGENT=unknown-worker ~/.codex/bin/codex-opencode-worker "This should not run."
```

Expected:

```text
unknown OPENCODE_WORKER_AGENT: unknown-worker
expected one of: codebase-researcher, implementer, test-fixer, diff-summarizer, refactor-worker, docs-worker
```

and exit status `65`.

### Task 9: Verify Codex Can Reason From Compact OpenCode Output

**Files:**
- Runtime output: `~/.codex/opencode-runs/<repo-slug>/*.jsonl`
- Runtime output: `~/.codex/opencode-runs/<repo-slug>/*.report.txt`
- No new source files

- [ ] **Step 1: Find the newest compact OpenCode report**

Run:

```bash
latest_report="$(ls -t "$HOME"/.codex/opencode-runs/*/*.report.txt | head -n 1)"
printf '%s\n' "$latest_report"
```

Expected: prints a path under `~/.codex/opencode-runs/`.

- [ ] **Step 2: Confirm Codex can read the compact report without full raw JSON**

Run:

```bash
latest_report="$(ls -t "$HOME"/.codex/opencode-runs/*/*.report.txt | head -n 1)"
sed -n '1,120p' "$latest_report"
```

Expected: output shows only wrapper metadata, final report label matches, and `git diff --stat`. It should not dump the full raw OpenCode JSON event stream.

- [ ] **Step 3: Confirm the raw JSON log remains available for targeted debugging**

Run:

```bash
latest_report="$(ls -t "$HOME"/.codex/opencode-runs/*/*.report.txt | head -n 1)"
raw_log="$(sed -n 's/^OPENCODE_LOG_FILE=//p' "$latest_report")"
test -s "$raw_log"
printf '%s\n' "$raw_log"
```

Expected: prints a non-empty `.jsonl` path outside the repository under `~/.codex/opencode-runs/`.

- [ ] **Step 4: Inspect git diff as Codex parent**

Run:

```bash
git diff --stat
git diff -- ~/.codex/bin/codex-opencode-worker .codex/agents/opencode-delegator.toml .agents/AGENTS.md
```

Expected: diff shows only the planned wrapper, Codex agent, and AGENTS changes.

### Task 10: Final Verification

**Files:**
- Verify: `~/.codex/bin/codex-opencode-worker`
- Verify: `.codex/agents/opencode-delegator.toml`
- Verify: `.agents/AGENTS.md`
- Verify: `/Users/haru256/.config/opencode/opencode.json`

- [ ] **Step 1: Run shell syntax check**

Run:

```bash
bash -n ~/.codex/bin/codex-opencode-worker
```

Expected: no output and exit status `0`.

- [ ] **Step 2: Run TOML syntax check**

Run:

```bash
mise exec -- python - <<'PY'
import tomllib
from pathlib import Path
tomllib.loads(Path(".codex/agents/opencode-delegator.toml").read_text())
print("valid toml")
PY
```

Expected:

```text
valid toml
```

- [ ] **Step 3: Run OpenCode config check**

Run:

```bash
mise exec -- opencode agent list
```

Expected: exits successfully and shows the configured agents.

- [ ] **Step 4: Review git status**

Run:

```bash
git status --short
```

Expected planned repository changes:

```text
 M .agents/AGENTS.md
?? .codex/agents/
?? docs/superpowers/plans/2026-05-06-codex-opencode-delegator.md
?? ~/.codex/bin/codex-opencode-worker
```

The `.codex/agents/` directory should contain both `opencode-delegator.toml` and `opencode-delegator-prompt.md`. If `/Users/haru256/.config/opencode/opencode.json` is not tracked by this repository, it will not appear in `git status`. Record that fact in the final implementation summary.

## Self-Review

- Spec coverage: The plan covers the user's requirement to reduce GPT-5.5 token usage by delegating implementation to OpenCode while Codex remains the orchestrator and reviewer.
- mise coverage: The plan explicitly uses `mise exec -- opencode` because OpenCode is installed through mise.
- Model availability coverage: The plan verifies `opencode-go/kimi-k2.6` appears in OpenCode models and can complete a no-edit run before delegation depends on it.
- Codex sub-agent coverage: The plan creates a custom delegator agent and a built-in `worker` fallback prompt, then records which mode the current Codex environment supports.
- Output feedback loop: The plan keeps raw JSONL logs outside the repository, prints only compact wrapper reports to stdout, includes final report labels, includes `git diff --stat`, and requires Codex parent inspection before deciding next actions.
- Safety coverage: The plan keeps destructive git operations denied and states that no commits happen without explicit user request.
- Placeholder scan: No unfinished-marker placeholders are present.
