---
name: context-plan
description: Gather local code context, then produce an implementation plan.
---

## scout
output: context.md
outputMode: file-only
progress: true

Inspect the current repository for this task:

{task}

Return a compact context report with:
- relevant files and directories
- existing patterns to follow
- likely change boundaries
- risks or ambiguous requirements
- recommended starting point for planning

Do not edit files.

## planner
reads: context.md
output: plan.md
outputMode: file-only
progress: true

Create a concrete implementation plan for:

{task}

Use the scout report from `context.md`.

The plan must include:
- exact files to create or modify
- validation commands
- risks and non-goals
- a recommendation on whether implementation should be done inline, by one worker, or by multiple workers

Do not edit source files.
