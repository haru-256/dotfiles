# Opencode Subagent Reuse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a clear subagent reuse policy to the opencode agent system and clean up the two documentation/config hygiene issues already identified.

**Architecture:** Put operational routing behavior in the `orchestrator` prompt, and keep explanatory vocabulary in `CONTEXT.md`. Treat the `AGENTS.md` symlink as filesystem hygiene: either point it to a real instruction file or remove it if no real target exists.

**Tech Stack:** opencode global config, Markdown agent prompts, Markdown context docs, shell verification commands.

---

## File Structure

- Modify: `.config/opencode/prompts/orchestrator.md` — add the subagent session reuse policy to the orchestrator's routing responsibilities.
- Modify: `.config/opencode/CONTEXT.md` — clarify the file's role and replace stale `orchestrator_v2` / `oracle_v2` names.
- Modify filesystem entry: `~/.config/opencode/AGENTS.md` — remove or retarget the dangling symlink after verifying the intended target.
- Do not modify: `.config/opencode/opencode.json` — keep `oracle.reasoningEffort = "xhigh"` unchanged.

## Task 1: Add orchestrator subagent reuse policy

**Files:**
- Modify: `.config/opencode/prompts/orchestrator.md`

- [ ] **Step 1: Read the current orchestrator prompt**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path('.config/opencode/prompts/orchestrator.md')
print(p.read_text())
PY
```

Expected: the file prints and contains sections about routing, delegation, failure detection, and review adjudication.

- [ ] **Step 2: Insert a `Subagent Session Reuse Policy` section near the routing/delegation rules**

Add this exact section, adapting only surrounding heading level if the file's existing hierarchy requires it:

```markdown
# Subagent Session Reuse Policy

Prefer reusing a specialist subagent session when continuity improves correctness:
- continuing the same user task after a follow-up question;
- continuing the same repo or external exploration thread;
- retrying implementation for the same written plan;
- fixing accepted reviewer findings from the same workflow;
- tracking the same failure signature during a failure loop.

Prefer a fresh specialist subagent when independence improves correctness:
- implementation review;
- oracle decisions;
- independent verification of a prior specialist conclusion;
- second-opinion exploration;
- comparisons where prior context could anchor the answer.

When reusing a subagent, pass the prior `task_id` and state why continuity is useful. When starting fresh, omit `task_id` and state why independence is useful. If continuity and independence conflict, choose the option that better protects correctness, security, data integrity, public behavior, and review objectivity.
```

- [ ] **Step 3: Ensure the policy does not conflict with existing review/oracle rules**

Check the file text and confirm:

```text
reviewer invocations for meaningful implementation changes still start fresh unless the user explicitly asked to continue a prior review thread;
oracle invocations for failure loops or escalations still start fresh by default;
implementer retries for the same plan can reuse a prior task_id;
explorer follow-ups for the same investigation can reuse a prior task_id.
```

- [ ] **Step 4: Verify the prompt still has no instruction to reuse reviewers by default**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
t = Path('.config/opencode/prompts/orchestrator.md').read_text()
assert 'Prefer a fresh specialist subagent when independence improves correctness' in t
assert 'implementation review' in t
assert 'oracle decisions' in t
print('orchestrator reuse policy present')
PY
```

Expected:

```text
orchestrator reuse policy present
```

## Task 2: Clarify CONTEXT.md and update stale agent names

**Files:**
- Modify: `.config/opencode/CONTEXT.md`

- [ ] **Step 1: Read the current context document**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path('.config/opencode/CONTEXT.md')
print(p.read_text())
PY
```

Expected: the file prints and contains old names such as `orchestrator_v2` or `oracle_v2`.

- [ ] **Step 2: Add a role statement near the top**

Add this paragraph near the beginning of the file, after the title or introductory paragraph:

```markdown
`CONTEXT.md` is a domain-context document for the opencode agent system. It records vocabulary, roles, and design intent for humans and agents. It is not an executable config file; runtime behavior is controlled by `opencode.json`, prompt files under `prompts/`, command files, and loaded skills.
```

- [ ] **Step 3: Replace stale agent names**

Apply these replacements throughout `.config/opencode/CONTEXT.md`:

```text
orchestrator_v2 -> orchestrator
oracle_v2 -> oracle
```

- [ ] **Step 4: Add a concise reuse-policy summary**

Add this paragraph in the agent-system or orchestration section:

```markdown
Subagent sessions are reused when continuity improves correctness, such as same-task exploration, implementation retries, and tracking the same failure signature. Fresh subagents are preferred when independence improves correctness, such as reviews, oracle decisions, independent verification, and second opinions.
```

- [ ] **Step 5: Verify stale names are gone**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
t = Path('.config/opencode/CONTEXT.md').read_text()
assert 'orchestrator_v2' not in t
assert 'oracle_v2' not in t
assert 'domain-context document' in t
assert 'Fresh subagents are preferred' in t
print('CONTEXT.md updated')
PY
```

Expected:

```text
CONTEXT.md updated
```

## Task 3: Resolve the dangling AGENTS.md symlink

**Files:**
- Modify filesystem entry: `~/.config/opencode/AGENTS.md`

- [ ] **Step 1: Inspect the symlink**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path.home() / '.config/opencode/AGENTS.md'
print(f'path={p}')
print(f'is_symlink={p.is_symlink()}')
print(f'exists={p.exists()}')
if p.is_symlink():
    print(f'target={p.readlink()}')
PY
```

Expected for the known current issue:

```text
is_symlink=True
exists=False
target=/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md
```

- [ ] **Step 2: Check for a real intended instruction file**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
candidates = [
    Path('.config/opencode/AGENTS.md'),
    Path('AGENTS.md'),
    Path('.agents/AGENTS.md'),
    Path.home() / '.config/opencode/AGENTS.md',
]
for p in candidates:
    print(f'{p}: exists={p.exists()} is_symlink={p.is_symlink()}')
PY
```

Expected: either one non-symlink candidate exists and is the intended target, or no real target exists.

- [ ] **Step 3A: If a real intended target exists, retarget the symlink**

Use this only when Step 2 found a real non-symlink instruction file that should be used globally:

```bash
python3 - <<'PY'
from pathlib import Path
link = Path.home() / '.config/opencode/AGENTS.md'
target = Path('/ABSOLUTE/PATH/TO/REAL/AGENTS.md')
assert target.exists() and not target.is_symlink(), target
if link.exists() or link.is_symlink():
    link.unlink()
link.symlink_to(target)
print(f'{link} -> {link.readlink()}')
PY
```

Replace `/ABSOLUTE/PATH/TO/REAL/AGENTS.md` with the real file found in Step 2.

Expected: the command prints the corrected symlink target and `link.exists()` is true afterward.

- [ ] **Step 3B: If no real intended target exists, remove the dangling symlink**

Use this when Step 2 found no real target:

```bash
python3 - <<'PY'
from pathlib import Path
link = Path.home() / '.config/opencode/AGENTS.md'
assert link.is_symlink(), link
assert not link.exists(), link
link.unlink()
print(f'removed dangling symlink: {link}')
PY
```

Expected:

```text
removed dangling symlink: /Users/haru256/.config/opencode/AGENTS.md
```

- [ ] **Step 4: Verify no dangling symlink remains**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path.home() / '.config/opencode/AGENTS.md'
if p.is_symlink():
    assert p.exists(), f'dangling symlink remains: {p} -> {p.readlink()}'
    print(f'valid symlink: {p} -> {p.readlink()}')
elif p.exists():
    print(f'real file exists: {p}')
else:
    print(f'no AGENTS.md entry at {p}')
PY
```

Expected: one of these valid outcomes prints:

```text
valid symlink: /Users/haru256/.config/opencode/AGENTS.md -> <real target>
```

or:

```text
no AGENTS.md entry at /Users/haru256/.config/opencode/AGENTS.md
```

## Task 4: Final verification

**Files:**
- Read: `.config/opencode/prompts/orchestrator.md`
- Read: `.config/opencode/CONTEXT.md`
- Read: `.config/opencode/opencode.json`

- [ ] **Step 1: Verify the requested behavior and non-goals**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
orch = Path('.config/opencode/prompts/orchestrator.md').read_text()
ctx = Path('.config/opencode/CONTEXT.md').read_text()
cfg = Path('.config/opencode/opencode.json').read_text()
assert 'Subagent Session Reuse Policy' in orch
assert 'Prefer reusing a specialist subagent session' in orch
assert 'Prefer a fresh specialist subagent' in orch
assert 'orchestrator_v2' not in ctx
assert 'oracle_v2' not in ctx
assert 'domain-context document' in ctx
assert '"reasoningEffort": "xhigh"' in cfg
print('requested changes verified')
PY
```

Expected:

```text
requested changes verified
```

- [ ] **Step 2: Inspect git diff**

Run:

```bash
git diff -- .config/opencode/prompts/orchestrator.md .config/opencode/CONTEXT.md docs/superpowers/specs/2026-05-23-opencode-subagent-reuse-design.md docs/superpowers/plans/2026-05-23-opencode-subagent-reuse.md
```

Expected: diff only contains the reuse policy, `CONTEXT.md` wording/name updates, and the design/plan docs.

- [ ] **Step 3: Restart note**

Tell the user:

```text
opencode loads config and prompts at startup. Quit and restart opencode for prompt/config-time file changes to take effect.
```

## Implementation Log
<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N -> STATUS | commit-or-failure-signature -->

- [2026-05-23] attempt #1 -> DONE | no commit per instructions

## Review Findings
<!-- This template is also defined in commands/plan.md. Keep them in sync on every edit. -->

### Reviewer Raw Findings
<!-- Orchestrator copies @reviewer's structured findings verbatim here when invoking @reviewer during a workflow. Direct /review-* calls do not write here. Raw findings are review input, not implementation instructions. -->

#### [2026-05-23] implementation -> APPROVE
[2026-05-23] implementation -> APPROVE | no findings

### Orchestrator Adjudication
<!-- Orchestrator appends adjudication tables for workflow reviews. Only ACCEPT rows are implementation instructions: | ID | Severity | Decision | Reason | Action | -->

## Deviations from Plan
<!-- Implementer documents intentional deviations and reasons. -->

- Task 3 (AGENTS.md symlink): The plan assumed the symlink at `~/.config/opencode/AGENTS.md` was dangling. Inspection found it already points to a real file (`/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md`, exists=True, is_symlink=False). No retargeting or removal was needed; the symlink is valid and satisfies the acceptance criterion.

## Open Questions
<!-- Any agent adds questions for orchestrator or oracle. -->

- [resolved] [2026-05-23] `AGENTS.md` symlink inspection found a valid target; no action needed.
