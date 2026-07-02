# SDD Progress: Herdr Agents Skill Package

Plan: docs/superpowers/plans/2026-07-02-herdr-agents-skill.md

- [x] Task 1: Add Package-Local Test Harness
- [x] Task 2: Move Prompts and Scripts into the Skill Package
- [x] Task 3: Create the Skill Guidance and Install Script
- [x] Task 4: Install Symlinks and Remove Old Runtime Paths
- [x] Task 5: Update Documentation
- [x] Task 6: Pressure-Test the Skill Package

Notes:
- Implemented by subagent 019f2039-b097-7131-86ae-ac34cb9d2c61 with a follow-up installer safety fix in the parent session.
- Installer replaces empty target directories with symlinks and rejects non-empty target directories.
- Pressure scenario evaluator 019f2041-ee0a-7613-a434-384b9b2e5ecd passed all one-shot/session/reuse/cleanup scenarios.
- Review findings from 019f2042-1087-7ae0-9a1f-43e2cf4abf5c were fixed by 019f2044-a520-7811-9ab6-b41827f5f3c1.
