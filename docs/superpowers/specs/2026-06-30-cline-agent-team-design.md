# Cline Adaptive Coding Workflow Design

## Goal

Add a practical Cline CLI workflow that saves tokens while improving coding performance.

The design should not mechanically reproduce OpenCode's five-agent setup. Instead, it should use the cheapest workflow that is likely to produce a correct result, then escalate only when the task needs more context isolation, review independence, or architectural judgment.

The workflow has three levels:

1. **Default path:** single Cline session with compact project rules.
2. **Escalation path:** Agent Teams for multi-step or risky implementation work.
3. **Quality gates:** targeted reviewer and oracle passes only when their expected quality gain exceeds their token overhead.

## Background

The repository already contains an OpenCode configuration with five custom agents under `.config/opencode/`:

- `.config/opencode/opencode.json` defines role-specific models, prompts, and permissions.
- `.config/opencode/prompts/*.md` contains mature role prompts for `orchestrator`, `explorer`, `implementer`, `reviewer`, and `oracle`.
- `scripts/cline-team` wraps the real Cline CLI for Agent Teams escalation.

Cline CLI differs from OpenCode. It supports Agent Teams via `--team-name`, project rules via `.cline/rules/`, prompt overrides via `--system`, model/provider overrides via `--provider`, `--model`, and `--thinking`, and command restrictions via `CLINE_COMMAND_PERMISSIONS`. It does not currently have a confirmed OpenCode-like JSON agent schema with per-agent permission blocks in this repository.

## Non-goals

- Do not replace the existing OpenCode setup.
- Do not add a normal `cline` wrapper; normal `cline` should resolve to the installed Cline executable.
- Do not introduce unverified `.cline/agents.yaml` schema usage.
- Do not create role-specific config directories such as `~/.cline-reviewer` in this initial implementation.
- Do not commit changes automatically.

## Proposed approach

Use an adaptive Cline-native workflow:

1. Add a short project rule at `.cline/rules/adaptive-coding.md` that teaches Cline to start simple, avoid unnecessary context loading, and escalate only when useful.
2. Add Cline-specific prompts under `.config/cline/prompts/` for the escalation roles: `orchestrator`, `explorer`, `implementer`, `reviewer`, and `oracle`.
3. Add `scripts/cline-team`, a POSIX shell wrapper for tasks that benefit from Agent Teams.
4. Add optional headless review / oracle usage examples to README instead of making them mandatory wrappers.
5. Update `README.md` with the default path and escalation path.

This keeps the common workflow cheap:

```sh
cline "小さな修正を実装して"
```

and makes escalation explicit when the task deserves it:

```sh
cline-team "調査して、必要なら実装してレビューして"
```

## Critical thinking: why adaptive instead of always Agent Teams?

Always using Agent Teams can improve separation of concerns, but it adds coordination overhead. For small or obvious coding tasks, that overhead can consume more tokens than it saves and can slow down feedback. The true objective is not to maximize the number of agents; it is to maximize correct useful code per token.

Adaptive workflow wins because:

- Small tasks stay cheap and fast.
- Broad repository exploration stays out of the main context when it matters.
- Implementation review is added only when it improves correctness materially.
- Expensive oracle-style reasoning is reserved for decisions that can actually change the outcome.
- The user does not need to reason about subagents vs teams for every request.

Agent Teams remain valuable for tasks with multiple phases, unclear scope, meaningful implementation risk, or repeated failure loops.

## Escalation policy

Use the cheapest adequate path.

### Stay in the default single-session path when

- the task is small and localized;
- relevant files are already named by the user;
- the implementation is mechanical;
- the risk is low;
- the expected review/orchestration overhead is larger than the likely benefit.

### Escalate to Agent Teams when

- the task needs broad repository exploration before implementation;
- the change spans multiple files or subsystems;
- the task has ambiguous scope or non-trivial acceptance criteria;
- implementation and review should be independent;
- the work may span multiple turns or sessions;
- the same failure pattern repeats.

### Escalate to reviewer when

- a meaningful implementation diff exists;
- the change touches behavior, tests, config loading, scripts, security, persistence, or public UX;
- the implementation deviates from the plan;
- the user explicitly asks for review.

### Escalate to oracle only when

- reviewer returns an architectural or strategic escalation;
- implementation fails twice with the same failure signature;
- the decision affects API, schema, state, IAM, security, data model, or long-lived architecture;
- two plausible approaches have unclear trade-offs;
- the current direction appears to conflict with inherited constraints.

Do not use oracle for routine implementation judgment.

## Escalation role model

### orchestrator

In the Agent Teams path, the main Cline session acts as `orchestrator`.

Responsibilities:

- Receive user requests.
- Clarify scope and success criteria.
- Delegate broad repository or external research to `explorer`.
- Delegate scoped implementation to `implementer`.
- Delegate meaningful post-change review to `reviewer`.
- Invoke `oracle` only for blocked loops, architecture drift, or API/schema/security/data-model decisions.
- Keep user-facing summaries compact.

Boundaries:

- Avoid broad repository exploration in the main context.
- Avoid non-trivial source/test edits directly.
- Avoid invoking `oracle` for routine work.

### explorer

Read-only research agent.

Responsibilities:

- Identify relevant files and relationships.
- Summarize impact radius, tests, docs, risks, and constraints.
- Return evidence paths for the orchestrator.

Boundaries:

- Do not edit files.
- Do not decide implementation order.
- Do not write plans or ADRs.

Note: Cline's built-in read-only subagents may be useful for broad exploration, but they are not part of the required user-facing setup. Treat them as an internal optimization when Cline chooses to use them, not as an additional configuration surface.

### implementer

Scoped implementation agent.

Responsibilities:

- Make the smallest coherent code/test/doc change needed by the brief.
- Preserve existing style.
- Run relevant checks when possible.
- Report files changed, commands run, test results, deviations, and remaining risks.

Boundaries:

- Do not create plans or ADRs.
- Do not broaden scope.
- Return `NEEDS_CONTEXT` before tool use if the brief lacks concrete behavior, relevant paths or impact area, or scope boundaries.

### reviewer

Read-only review agent.

Responsibilities:

- Review plan, docs, README, ADR, or implementation diff against the original goal.
- Check correctness, security, tests, maintainability, and scope.
- Produce structured, evidence-backed findings.

Boundaries:

- Do not edit files.
- Do not implement fixes.
- Do not escalate without concrete reason.

### oracle

Rare high-context decision consultation agent.

Responsibilities:

- Diagnose blocked loops or architectural drift.
- Resolve unclear trade-offs when the decision affects API, schema, security, state, IAM, data model, or long-lived architecture.
- Return a compact next-approach recommendation.

Boundaries:

- Do not edit files.
- Do not perform broad exploration.
- Do not become a second planner for routine tasks.

## File changes

### New files

```text
.config/cline/prompts/orchestrator.md
.config/cline/prompts/explorer.md
.config/cline/prompts/implementer.md
.config/cline/prompts/reviewer.md
.config/cline/prompts/oracle.md
.cline/rules/adaptive-coding.md
scripts/cline-team
```

### Updated files

```text
README.md
```

## Prompt strategy

The Cline prompts should be adapted from the OpenCode prompts, not copied verbatim. They are escalation prompts, not always-on context.

Adaptation rules:

- Replace OpenCode-specific `@agent` and `task` wording with Cline Agent Teams and adaptive escalation wording.
- Remove OpenCode-specific permission-ceiling details.
- Keep role boundaries and output formats.
- Keep prompts shorter than the OpenCode versions where practical to avoid wasting the main context.
- Use `orchestrator` and `explorer` spellings, not `orchestorator` or `exploter`.

The always-on `.cline/rules/adaptive-coding.md` file should be much shorter than the role prompts. It should teach routing and escalation, not embed all role definitions.

## Wrapper behavior

`scripts/cline-team` should:

- Be POSIX `sh` with `set -eu`.
- Resolve the real Cline executable without resolving to itself.
- Prefer `CLINE_BIN_PATH` when executable.
- Prefer `mise which cline` when available.
- Fall back to known install locations, including the current `latest` mise path.
- Start Cline with Agent Teams for escalation tasks:

  ```sh
  --team-name "${CLINE_TEAM_NAME:-dotfiles-agents}"
  --provider "${CLINE_PROVIDER:-openai-codex}"
  --model "${CLINE_MODEL:-gpt-5.5}"
  --thinking "${CLINE_THINKING:-medium}"
  --system "$(cat "$HOME/.config/cline/prompts/orchestrator.md")"
  ```

- Forward all user arguments to Cline.

The wrapper should not force `CLINE_COMMAND_PERMISSIONS`, because command needs differ by task. README may document optional examples.

## README updates

The Cline section should document:

- Default cheap path: use normal `cline` for small/local tasks.
- Escalation path: use `scripts/cline-team` for multi-phase or risky tasks.
- Symlinks for `.config/cline/prompts` and `scripts/cline-team`.
- Project rule location `.cline/rules/adaptive-coding.md`.
- Basic usage:

  ```sh
  cline "小さな修正を実装して"
  cline-team
  cline-team "この変更を調査して、必要なら実装してレビューして"
  ```

- Override example:

  ```sh
  CLINE_TEAM_NAME=my-task CLINE_THINKING=high cline-team "..."
  ```

## Validation

Run at minimum:

```sh
sh -n scripts/cline-team
git diff -- scripts/cline-team README.md .config/cline .cline/rules docs/superpowers/specs/2026-06-30-cline-agent-team-design.md
```

If possible, run:

```sh
scripts/cline-team --help
```

This command may fail when the Cline hub daemon port is already in use. If so, report the failure and do not treat it as a script syntax failure.

## Risks and mitigations

### Agent Teams overhead can exceed its benefit

Mitigation: make normal `cline` the default path and reserve `cline-team` for tasks matching the escalation policy.

### Cline Agent Teams behavior differs from OpenCode task delegation

Mitigation: keep the setup prompt- and wrapper-based, avoid relying on unverified `.cline/agents.yaml` schema.

### Long prompts could offset token savings

Mitigation: keep role prompts out of the default path and keep always-on `.cline/rules/adaptive-coding.md` short.

### Wrapper may accidentally call itself

Mitigation: resolve the real Cline executable defensively and compare physical paths so `scripts/cline-team` does not resolve to itself.

### Read-only roles are not enforced as strongly as OpenCode permissions

Mitigation: rely on Cline built-in subagents for broad read-only exploration when possible, keep role prompts explicit, and document optional `CLINE_COMMAND_PERMISSIONS` examples.

## Acceptance criteria

- Default workflow stays usable through normal `cline` for small/local tasks.
- `scripts/cline-team` starts Cline in team mode with the orchestrator system prompt for escalation tasks.
- Cline prompts exist for all five roles.
- Project rule captures adaptive token-saving routing policy without excessive context.
- README documents symlink setup and basic usage.
- `sh -n scripts/cline-team` passes.
- The implementation does not modify existing OpenCode behavior and does not introduce a normal `cline` wrapper.

## Spec self-review

- Placeholder scan: no `TBD` or `TODO` placeholders remain.
- Consistency check: file list, wrapper behavior, README updates, validation, and acceptance criteria align with adaptive workflow.
- Scope check: focused on practical adaptive Cline workflow; role-specific config directories and `.cline/agents.yaml` are explicitly out of scope.
- Ambiguity check: role names, wrapper defaults, validation commands, and non-goals are explicit.