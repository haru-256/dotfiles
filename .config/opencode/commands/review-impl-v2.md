---
description: Critically review an implementation diff through reviewer
agent: reviewer_v2
---

ARTIFACT_TYPE: implementation

Target:
$ARGUMENTS

Read the plan first if a plan path is provided, then the diff (`git diff main...HEAD`). Apply only the implementation review framework. Generate critical thinking findings before forming the verdict.
Inline output only. Do not persist findings or adjudication to the plan; planner_v2 owns persistence when it invokes reviewer_v2 during a workflow.

List individual issues under Critical issues / Non-blocking suggestions using the Finding format defined in reviewer_v2.md.
