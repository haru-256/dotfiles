---
description: Write or update an ADR through the orchestrator
agent: orchestrator_v2
---

Write or update an ADR for the following decision:
$ARGUMENTS

Rules:
- Use existing ADR format if present in the repo.
- Include: status, context, decision, alternatives considered, consequences, reversibility, review conditions.
- Do not edit source code.
- Do not pre-review the ADR. If a review is needed later, the user can invoke /review-adr-v2 explicitly.
