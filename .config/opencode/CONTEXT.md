# opencode Agent System

A custom multi-agent configuration for the opencode CLI. A single persistent **orchestrator** coordinates ephemeral **specialist subagents** for repository exploration, implementation, and review.

## Language

**orchestrator**:
The primary agent of the v2 system (`orchestrator_v2`). Holds persistent context across all user turns, decides routing, writes plans/ADRs/docs, adjudicates review findings, and delegates execution to specialists.
_Avoid_: planner, dispatcher, main agent

**specialist subagent**:
A subagent dedicated to a bounded task — exploration, implementation, review, or oracle consultation. Specialists are ephemeral: each invocation is a fresh session with no memory of prior calls.
_Avoid_: worker, helper

**primary agent**:
An agent whose session persists across all user turns. Set via `default_agent` in `opencode.json`. Exactly one in the system.
_Avoid_: host, root agent

**ephemeral context**:
The fresh session created on each specialist invocation. Starts with only the brief and the agent prompt; conversation history is not carried.
_Avoid_: fresh context, cold context

**persistent context**:
The orchestrator's session content that survives across user turns: prior plans, reviewer findings, adjudications, failure signatures, and conversation history.
_Avoid_: long context

**brief**:
The structured input passed to a specialist on invocation. Fields: Goal, Background, Constraints, Relevant paths, Acceptance criteria, Mode (when invoking the explorer). Kept under 10 lines.
_Avoid_: task description, instructions, prompt

**mode** (explorer):
One of `Repo`, `External`, or `Hybrid`. `Repo` for repository understanding, `External` for library/paper/API research, `Hybrid` runs both in one session. Selected via the brief or inferred from content.
_Avoid_: explorer type, search mode

**adjudication**:
The orchestrator's per-finding decision after a reviewer report. Verdicts: `ACCEPT`, `REJECT`, `DEFER`, `NEEDS_CONTEXT`, `ESCALATE`. Persisted to the plan file under `Review Findings > Planner Adjudication`.
_Avoid_: review decision, triage

**failure_signature**:
A stable identifier emitted in a specialist's `BLOCKED` report. The orchestrator tracks repeats; two consecutive identical signatures trigger automatic `oracle_v2` escalation.
_Avoid_: error code, stack trace hash

**oracle escalation**:
Automatic invocation of `oracle_v2` after two consecutive identical failure_signatures from the same specialist, or on orchestrator-detected drift. Bounded to one call per failure loop.
_Avoid_: oracle consultation, oracle ask

## Flagged ambiguities

- **"task"**: In opencode's CLI sense, a `task` is a single specialist invocation (one ephemeral session). In user-facing dialogue, "task" often means a unit of work the user assigned. Prefer **invocation** for the former and **work item** for the latter when both appear in the same sentence.
- **"agent"** alone is ambiguous between primary and specialist. Always qualify: **orchestrator** or **specialist subagent**.

## Example dialogue

> Dev: "Why does the orchestrator persist but the implementer doesn't?"
>
> Expert: "Because the orchestrator is the primary — its session is yours, across turns. The implementer is a specialist subagent. Each invocation gets ephemeral context: a fresh session with only the brief. You wouldn't want the implementer's mid-edit reasoning to clutter your next turn anyway."
>
> Dev: "So when I revise the plan, I'm still talking to the same orchestrator?"
>
> Expert: "Yes. The orchestrator wrote the plan in its persistent context — it remembers the trade-offs. When you ask to fix step 3, no cold start happens at that level. It does spawn fresh specialists downstream as needed, but the brief it sends is richer because of its own memory."
>
> Dev: "And the failure_signature thing?"
>
> Expert: "When the implementer hits `BLOCKED`, it reports a failure_signature. The orchestrator remembers it. If the same signature comes back twice from the same specialist, oracle escalation fires automatically — no user gate."
