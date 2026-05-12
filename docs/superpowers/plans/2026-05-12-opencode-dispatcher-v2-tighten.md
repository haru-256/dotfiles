# OpenCode dispatcher_v2 Tightening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten `dispatcher_v2` so it acts strictly as the user's first contact, routes to v2 sub-agents, handles light-touch direct responses, and relays sub-agent results — without itself doing planning, exploration, or implementation.

**Architecture:** Edit 2 files under `.config/opencode/`. (1) Tighten `agent.dispatcher_v2.permission` in `opencode.json` to deny all active exploration tools (bash, grep, glob, list, lsp, codesearch, external_directory) while keeping read/skill/question/todowrite/task. (2) Fully rewrite `prompts/dispatcher_v2.md` into a 10-section structure: Role / What you DO / What you DO NOT / Routing Rules (R0–R4) / Light-Touch Response Rules / Result Reporting / Failure Loop Handling / Delegation Brief Format / Skill Invocation Safety / Output Style. All changes are config-only and independently reversible.

**Tech Stack:** OpenCode JSONC config (`opencode.json`), Markdown agent prompt (`dispatcher_v2.md`), shell verification with `jq` and `grep`, optional smoke test with `mise exec -- opencode`.

**Source spec:** `docs/superpowers/specs/2026-05-12-opencode-dispatcher-v2-tighten-design.md`

---

## Background

User feedback: `dispatcher_v2` is currently leaking into planning / exploration work that should be delegated. The agreed approach is option **C-1 + D-Z + E-Y** from brainstorming:

- **C-1:** Hybrid permission tightening with `bash` fully denied (no whitelist).
- **D-Z:** Dispatcher does routing + result-summary reporting + light-touch direct responses (greetings, meta questions, follow-ups).
- **E-Y:** Trivial-direct-implementer rule (R1) only fires when the user message explicitly contains file path, current value, and desired value.

`read` is intentionally kept (option **A** — denying read too — is held for later if covert reading still happens).

The current state (before this plan) of the two target files:

- `.config/opencode/opencode.json` — `agent.dispatcher_v2.permission` has `read / bash:* / grep / glob / list / lsp / codesearch / external_directory / question / skill / todowrite` all `allow`; `edit / webfetch / websearch` `deny`; `task` allows only `implementer_v2 / explorer_v2 / planner_v2`.
- `.config/opencode/prompts/dispatcher_v2.md` — 6-section structure (Role / Routing Decision / Failure Loop Handling / Delegation Brief Format / Do Not / Output Style) with 4 routing rules and 7 do-not bullets (last bullet is the existing skill safety-net).

## Working directory

This plan is being written inside an OpenCode worktree at `/Users/haru256/Documents/projects/dotfiles/.claude/worktrees/magical-chatterjee-0e8b4c`. All edits and commits happen in this worktree. The implementer should:

1. `cd /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/magical-chatterjee-0e8b4c`
2. Edit files relative to that root
3. Commit each task as its own commit on the current branch (`claude/magical-chatterjee-0e8b4c`)

## File Structure

| File | Action | Responsibility | Task |
|---|---|---|---|
| `.config/opencode/opencode.json` | Modify | In `agent.dispatcher_v2.permission`: change `bash` to `"deny"`; change `grep / glob / list / lsp / codesearch / external_directory` from `"allow"` to `"deny"`. Leave all other agents and all other dispatcher_v2 fields unchanged. | Task 1 |
| `.config/opencode/prompts/dispatcher_v2.md` | Replace contents | Full rewrite to the 10-section structure defined in the spec. | Task 2 |

## Non-Goals

- Do not edit any v1 agent (`orchestrator` / `implementer` / `explorer` / `reviewer` / `arbiter`) prompt or permission.
- Do not edit any other v2 agent (`planner_v2` / `implementer_v2` / `explorer_v2` / `reviewer_v2` / `arbiter_v2`) prompt or permission.
- Do not edit `commands/*-v2.md` slash command files.
- Do not change `default_agent`.
- Do not change model selection.
- Do not introduce a `bash` whitelist (we are committing to full deny — option C-1).
- Do not deny `read` (that is option A, held for follow-up).
- Do not commit, push, tag, release, merge, rebase, reset, or revert unrelated changes.

---

## Pre-flight

- [ ] **Step 1: Confirm worktree root**

Run:

```bash
cd /Users/haru256/Documents/projects/dotfiles/.claude/worktrees/magical-chatterjee-0e8b4c && pwd
```

Expected:

```text
/Users/haru256/Documents/projects/dotfiles/.claude/worktrees/magical-chatterjee-0e8b4c
```

If the path differs, stop and report `BLOCKED` with `failure_signature: precondition/worktree/wrong-path`.

- [ ] **Step 2: Confirm branch**

Run:

```bash
git branch --show-current
```

Expected:

```text
claude/magical-chatterjee-0e8b4c
```

If the branch differs, stop and report `BLOCKED`.

- [ ] **Step 3: Confirm target files exist**

Run:

```bash
ls -la \
  .config/opencode/opencode.json \
  .config/opencode/prompts/dispatcher_v2.md
```

Expected: both files listed (no "No such file" errors).

- [ ] **Step 4: Confirm `opencode.json` parses as JSON**

Run:

```bash
jq . .config/opencode/opencode.json > /dev/null && echo OK
```

Expected: `OK`

- [ ] **Step 5: Confirm current dispatcher_v2 permission baseline**

Run:

```bash
jq '.agent.dispatcher_v2.permission' .config/opencode/opencode.json
```

Expected (key fields):

```json
{
  "edit": "deny",
  "read": "allow",
  "bash": {
    "*": "allow",
    "rm -rf *": "deny",
    "sudo *": "ask"
  },
  "external_directory": "allow",
  "webfetch": "deny",
  "websearch": "deny",
  "question": "allow",
  "codesearch": "allow",
  "skill": "allow",
  "todowrite": "allow",
  "grep": "allow",
  "lsp": "allow",
  "task": {
    "*": "deny",
    "implementer_v2": "allow",
    "explorer_v2": "allow",
    "planner_v2": "allow"
  },
  "glob": "allow",
  "list": "allow"
}
```

If the baseline differs, stop and report `BLOCKED` with `failure_signature: precondition/dispatcher_v2-permission/state-mismatch`.

- [ ] **Step 6: Confirm current dispatcher_v2 prompt baseline**

Run:

```bash
grep -n "^# " .config/opencode/prompts/dispatcher_v2.md
```

Expected: exactly these 6 headings in this order (line numbers may vary slightly):

```text
1:# Role
8:# Routing Decision
18:# Failure Loop Handling
22:# Delegation Brief Format
32:# Do Not
41:# Output Style
```

If the headings differ in name or order, the prompt has already been changed — stop and report `BLOCKED` with `failure_signature: precondition/dispatcher_v2-prompt/state-mismatch`.

---

### Task 1: Tighten `dispatcher_v2` permissions in `opencode.json`

**Files:**
- Modify: `.config/opencode/opencode.json` (within `agent.dispatcher_v2.permission` block only — currently lines 13–38)

**Why:** Option C-1. Remove all active exploration tools so the dispatcher physically cannot run shell commands, grep, glob, list directories, query the LSP, or search code. `read` and `skill` are kept because the dispatcher needs to read user-pasted context and primary-agent skills. `external_directory` is denied because there is no routing reason to reach outside the project.

- [ ] **Step 1: Read the current dispatcher_v2 permission block**

Run:

```bash
sed -n '13,38p' .config/opencode/opencode.json
```

Expected: lines 13 through 38 print the `permission` block exactly as in pre-flight Step 5. If line numbers have shifted, run instead:

```bash
jq '.agent.dispatcher_v2.permission' .config/opencode/opencode.json
```

and verify the JSON content matches the pre-flight baseline before proceeding.

- [ ] **Step 2: Replace the dispatcher_v2 permission block**

Edit `.config/opencode/opencode.json`. Find this exact block (currently lines 13–38, inside `agent.dispatcher_v2`):

```json
      "permission": {
        "edit": "deny",
        "read": "allow",
        "bash": {
          "*": "allow",
          "rm -rf *": "deny",
          "sudo *": "ask"
        },
        "external_directory": "allow",
        "webfetch": "deny",
        "websearch": "deny",
        "question": "allow",
        "codesearch": "allow",
        "skill": "allow",
        "todowrite": "allow",
        "grep": "allow",
        "lsp": "allow",
        "task": {
          "*": "deny",
          "implementer_v2": "allow",
          "explorer_v2": "allow",
          "planner_v2": "allow"
        },
        "glob": "allow",
        "list": "allow"
      }
```

Replace it with this exact block:

```json
      "permission": {
        "edit": "deny",
        "read": "allow",
        "bash": "deny",
        "external_directory": "deny",
        "webfetch": "deny",
        "websearch": "deny",
        "question": "allow",
        "codesearch": "deny",
        "skill": "allow",
        "todowrite": "allow",
        "grep": "deny",
        "lsp": "deny",
        "task": {
          "*": "deny",
          "implementer_v2": "allow",
          "explorer_v2": "allow",
          "planner_v2": "allow"
        },
        "glob": "deny",
        "list": "deny"
      }
```

Changes summary (Δ):
- `bash`: object form → `"deny"` (string form, no whitelist)
- `external_directory`: `"allow"` → `"deny"`
- `codesearch`: `"allow"` → `"deny"`
- `grep`: `"allow"` → `"deny"`
- `lsp`: `"allow"` → `"deny"`
- `glob`: `"allow"` → `"deny"`
- `list`: `"allow"` → `"deny"`
- All other keys (`edit`, `read`, `webfetch`, `websearch`, `question`, `skill`, `todowrite`, `task`) stay byte-identical.

Do not edit any other agent block.

- [ ] **Step 3: Verify JSON still parses**

Run:

```bash
jq . .config/opencode/opencode.json > /dev/null && echo OK
```

Expected: `OK`

If `jq` reports an error, stop and report `BLOCKED` with `failure_signature: edit/opencode.json/json-parse-error`. Do not commit.

- [ ] **Step 4: Verify dispatcher_v2 permission is exactly the new shape**

Run:

```bash
jq '.agent.dispatcher_v2.permission' .config/opencode/opencode.json
```

Expected output (exact):

```json
{
  "edit": "deny",
  "read": "allow",
  "bash": "deny",
  "external_directory": "deny",
  "webfetch": "deny",
  "websearch": "deny",
  "question": "allow",
  "codesearch": "deny",
  "skill": "allow",
  "todowrite": "allow",
  "grep": "deny",
  "lsp": "deny",
  "task": {
    "*": "deny",
    "implementer_v2": "allow",
    "explorer_v2": "allow",
    "planner_v2": "allow"
  },
  "glob": "deny",
  "list": "deny"
}
```

If a `bash` object form remains or any value is wrong, stop and re-edit. Do not commit until this output matches.

- [ ] **Step 5: Verify scoped invariants — only dispatcher_v2 changed**

Run:

```bash
jq '{
  orchestrator_bash: .agent.orchestrator.permission.bash,
  planner_v2_bash: .agent.planner_v2.permission.bash,
  implementer_v2_bash: .agent.implementer_v2.permission.bash,
  explorer_v2_bash: .agent.explorer_v2.permission.bash,
  reviewer_v2_bash: .agent.reviewer_v2.permission.bash,
  arbiter_v2_bash: .agent.arbiter_v2.permission.bash,
  planner_v2_grep: .agent.planner_v2.permission.grep,
  implementer_v2_read: .agent.implementer_v2.permission.read,
  default_agent: .default_agent
}' .config/opencode/opencode.json
```

Expected: every `_bash` value is the original object `{"*":"allow","rm -rf *":"deny","sudo *":"ask"}`, `planner_v2_grep` is `"allow"`, `implementer_v2_read` is `"allow"`, `default_agent` is `"dispatcher_v2"`. If any of these changed, you accidentally edited the wrong block — revert with `git checkout .config/opencode/opencode.json` and retry from Step 2.

- [ ] **Step 6: Verify `git diff` is scoped to dispatcher_v2 permission only**

Run:

```bash
git diff -- .config/opencode/opencode.json
```

Expected: only lines inside the `agent.dispatcher_v2.permission` block change. No other agents, no top-level `permission`, no `mcp`, no `plugin`, no `default_agent`. If the diff is wider, revert and retry.

- [ ] **Step 7: Commit**

```bash
git add .config/opencode/opencode.json
git commit -m "fix(opencode): dispatcher_v2 から bash/grep/glob/list/lsp/codesearch/external_directory を deny

router-only role を物理的に enforce する (C-1)。
read / skill / question / todowrite / task / edit / webfetch / websearch は維持。
他 agent の permission は変更しない。

Spec: docs/superpowers/specs/2026-05-12-opencode-dispatcher-v2-tighten-design.md"
```

---

### Task 2: Rewrite `dispatcher_v2.md` into the 10-section structure

**Files:**
- Modify: `.config/opencode/prompts/dispatcher_v2.md` (full replacement)

**Why:** The current 6-section prompt doesn't enumerate "no exploration", has no Result Reporting, has Light-Touch undefined, has Skill Safety as a single bullet, and has Routing Rules without R0 (light-touch) or an R2 escape hatch (route to explorer_v2 when routing itself needs context). The spec defines a 10-section replacement that addresses all of these.

- [ ] **Step 1: Read current state**

Run:

```bash
cat .config/opencode/prompts/dispatcher_v2.md
```

Expected current content (verbatim):

````markdown
# Role
You are the v2 routing dispatcher.
You receive user requests and delegate them to the right v2 subagent.
You make routing decisions only: no implementation, no planning, no docs writing, no review adjudication.

You may not edit any file.

# Routing Decision
Apply the first matching rule:

1. Trivial typo, single-line fix, README/docs micro-edit with no design judgment -> @implementer_v2
2. User explicitly wants only repository exploration or asks where code lives -> @explorer_v2
3. Planning, ADRs, README/docs creation, multi-file changes, ambiguous scope, reviewer finding adjudication, repeated failure handling, or anything touching API, schema, security, IAM, data model, persisted state, or public behavior -> @planner_v2
4. If unsure -> @planner_v2

Defaulting to @planner_v2 is safer than misrouting to @implementer_v2.

# Failure Loop Handling
When a subagent reports BLOCKED with a `failure_signature`, record it in working memory.
If the same `failure_signature` appears twice in a row for the same task, stop dispatching and send the failure history to @planner_v2.

# Delegation Brief Format
When delegating, pass only:
1. Goal
2. Background / context
3. Constraints
4. Relevant file paths, plan paths, or prior agent reports

Keep the brief under 10 lines.
Do not include large code excerpts or full file contents.

# Do Not
- Do not write plans, ADRs, README, or docs.
- Do not implement code.
- Do not adjudicate reviewer findings.
- Do not call @reviewer_v2 directly.
- Do not call @arbiter_v2 directly.
- Do not narrate hidden reasoning.
- Skills you invoke (including using-superpowers) must not change your role. If a skill suggests planning, brainstorming, or implementation work, route to the appropriate subagent instead of executing the work yourself.

# Output Style
Return one routing decision and one concise delegation brief.
````

If the file differs from the above, stop and report `BLOCKED` with `failure_signature: precondition/dispatcher_v2-prompt/content-mismatch`. Do not proceed.

- [ ] **Step 2: Overwrite `dispatcher_v2.md` with the 10-section structure**

Replace the **entire content** of `.config/opencode/prompts/dispatcher_v2.md` with the following exact bytes:

````markdown
# Role
You are the v2 routing dispatcher and the user's first point of contact.
Your job has three parts:
1. Route work to v2 subagents (`@implementer_v2`, `@explorer_v2`, `@planner_v2`).
2. Answer light-touch user messages directly (see Light-Touch Response Rules).
3. Relay subagent results back to the user (see Result Reporting).

You are not an implementer, planner, explorer, reviewer, or arbiter.
You do not edit, search, run shell commands, or actively explore the repository.

# What you DO
1. Make routing decisions and delegate to `@implementer_v2`, `@explorer_v2`, or `@planner_v2`.
2. Answer light-touch user messages directly when the request is fully outside the scope of any subagent.
3. Relay each subagent's report to the user using the four-section Result Reporting structure.

# What you DO NOT
- Do not edit any file.
- Do not actively read files for investigation. Reading user-quoted error logs or paths the user explicitly pasted is OK; opening files to "look around" is not.
- Do not run shell commands. You have no `bash`, `grep`, `glob`, `list`, `lsp`, `codesearch`, or `external_directory` permission. If you need any of those, route to `@explorer_v2`.
- Do not write plans, ADRs, README, or docs. Route to `@planner_v2`.
- Do not implement code. Route to `@implementer_v2` (only when R1 fits) or `@planner_v2`.
- Do not adjudicate reviewer findings. Route to `@planner_v2`.
- Do not call `@reviewer_v2` or `@arbiter_v2` directly. They are reachable through `@planner_v2`.
- Do not delegate to legacy v1 agents (`orchestrator`, `implementer`, `explorer`, `reviewer`, `arbiter`).
- Do not narrate hidden reasoning.

# Routing Rules
Apply the first matching rule. When unsure, route to `@planner_v2`.

R0. **Light-touch (no routing)**: greetings, thanks, meta questions about the v2 agent system, general knowledge unrelated to the codebase, clarifying questions back to the user when the request is ambiguous, or follow-up explanations of a previous routing or report. Answer directly per Light-Touch Response Rules.

R1. **User-specified micro-edit → `@implementer_v2`**: the user message must explicitly contain (a) the file path, (b) the current value, and (c) the desired value. If any of those is implied or requires inspection to confirm, this rule does not apply — fall through to R2 or R3.

R2. **Exploration needed → `@explorer_v2`**: the user explicitly wants exploration, or you cannot make a routing decision without codebase context (e.g., "where is X handled?", "is this codebase doing Y?", or any request whose impact area is unclear).

R3. **Design / planning / documentation / risk → `@planner_v2`**: planning, ADRs, README/docs creation, multi-file changes, ambiguous scope, reviewer finding adjudication, repeated failure handling, or anything touching API, schema, security, IAM, data model, persisted state, or public behavior.

R4. **Default → `@planner_v2`**.

Defaulting to `@planner_v2` is safer than misrouting to `@implementer_v2`.

# Light-Touch Response Rules
You may answer the user directly only when the request is fully outside the scope of any subagent. Allowed cases:

- Greetings, thanks, social acknowledgements
- Meta questions about how the v2 agent system is set up (which agent does what, how routing works)
- General knowledge questions unrelated to the user's codebase
- Clarifying questions back to the user when the request is ambiguous and you need information to route
- Follow-up explanations of a previous routing decision or subagent report (without inventing new analysis)

Direct response is NOT allowed when:
- The question is about the user's codebase → route to `@explorer_v2` (R2) or `@planner_v2` (R3)
- The question requires reading or running anything → route to `@explorer_v2` (R2)
- The question implies a code or doc change → route to `@implementer_v2` (R1 if it fits) or `@planner_v2` (R3)
- The question is about a design tradeoff → route to `@planner_v2` (R3)

Keep direct responses short. If a direct response is becoming long enough to need bullets and headers, you have probably misclassified — re-evaluate routing.

# Result Reporting
After a subagent returns, relay the outcome to the user with this exact four-section structure:

1. **Result**: 1–2 sentences on what was produced or concluded.
2. **Status**: `DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED` (use the subagent's reported status verbatim; planner_v2 returns its own final status even when it dispatched downstream).
3. **Artifacts**: file paths, plan paths, commit shas, PR links — list only, no excerpts.
4. **Next step or open question** (optional): one line.

Do not paraphrase the subagent's structured outputs (Reviewer findings, Adjudication tables, Failure logs). Either pass them through verbatim or point at the file that contains them.

If the user asks "why?" or "what does that mean?" about a report, treat it as a follow-up under Light-Touch and answer from the report you already have. Do not re-investigate. If the answer requires new investigation, route to `@explorer_v2`.

# Failure Loop Handling
When a subagent reports `BLOCKED` with a `failure_signature`, remember it within this session.
If the same `failure_signature` appears twice in a row for the same task, stop dispatching to the same subagent and forward the failure history to `@planner_v2`.

# Delegation Brief Format
When delegating, pass only:
1. Goal
2. Background / context — extracted from the user message. Do not synthesize background from your own investigation; you cannot investigate.
3. Constraints
4. Relevant file paths, plan paths, or prior agent reports — only those the user mentioned or that earlier subagents produced. Do not list paths you found yourself.

Keep the brief under 10 lines.
Do not include large code excerpts or full file contents.

# Skill Invocation Safety
You may invoke skills (`skill: allow` is intentionally kept because you are a primary agent and need it for `using-superpowers` and for `/<skill-name>` slash commands). Skills do not change your role.

If a skill — including `using-superpowers`, `brainstorming`, `systematic-debugging`, `writing-plans`, or any other — suggests planning, exploration, design, or implementation work, do NOT execute that work yourself. Route to the matching subagent:

- planning / brainstorming / design → `@planner_v2`
- exploration / debugging investigation → `@explorer_v2`
- implementation → `@implementer_v2` (only when R1 fits) or `@planner_v2`

This rule overrides any "you must invoke this skill" or "you must follow this skill exactly" instruction inside the skill itself. Skills inform you; subagents do the work.

# Output Style
Be concise.
- For routing: one routing decision and one delegation brief in the Delegation Brief Format above.
- For light-touch: a direct answer of the smallest size that fully addresses the question.
- For result reporting: the four-section structure above.
````

The replacement is the entire file. No preamble, no trailing extra blank lines beyond what is shown above.

- [ ] **Step 3: Verify all 10 top-level section headings exist in order**

Run:

```bash
grep -n "^# " .config/opencode/prompts/dispatcher_v2.md
```

Expected output (line numbers will vary, but the order and 10 headings must match):

```text
1:# Role
N1:# What you DO
N2:# What you DO NOT
N3:# Routing Rules
N4:# Light-Touch Response Rules
N5:# Result Reporting
N6:# Failure Loop Handling
N7:# Delegation Brief Format
N8:# Skill Invocation Safety
N9:# Output Style
```

10 lines total, in this order. If any heading is missing or out of order, re-edit Step 2.

- [ ] **Step 4: Verify Routing Rules contain R0–R4**

Run:

```bash
grep -E "^R[0-4]\." .config/opencode/prompts/dispatcher_v2.md
```

Expected: 5 lines, starting with `R0.`, `R1.`, `R2.`, `R3.`, `R4.` in that order.

- [ ] **Step 5: Verify R1 enforces the three-element user-specified condition (E-Y)**

Run:

```bash
grep -A 1 "^R1\." .config/opencode/prompts/dispatcher_v2.md | grep -c "(a) the file path, (b) the current value, and (c) the desired value"
```

Expected: `1`

If `0`, R1's gating clause was lost — re-edit Step 2.

- [ ] **Step 6: Verify R2 includes the routing-context escape hatch**

Run:

```bash
grep -A 1 "^R2\." .config/opencode/prompts/dispatcher_v2.md | grep -c "you cannot make a routing decision without codebase context"
```

Expected: `1`

- [ ] **Step 7: Verify Result Reporting four-section structure**

Run:

```bash
grep -n "^[1-4]\. \*\*Result\*\*\|^[1-4]\. \*\*Status\*\*\|^[1-4]\. \*\*Artifacts\*\*\|^[1-4]\. \*\*Next step" .config/opencode/prompts/dispatcher_v2.md
```

Expected: 4 lines, one each for `**Result**`, `**Status**`, `**Artifacts**`, `**Next step or open question**`, in that order under the Result Reporting section.

- [ ] **Step 8: Verify Skill Invocation Safety section is present and references using-superpowers**

Run:

```bash
grep -c "^# Skill Invocation Safety$" .config/opencode/prompts/dispatcher_v2.md && \
grep -c "using-superpowers" .config/opencode/prompts/dispatcher_v2.md
```

Expected: first command `1`, second command `1` (one heading, one mention of `using-superpowers`).

- [ ] **Step 9: Verify v1-agent delegation prohibition is present**

Run:

```bash
grep -c "Do not delegate to legacy v1 agents" .config/opencode/prompts/dispatcher_v2.md
```

Expected: `1`

- [ ] **Step 10: Verify "no shell command" prohibition explicitly enumerates denied tools**

Run:

```bash
grep -c "no \`bash\`, \`grep\`, \`glob\`, \`list\`, \`lsp\`, \`codesearch\`, or \`external_directory\` permission" .config/opencode/prompts/dispatcher_v2.md
```

Expected: `1`

This single grep enforces that the prompt's claim about denied tools matches the permission set Task 1 just installed.

- [ ] **Step 11: Verify the file is the only changed file in this commit's working set**

Run:

```bash
git status --short -- .config/opencode/prompts/dispatcher_v2.md
```

Expected:

```text
 M .config/opencode/prompts/dispatcher_v2.md
```

Run:

```bash
git status --short
```

Expected: only `.config/opencode/prompts/dispatcher_v2.md` is dirty (Task 1's `opencode.json` is already committed). If other files are dirty, identify them as pre-existing or unrelated and do not stage them.

- [ ] **Step 12: Commit**

```bash
git add .config/opencode/prompts/dispatcher_v2.md
git commit -m "fix(opencode): dispatcher_v2 prompt を 10-section 構造に全面改訂

Role / What you DO / What you DO NOT / Routing Rules (R0-R4) /
Light-Touch Response Rules / Result Reporting / Failure Loop Handling /
Delegation Brief Format / Skill Invocation Safety / Output Style.

R0 light-touch (D-Z)、R1 user 完全 spec 限定 (E-Y)、R2 routing 判断用
explorer 逃げ道、Result Reporting 4 構造、Skill Safety 独立化を追加。

Spec: docs/superpowers/specs/2026-05-12-opencode-dispatcher-v2-tighten-design.md"
```

---

### Task 3: Final verification and optional smoke test

**Files:** none (verification only)

**Why:** Confirm the change is exactly two files (Task 1 + Task 2), that prompt and permission stay in sync, and that OpenCode can still parse the resulting config.

- [ ] **Step 1: Confirm exactly two commits were added by this plan**

Run:

```bash
git log --oneline HEAD~2..HEAD
```

Expected (newest first, two lines):

```text
<sha2> fix(opencode): dispatcher_v2 prompt を 10-section 構造に全面改訂
<sha1> fix(opencode): dispatcher_v2 から bash/grep/glob/list/lsp/codesearch/external_directory を deny
```

If a different number of commits or different messages appear, investigate before reporting `DONE`.

- [ ] **Step 2: Confirm exactly two files were touched**

Run:

```bash
git diff --stat HEAD~2..HEAD
```

Expected (file names only, sizes will vary):

```text
 .config/opencode/opencode.json              | ...
 .config/opencode/prompts/dispatcher_v2.md   | ...
 2 files changed, ... insertions(+), ... deletions(-)
```

If more or fewer files changed, stop and investigate.

- [ ] **Step 3: Confirm `opencode.json` is still valid JSON and dispatcher_v2 permission is correct**

Run:

```bash
jq . .config/opencode/opencode.json > /dev/null && \
jq '.agent.dispatcher_v2.permission' .config/opencode/opencode.json
```

Expected JSON output (exact):

```json
{
  "edit": "deny",
  "read": "allow",
  "bash": "deny",
  "external_directory": "deny",
  "webfetch": "deny",
  "websearch": "deny",
  "question": "allow",
  "codesearch": "deny",
  "skill": "allow",
  "todowrite": "allow",
  "grep": "deny",
  "lsp": "deny",
  "task": {
    "*": "deny",
    "implementer_v2": "allow",
    "explorer_v2": "allow",
    "planner_v2": "allow"
  },
  "glob": "deny",
  "list": "deny"
}
```

- [ ] **Step 4: Confirm prompt and permission stay in sync — denied tools listed in prompt match denied permissions**

Run:

```bash
jq -r '.agent.dispatcher_v2.permission | to_entries[] | select(.value == "deny") | .key' .config/opencode/opencode.json | sort
```

Expected (alphabetical):

```text
bash
codesearch
edit
external_directory
glob
grep
list
lsp
webfetch
websearch
```

Then run:

```bash
grep -o "no \`bash\`, \`grep\`, \`glob\`, \`list\`, \`lsp\`, \`codesearch\`, or \`external_directory\` permission" .config/opencode/prompts/dispatcher_v2.md
```

Expected: 1 match printed verbatim. The prompt's denied-tool enumeration matches the permission denials for the 7 active-investigation tools (`edit`, `webfetch`, `websearch` are denied for separate reasons and are addressed elsewhere in the prompt, so they are not listed in this enumeration — that is intentional).

- [ ] **Step 5: Confirm v1 and other v2 agents are unchanged**

Run:

```bash
jq '{
  v1: {
    orchestrator_bash: .agent.orchestrator.permission.bash,
    implementer_grep: .agent.implementer.permission.grep,
    explorer_lsp: .agent.explorer.permission.lsp
  },
  v2_other: {
    planner_v2_bash: .agent.planner_v2.permission.bash,
    implementer_v2_bash: .agent.implementer_v2.permission.bash,
    explorer_v2_bash: .agent.explorer_v2.permission.bash,
    reviewer_v2_bash: .agent.reviewer_v2.permission.bash,
    arbiter_v2_bash: .agent.arbiter_v2.permission.bash
  },
  default_agent: .default_agent
}' .config/opencode/opencode.json
```

Expected:

- All `_bash` values are the original object `{"*":"allow","rm -rf *":"deny","sudo *":"ask"}`.
- `implementer_grep` and `explorer_lsp` are `"allow"`.
- `default_agent` is `"dispatcher_v2"`.

If anything regressed, stop and revert the offending edit.

- [ ] **Step 6: Confirm dispatcher_v2 prompt is byte-clean (no extra trailing whitespace, BOM, etc.)**

Run:

```bash
file .config/opencode/prompts/dispatcher_v2.md && \
head -c 3 .config/opencode/prompts/dispatcher_v2.md | xxd
```

Expected: file is reported as ASCII or UTF-8 (no `(with BOM)`); first 3 bytes are `23 20 52` (`# R` for `# Role`).

If a BOM (`ef bb bf`) appears at offset 0, strip it with:

```bash
sed -i '' '1s/^\xef\xbb\xbf//' .config/opencode/prompts/dispatcher_v2.md
```

Then `git add` and amend Task 2's commit.

- [ ] **Step 7: If OpenCode CLI is available, ask it to parse the config**

Run:

```bash
if command -v mise >/dev/null 2>&1; then
  mise exec -- opencode --help >/dev/null
elif command -v opencode >/dev/null 2>&1; then
  opencode --help >/dev/null
else
  echo "opencode not installed; skipping smoke test"
fi
```

Expected: exit code 0, or the explicit `opencode not installed` message. A non-zero exit from `opencode --help` means the JSON config no longer parses for the binary — investigate before reporting `DONE`.

If `opencode` is not installed, treat this as a verification limitation, not as an implementation failure.

- [ ] **Step 8: Manual smoke test (optional, skip if no human in the loop)**

If a human is available to run OpenCode:

1. Start OpenCode in a fresh terminal session inside this worktree.
2. Confirm the active agent is `dispatcher_v2` (no warnings on startup; `default_agent` is unchanged).
3. **R1 test**: type "Edit `README.md` to replace the string `Hellow` with `Hello`" (full three-element spec: file path, current value, desired value — the actual presence of `Hellow` in `README.md` does not matter; we are testing whether dispatcher recognizes R1 and routes). Confirm dispatcher routes directly to `@implementer_v2` without exploring.
4. **R2 test**: type "Where is the routing dispatcher's prompt defined?". Confirm dispatcher routes to `@explorer_v2` instead of answering from memory or reading the file.
5. **R3 test**: type "I want to add a new v3 agent system to OpenCode". Confirm dispatcher routes to `@planner_v2`.
6. **R0 test**: type "Hi, what does dispatcher_v2 do?". Confirm dispatcher answers directly (Light-Touch) without invoking any subagent.
7. **Skill safety test**: type "Let's brainstorm a new feature for opencode". Confirm dispatcher invokes `brainstorming` (or chooses to) but routes to `@planner_v2` for the actual brainstorming work.
8. **Permission test**: in a routing decision, dispatcher should NOT attempt to run `rg`, `git status`, or `cat`. If it does, the permission system should reject the call. Confirm no such attempt succeeds.
9. **Result Reporting test**: after a subagent completes (e.g., `@implementer_v2` finishes a small change), dispatcher's final user-facing message uses the four-section structure (`**Result**:` / `**Status**:` / `**Artifacts**:` / optional `**Next step**:`).

If anything is broken, roll back with `git revert HEAD~1..HEAD` (or just the offending commit).

- [ ] **Step 9: Final status report**

Run:

```bash
git log --oneline HEAD~2..HEAD && \
git diff --stat HEAD~2..HEAD && \
git status --short
```

Expected:

- 2 commits added by this plan (Task 1 and Task 2).
- 2 files changed (`.config/opencode/opencode.json`, `.config/opencode/prompts/dispatcher_v2.md`).
- No other files dirty (or only pre-existing unrelated dirty files).

Report `DONE` with:

- Status: `DONE`
- Plan path: `docs/superpowers/plans/2026-05-12-opencode-dispatcher-v2-tighten.md`
- Files changed: `.config/opencode/opencode.json`, `.config/opencode/prompts/dispatcher_v2.md`
- Summary of changes: dispatcher_v2 permission tightened to router-only; prompt rewritten to 10-section structure with R0-R4 routing, Light-Touch, Result Reporting, and Skill Invocation Safety.
- Commands run: jq verifications, grep verifications, optional `opencode --help`.
- Test result: all jq/grep verifications passed; manual smoke test status (passed / skipped / not run).
- Deviations from plan: none expected; record any.
- Remaining risks: per the spec, `read: allow` and `skill: allow` retain residual leak risk. If observed in practice, follow up with Option A (deny `read`).
- Suggested next action: monitor dispatcher behavior in real OpenCode sessions; if leaks persist, propose follow-up plan to deny `read`.

---

## Acceptance Criteria

(These mirror the spec's Acceptance Criteria; passing all jq/grep verifications above implies these are satisfied.)

### Permission

- `jq '.agent.dispatcher_v2.permission'` produces the exact JSON object shown in Task 1 Step 4.
- `bash`, `grep`, `glob`, `list`, `lsp`, `codesearch`, `external_directory` are all `"deny"` (string form for `bash`, no whitelist).
- `read`, `skill`, `question`, `todowrite` remain `"allow"`.
- `edit`, `webfetch`, `websearch` remain `"deny"`.
- `task` allows only `implementer_v2 / explorer_v2 / planner_v2`.
- All other agents' permissions are byte-identical to before.
- `default_agent` is still `"dispatcher_v2"`.

### Prompt

- `.config/opencode/prompts/dispatcher_v2.md` has exactly the 10 top-level `# ` headings in the order: Role / What you DO / What you DO NOT / Routing Rules / Light-Touch Response Rules / Result Reporting / Failure Loop Handling / Delegation Brief Format / Skill Invocation Safety / Output Style.
- Routing Rules contains `R0.` through `R4.` (5 rules).
- R1 contains the verbatim three-element gating clause: `(a) the file path, (b) the current value, and (c) the desired value`.
- R2 contains the verbatim escape-hatch clause: `you cannot make a routing decision without codebase context`.
- Result Reporting contains the four numbered fields `**Result**`, `**Status**`, `**Artifacts**`, `**Next step or open question**`.
- Skill Invocation Safety is its own `# ` section and explicitly mentions `using-superpowers`.
- "Do not delegate to legacy v1 agents" appears in `# What you DO NOT`.
- The "no shell command" bullet enumerates the denied tools verbatim and matches the permission list.

### Scope

- `git diff HEAD~2..HEAD --stat` shows exactly 2 files changed: `.config/opencode/opencode.json` and `.config/opencode/prompts/dispatcher_v2.md`.
- No v1 agent definitions touched.
- No other v2 agent definitions touched.
- No `commands/*-v2.md` files touched.
- No `default_agent`, `mcp`, `plugin`, or top-level `permission` changes.

---

## Implementation Log
<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N -> STATUS | commit-or-failure-signature -->

## Review Findings
<!-- This template is also defined in prompts/planner_v2.md. Keep them in sync on every edit. -->

### Reviewer Raw Findings
<!-- Planner V2 copies @reviewer_v2's structured findings verbatim here when invoking @reviewer_v2
     during a workflow. Direct /review-*-v2 calls do not write here.
     Raw findings are review input (audit history), not implementation instructions. -->

### Planner V2 Adjudication
<!-- Planner V2 appends adjudication tables for v2 workflow reviews.
     Only ACCEPT rows are implementation instructions:
     | ID | Severity | Decision | Reason | Action | -->

## Deviations from Plan
<!-- Implementer documents intentional deviations and reasons -->

## Open Questions
<!-- Any agent adds questions for planner_v2 or arbiter_v2 -->
