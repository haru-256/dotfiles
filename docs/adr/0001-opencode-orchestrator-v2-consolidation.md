# Consolidate dispatcher_v2 and planner_v2 into orchestrator_v2

The opencode v2 agent system originally split routing (`dispatcher_v2` as primary) from planning (`planner_v2` as a specialist subagent). This made the highest-thinking agent ephemeral: revising a plan spawned a fresh `planner_v2` task with no memory of how the original plan was authored, so every revision rediscovered context from the plan file alone. We merged the two into a single primary `orchestrator_v2`, keeping specialist subagents (`explorer_v2`, `implementer_v2`, `reviewer_v2`, `oracle_v2`) ephemeral because their work is bounded and model specialization matters more there than context continuity.

## Considered alternatives

- **Collapse everything into one primary, no specialists.** Rejected: loses per-task model specialization (kimi-k2.6 for implementation, deepseek-v4-pro/max for review, deepseek-v4-flash for exploration). The model-per-role split is a real win we did not want to give up.
- **Keep `dispatcher_v2` as primary, add session-resume for `planner_v2`.** Rejected: opencode does not support resuming a prior specialist session — each task invocation is necessarily a fresh session.
- **A cheap front-door primary that hands context to a planning specialist.** Rejected: reintroduces the context-loss problem at the hand-off boundary, just one level deeper.
- **Quota-based model fallback (gpt-5.5 → deepseek-v4-pro on exhaustion).** Rejected as a primary cost lever: it is a degradation strategy for rate limits, not adaptive routing, so the routine cost of gpt-5.5 is unchanged.

## Consequences

- `gpt-5.5` is now consumed on every user turn (including light-touch responses) because `orchestrator_v2` is the persistent primary. If routine cost becomes unacceptable, switch `orchestrator_v2` to `opencode-go/deepseek-v4-pro` with `reasoningEffort: high`. `oracle_v2` remains on `gpt-5.5 xhigh` for hard escalations regardless.
- Pre-implementation reviews are removed: plans, ADRs, and docs are no longer reviewed by `reviewer_v2` before implementation. Only post-implementation review of code changes remains. Users can still trigger `/review-plan-v2`, `/review-adr-v2`, etc. explicitly.
- `oracle_v2` is invoked automatically after two consecutive identical failure_signatures from the same specialist; the previous "ask user first" gate is removed. Bounded cost (one call per failure loop) makes the user-confirmation step net-negative.
- The R2a two-step pattern (dispatcher pre-extracts the explorer's Summary Report before passing to planner) dissolves: `orchestrator_v2` calls `explorer_v2` itself and retains both the Summary Report and the Exploration Log in its persistent context, giving downstream planning richer information than before.
- The legacy `orchestrator` agent (v1) and other v1 specialists (`implementer`, `explorer`, `reviewer`, `oracle`) are removed from `opencode.json` to prevent confusion with the renamed v2 primary.
