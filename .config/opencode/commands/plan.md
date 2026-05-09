---
description: Create a Superpowers implementation plan
agent: orchestrator
---

Create a Superpowers implementation plan for the following task:
$ARGUMENTS

Rules:
- Use the writing-plans skill when applicable.
- Save the plan under `docs/superpowers/plans/`.
- After the plan body is written, append the following living-document sections at the end (if not already present):

  ## Implementation Log
  <!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N → STATUS | commit-or-failure-signature -->

  ## Review Findings
  <!-- Reviewer appends one line per review: [YYYY-MM-DD] ARTIFACT_TYPE → VERDICT | key issue -->

  ## Deviations from Plan
  <!-- Implementer documents intentional deviations and reasons -->

  ## Open Questions
  <!-- Any agent adds questions for orchestrator or arbiter -->

- Do not implement the plan.
- After saving, report the plan path and recommended execution mode.
