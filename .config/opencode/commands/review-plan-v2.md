---
description: Critically review a Superpowers plan through reviewer
agent: reviewer_v2
---

ARTIFACT_TYPE: plan

Target plan:
$ARGUMENTS

Apply only the plan review framework. Generate critical thinking findings before forming the verdict.
Inline output only. Do not persist findings or adjudication to the plan; orchestrator_v2 owns persistence when it invokes reviewer_v2 during a workflow.

List individual issues under Critical issues / Non-blocking suggestions using the Finding format defined in reviewer_v2.md.
