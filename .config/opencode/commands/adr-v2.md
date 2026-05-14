---
description: Write or update an ADR through the v2 planner
agent: planner_v2
---

Write or update an ADR for the following decision:
$ARGUMENTS

Rules:
- Use existing ADR format if present in the repo.
- Include: status, context, decision, alternatives considered, consequences, reversibility, review conditions.
- Do not edit source code.
- After saving, request @reviewer_v2 for the new file and adjudicate findings through the planner_v2 workflow. Do not use /review-adr-v2 from inside this planner-owned workflow because direct review commands do not persist findings or adjudication.
