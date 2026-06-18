# Opencode Subagent Reuse Design

## Goal

Reduce context fragmentation in the opencode agent system while preserving independent judgment where prior context would create confirmation bias.

## Scope

This design covers three changes:

1. Document and encode a subagent reuse policy for the `orchestrator`.
2. Resolve the broken `~/.config/opencode/AGENTS.md` symlink situation.
3. Clarify `CONTEXT.md` and remove stale `_v2` agent names.

It does not change the `oracle` `reasoningEffort: "xhigh"` setting. Investigation found that setting is valid and likely effective for `openai/gpt-5.5` in the current opencode version.

## Design

The `orchestrator` should treat subagent reuse as a correctness tradeoff, not as a blanket optimization.

Reuse is preferred when continuity improves correctness: continuing the same task, following up on the same exploration, retrying implementation after a failed attempt, tracking the same failure signature, or applying accepted review findings from the same workflow.

Fresh subagents are preferred when independence improves correctness: implementation review, oracle decisions, independent verification, second-opinion exploration, or checking whether a previous specialist conclusion was wrong. In these cases, context continuity can cause anchoring or deference to earlier outputs.

The policy should live in the `orchestrator` prompt because the orchestrator is the routing and judgment agent. `CONTEXT.md` should describe the vocabulary and intent at a lower level of authority, so humans and agents understand why the prompt behaves this way.

## File Responsibilities

- `.config/opencode/prompts/orchestrator.md`: operational routing rule for when to reuse a `task_id` and when to start a fresh subagent.
- `.config/opencode/CONTEXT.md`: human/agent-facing domain context, updated to current agent names and the role of the document itself.
- `~/.config/opencode/AGENTS.md`: dangling symlink cleanup or retargeting, depending on the intended shared-instructions source.

## Acceptance Criteria

- The orchestrator prompt contains an explicit subagent reuse policy.
- The policy says reviews, oracle decisions, independent verification, and second opinions should use fresh subagents by default.
- The policy says same-task exploration, implementation retries, and same failure loops should reuse subagent sessions when a prior `task_id` exists.
- `CONTEXT.md` no longer refers to `orchestrator_v2` or `oracle_v2`.
- `CONTEXT.md` explains its role as a domain-context document, not as an executable config file.
- The broken `AGENTS.md` symlink is either removed or corrected to a real target.
- `oracle` keeps `reasoningEffort: "xhigh"`.

## Non-Goals

- Do not change the agent model assignments.
- Do not change `mode: "all"` versus `mode: "subagent"` in this slice.
- Do not change MCP configuration.
- Do not convert `opencode.json` to JSONC in this slice.

## Open Decision

The implementation should inspect the dangling `AGENTS.md` symlink target. If there is a clear intended replacement instruction file, retarget it. If not, remove the symlink and document that opencode is currently using the global `/Users/haru256/.config/opencode/AGENTS.md` instruction source from the running environment rather than the dangling target.
