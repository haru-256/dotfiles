---
description: Critically review documentation changes through reviewer
agent: reviewer_v2
---

ARTIFACT_TYPE: docs

Target:
$ARGUMENTS

Apply only the README/docs review framework.
Inline output only. Do not persist findings or adjudication to docs or any plan; orchestrator_v2 owns persistence when it invokes reviewer_v2 during a workflow.

List individual issues under Critical issues / Non-blocking suggestions using the Finding format defined in reviewer_v2.md.
