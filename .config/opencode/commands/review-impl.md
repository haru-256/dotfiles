---
description: Critically review an implementation diff
agent: reviewer
---

ARTIFACT_TYPE: implementation

Target:
$ARGUMENTS

Read the plan first if a plan path is provided, then the diff (`git diff main...HEAD`). Apply only the implementation review framework. Generate critical thinking findings before forming the verdict.

List individual issues under Critical issues / Non-blocking suggestions using the Finding format defined in reviewer.md (ID / Severity / Confidence / Category / Evidence / Why / Recommended action / Must fix before merge).
