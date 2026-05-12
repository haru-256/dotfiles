---
description: Create a Superpowers implementation plan through the v2 planner
agent: planner_v2
---

Create a Superpowers implementation plan for the following task:
$ARGUMENTS

Rules:
- Use the writing-plans skill when applicable.
- Save the plan under `docs/superpowers/plans/`.
- After the plan body is written, append the following living-document sections at the end (if not already present):

  ## Implementation Log
  <!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N -> STATUS | commit-or-failure-signature -->

  ## Review Findings
  <!-- This template is also defined in prompts/planner_v2.md. Keep them in sync on every edit. -->

  ### Reviewer Raw Findings
  <!-- Planner V2 copies @reviewer_v2's structured findings verbatim here when invoking @reviewer_v2
       during a workflow. Direct /review-*-v2 calls do not write here.
       Raw findings are review input (audit history), not implementation instructions. -->

  ### Planner V2 Adjudication
  <!-- Planner V2 appends adjudication tables for v2 workflow reviews.
       Only ACCEPT rows are implementation instructions:
       | ID | Severity | Decision | Reason | Action | -->

  ## Deviations from Plan
  <!-- Implementer documents intentional deviations and reasons -->

  ## Open Questions
  <!-- Any agent adds questions for planner_v2 or oracle_v2 -->

- Do not implement the plan.
- After saving, report the plan path and recommended execution mode.
