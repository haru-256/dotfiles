---
description: Small focused fix through the implementer
agent: implementer
---

Apply a small focused fix.

Task:
$ARGUMENTS

Rules:
- Make the smallest coherent change.
- Use this command only for small focused fixes with clear scope. If the task is broad, ambiguous, multi-file by nature, requires investigation before choosing an approach, or touches API, schema, security, IAM, data model, persisted state, or public behavior, stop with NEEDS_CONTEXT and suggest @orchestrator or /feature.
- Do not refactor unrelated code.
- Run the relevant check if obvious.
- Report files changed, commands run, test result, and risks.
