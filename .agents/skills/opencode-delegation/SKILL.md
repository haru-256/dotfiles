---
name: opencode-delegation
description: Use when the user wants Codex to orchestrate work while delegating implementation, repository research, test fixing, diff summarization, refactoring, or documentation updates to OpenCode/Kimi workers.
---

# OpenCode Delegation

Use this when Codex should preserve GPT-5.5 context for orchestration and review while OpenCode/Kimi performs implementation-heavy work.

## Requirements

- Global wrapper exists at `~/.codex/bin/codex-opencode-worker`.
- If `codex-opencode-worker` is on `PATH`, the short command may be used; otherwise use the absolute `~/.codex/bin/...` path.
- OpenCode is invoked through `mise exec -- opencode`.
- Default worker model is `opencode-go/kimi-k2.6`, overridable with `OPENCODE_WORKER_MODEL`.
- Raw logs live outside the repository under `~/.codex/opencode-runs/...`.

## Workflow

1. Restate the task and decide if delegation is useful. Keep planning, architecture, final review, and merge-readiness decisions in Codex.
2. Choose the worker role automatically:
   - `codebase-researcher`: unclear codebase context, related files, patterns, or test commands.
   - `implementer`: normal feature work or bug fixes.
   - `test-fixer`: failing test or command output is available.
   - `diff-summarizer`: large existing diff needs review focus or summary.
   - `refactor-worker`: mechanical rename, move, split, or behavior-preserving refactor.
   - `docs-worker`: README, AGENTS, setup notes, usage docs, or migration notes.
3. Prefer the Codex custom agent `opencode-delegator` when available. If custom agents are not exposed, dispatch the built-in `worker` with `.codex/agents/opencode-delegator-prompt.md` content plus the task.
4. The delegator should run:

```bash
OPENCODE_WORKER_AGENT="<role>" ~/.codex/bin/codex-opencode-worker "<concise task>"
```

5. Read only the compact wrapper stdout first. Inspect `OPENCODE_LOG_FILE` only when the compact report is ambiguous or failed.
6. Always inspect `git diff --stat`; inspect targeted `git diff` for changed files before deciding next action.
7. If OpenCode fails, pass the compact failure report and relevant stderr/log excerpt to `test-fixer` or retry with a narrower prompt.

## User Prompt Shortcut

When the user says any of these, apply this skill without requiring explicit worker names:

- "OpenCode 委譲運用で進めて"
- "Codex はオーケストレーションだけして"
- "実装は Kimi/OpenCode に任せて"
- "GPT-5.5 のトークンを節約して実装して"

## Guardrails

- Do not stream full OpenCode JSON logs into the main Codex context.
- Do not commit, push, tag, release, merge, rebase, or reset unless explicitly requested.
- Do not ask the user to choose a worker role unless the task is genuinely ambiguous after `codebase-researcher`.
- If no `~/.codex/bin/codex-opencode-worker` exists, report that setup is missing and suggest running the dotfiles OpenCode delegator setup.
