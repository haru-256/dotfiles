# OpenCode V2 Default Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make OpenCode use the v2 agent island by default while keeping all v1 agents available for backward compatibility.

**Architecture:** Keep the existing v1 custom agents in `opencode.json` unchanged, but switch `default_agent` to the v2 routing front door, `dispatcher_v2`. Update global AGENTS guidance so routine OpenCode orchestration points to `dispatcher_v2`, `planner_v2`, `explorer_v2`, `implementer_v2`, `reviewer_v2`, and `arbiter_v2`; do not introduce Pi-style names such as `scout`, `worker`, or `oracle`.

**Tech Stack:** OpenCode JSONC config, OpenCode custom agents, Markdown AGENTS instructions, shell validation with `mise exec -- opencode` when available.

---

## Background

The repository currently has two OpenCode agent generations configured in `.config/opencode/opencode.json`:

- v1 public agents: `orchestrator`, `implementer`, `explorer`, `reviewer`, `arbiter`
- v2 hidden agents: `dispatcher_v2`, `planner_v2`, `implementer_v2`, `explorer_v2`, `reviewer_v2`, `arbiter_v2`

The current default is:

```jsonc
"default_agent": "orchestrator"
```

The requested behavior is:

- Keep v1 agents in the config.
- Do not rename v2 agents to Pi-native names.
- Make the normal OpenCode entrypoint reference v2.
- Update AGENTS.md so future agents know to use v2 by default.

`dispatcher_v2` currently uses:

```jsonc
"model": "opencode-go/deepseek-v4-pro"
```

OpenCode does not appear to provide native first-class fallback model configuration in the official config docs. Fallback plugins exist, but fallback model setup is out of scope for this plan.

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `/Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json` | Modify | Change only `default_agent` from `orchestrator` to `dispatcher_v2`; keep v1 and v2 agent definitions intact. |
| `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md` | Modify | Update the OpenCode Balanced Workflow section to state that v2 is the normal OpenCode path while v1 agents remain compatibility/manual agents. |

## Non-Goals

- Do not delete or rename v1 agents.
- Do not add `scout`, `worker`, `oracle`, or other Pi-style OpenCode aliases.
- Do not change model selections, including `dispatcher_v2`'s `opencode-go/deepseek-v4-pro` model.
- Do not add fallback model plugins or `fallback_models` fields.
- Do not change Pi settings or Pi workflow rules.
- Do not rewrite v2 prompts beyond what is required by this plan.
- Do not commit, push, tag, release, merge, rebase, reset, or revert unrelated user changes unless explicitly requested.

## Pre-flight

- [ ] **Step 1: Capture working tree state**

Run:

```bash
git status --short
```

Expected: Existing unrelated dirty files may be present. At the time this plan was written, known dirty paths included `.agents/AGENTS.md`, `.codex/config.toml`, `.config/mise/config.toml`, `.config/opencode/opencode.json`, `.config/zed/prompts/prompts-library-db.0.mdb/lock.mdb`, `.claude/worktrees/hopeful-spence-92f5cb/`, `.pi/`, and `docs/superpowers/plans/2026-05-11-pi-native-orchestration.md`. Do not revert unrelated changes.

- [ ] **Step 2: Confirm current default agent and v2 dispatcher model**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path('/Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json')
text = p.read_text()
for needle in ['"default_agent": "orchestrator"', '"dispatcher_v2"', '"model": "opencode-go/deepseek-v4-pro"']:
    if needle not in text:
        raise SystemExit(f'missing expected text: {needle}')
print('expected OpenCode v2 baseline present')
PY
```

Expected output:

```text
expected OpenCode v2 baseline present
```

If the default agent is already `dispatcher_v2`, continue and make only the AGENTS.md update.

---

### Task 1: Switch OpenCode Default Agent To V2 Dispatcher

**Files:**
- Modify: `/Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json`

**Why:** This makes ordinary OpenCode sessions enter the v2 routing island by default, without removing the v1 compatibility agents.

- [ ] **Step 1: Read the top of the config**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path('/Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json')
for i, line in enumerate(p.read_text().splitlines()[:16], 1):
    print(f'{i}: {line}')
PY
```

Expected: line 3 is currently either `"default_agent": "orchestrator",` or has already been changed to `"default_agent": "dispatcher_v2",`.

- [ ] **Step 2: Change only the default agent value**

Replace this exact line:

```jsonc
  "default_agent": "orchestrator",
```

with:

```jsonc
  "default_agent": "dispatcher_v2",
```

Do not edit any v1 agent definitions. Do not remove `orchestrator`, `implementer`, `explorer`, `reviewer`, or `arbiter`.

- [ ] **Step 3: Verify v1 and v2 agent keys still exist**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
text = Path('/Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json').read_text()
required = [
    '"default_agent": "dispatcher_v2"',
    '"orchestrator"',
    '"implementer"',
    '"explorer"',
    '"reviewer"',
    '"arbiter"',
    '"dispatcher_v2"',
    '"planner_v2"',
    '"implementer_v2"',
    '"explorer_v2"',
    '"reviewer_v2"',
    '"arbiter_v2"',
]
missing = [item for item in required if item not in text]
if missing:
    raise SystemExit('missing expected config entries: ' + ', '.join(missing))
print('default uses dispatcher_v2 and both v1/v2 agent keys remain')
PY
```

Expected output:

```text
default uses dispatcher_v2 and both v1/v2 agent keys remain
```

---

### Task 2: Update OpenCode Workflow Guidance In AGENTS.md

**Files:**
- Modify: `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md`

**Why:** The global agent instructions currently describe v1 as the normal OpenCode workflow. They must tell future sessions to route normal OpenCode work through v2 while preserving v1 as compatibility/manual agents.

- [ ] **Step 1: Read the current OpenCode Balanced Workflow section**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path('/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md')
lines = p.read_text().splitlines()
for start, line in enumerate(lines):
    if line == '## OpenCode Balanced Workflow':
        break
else:
    raise SystemExit('OpenCode Balanced Workflow section not found')
for i in range(start, min(start + 38, len(lines))):
    print(f'{i + 1}: {lines[i]}')
PY
```

Expected: the section currently says the normal entrypoint is `orchestrator` and routes to `@implementer`, `@explorer`, `@reviewer`, and `@arbiter`.

- [ ] **Step 2: Replace the OpenCode Balanced Workflow section body**

Replace only the content from immediately after `## OpenCode Balanced Workflow` through the paragraph ending with `**\`@arbiter\` は常用しない。** 同じ問題で2回相談しても解決しない場合は、人間にエスカレートする。`.

Keep the `## OpenCode Balanced Workflow` heading and the following `---` separator in place.

Use this exact replacement body:

```md

OpenCode の通常入口は `dispatcher_v2` を使う。v1 agent（`orchestrator` / `implementer` / `explorer` / `reviewer` / `arbiter`）は互換用・手動呼び出し用として残すが、通常の新規作業では v2 agent を優先する。

**v2 ルーティング方針:**
- typo・1行修正・README/docs micro-edit → `@implementer_v2` 直行
- どこを触るか不明、または調査だけが目的 → `@explorer_v2` で調査してから判断
- 中規模以上の機能、複数ファイル変更、設計判断、plan / ADR / README / docs 作成 → `@planner_v2` 経由で探索・計画・実装・レビューを調整
- 意味のある成果物のレビュー → `@reviewer_v2`（`/review-plan-v2`, `/review-impl-v2`, `/review-adr-v2`, `/review-docs-v2` を使って ARTIFACT_TYPE を指定）
- `@implementer_v2` が同じ失敗を2回繰り返した → `@planner_v2` に failure history を渡し、必要なら `@arbiter_v2` 相談をユーザーに確認する
- `@dispatcher_v2` は routing-only front door とし、実装・計画・レビュー・adjudication は担当しない

**v2 Reviewer findings の取り扱い:**
- `@reviewer_v2` は構造化 findings を inline で返すのみ。plan には書き込まない（**単一書き込み主体: planner_v2 のみ**）。
- `@planner_v2` は workflow 内で `@reviewer_v2` を呼んだ場合、受け取った findings を verbatim で plan の `Review Findings > Reviewer Raw Findings` に転記する。
- 続けて `@planner_v2` は raw findings を `ACCEPT / REJECT / DEFER / NEEDS_CONTEXT / ESCALATE` に分類し、採否を `Review Findings > Orchestrator Adjudication` に表形式（| ID | Severity | Decision | Reason | Action |）で記録する。
- raw findings はレビュー入力（監査履歴）であり、そのまま実装指示として扱わない。
- DEFER は plan の Open Questions セクションにも転記して追跡する。
- `@implementer_v2` には ACCEPT 分のみを渡す。
- ESCALATE は `@arbiter_v2` 呼び出し前に必ずユーザーに確認する。
- `/review-*-v2` 直接呼び出しは reviewer_v2 が inline で findings を返すだけ。plan 自動保存は行わない（user が必要なら手で転記する）。

**Plan as source of truth:**
- plan ファイルが存在する場合、plan ファイルを実装・レビューの基準にする。
- chat 履歴だけに依存しない。
- plan には実装ログ・レビュー所見・逸脱記録・未解決事項のセクションを設けて状態を引き継ぐ。

**`@arbiter_v2` の使用条件:**
- `@implementer_v2` が同種の失敗を2回繰り返した
- `@reviewer_v2` が ESCALATE を返した
- 設計判断が割れた
- API 境界・state schema・IAM・データモデル・セキュリティに影響する変更

**`@arbiter_v2` は常用しない。** 同じ問題で2回相談しても解決しない場合は、人間にエスカレートする。
```

- [ ] **Step 3: Verify AGENTS.md references v2 as the normal path**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
text = Path('/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md').read_text()
required = [
    'OpenCode の通常入口は `dispatcher_v2` を使う。',
    '`@implementer_v2` 直行',
    '`@explorer_v2` で調査してから判断',
    '`@planner_v2` 経由',
    '`@reviewer_v2`',
    '`@arbiter_v2` は常用しない。',
]
missing = [item for item in required if item not in text]
if missing:
    raise SystemExit('missing expected AGENTS.md text: ' + ', '.join(missing))
print('AGENTS.md OpenCode guidance points to v2')
PY
```

Expected output:

```text
AGENTS.md OpenCode guidance points to v2
```

---

### Task 3: Validate The Resulting Configuration

**Files:**
- Read: `/Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json`
- Read: `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md`

**Why:** Confirm the change is narrow: default routing and docs changed, v1 agents remain, and no fallback or Pi-style names were introduced.

- [ ] **Step 1: Inspect the focused diff**

Run:

```bash
git diff -- .config/opencode/opencode.json .agents/AGENTS.md
```

Expected:

- `.config/opencode/opencode.json` changes only `default_agent` from `orchestrator` to `dispatcher_v2`.
- `.agents/AGENTS.md` changes only the OpenCode Balanced Workflow section.
- No deletion of v1 agent definitions.
- No additions of `scout`, `worker`, or `oracle` to the OpenCode section.
- No `fallback_models` or fallback plugin additions.

- [ ] **Step 2: Run text invariants**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
config = Path('/Users/haru256/Documents/projects/dotfiles/.config/opencode/opencode.json').read_text()
agents = Path('/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md').read_text()

checks = {
    'default dispatcher_v2': '"default_agent": "dispatcher_v2"' in config,
    'v1 orchestrator retained': '"orchestrator"' in config,
    'v1 implementer retained': '"implementer"' in config,
    'v1 explorer retained': '"explorer"' in config,
    'v1 arbiter retained': '"arbiter"' in config,
    'v2 planner retained': '"planner_v2"' in config,
    'AGENTS v2 default': 'OpenCode の通常入口は `dispatcher_v2` を使う。' in agents,
    'AGENTS no scout': '`scout`' not in agents.split('## Pi Native Orchestration Workflow')[0],
    'AGENTS no worker': '`worker`' not in agents.split('## Pi Native Orchestration Workflow')[0],
    'AGENTS no oracle': '`oracle`' not in agents.split('## Pi Native Orchestration Workflow')[0],
    'no fallback_models': 'fallback_models' not in config,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('failed invariants: ' + ', '.join(failed))
print('OpenCode v2 default invariants pass')
PY
```

Expected output:

```text
OpenCode v2 default invariants pass
```

- [ ] **Step 3: If OpenCode CLI is available, ask it to parse the config**

Run:

```bash
if command -v mise >/dev/null 2>&1; then
  mise exec -- opencode --help >/dev/null
else
  opencode --help >/dev/null
fi
```

Expected: exit code 0. If this command fails because `opencode` is not installed or not managed by `mise`, report the failure as a verification limitation, not as an implementation failure.

- [ ] **Step 4: Final status report**

Run:

```bash
git status --short
```

Expected: the only files changed by this plan are `.config/opencode/opencode.json` and `.agents/AGENTS.md`. If other files are dirty, identify them as pre-existing or unrelated and do not modify them.

## Acceptance Criteria

- `.config/opencode/opencode.json` has `"default_agent": "dispatcher_v2"`.
- v1 agents remain defined in `.config/opencode/opencode.json`.
- v2 agents remain defined in `.config/opencode/opencode.json`.
- `.agents/AGENTS.md` says OpenCode's normal entrypoint is `dispatcher_v2`.
- `.agents/AGENTS.md` routes normal OpenCode work to `planner_v2`, `explorer_v2`, `implementer_v2`, `reviewer_v2`, and `arbiter_v2`.
- The OpenCode section does not introduce Pi-style names `scout`, `worker`, or `oracle`.
- No fallback model plugin or fallback model setting is added.

## Implementation Log
<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N → STATUS | commit-or-failure-signature -->

## Review Findings
<!-- This template is also defined in commands/plan.md. Keep them in sync on every edit. -->

### Reviewer Raw Findings
<!-- Orchestrator copies @reviewer's structured findings verbatim here when invoking @reviewer
     during a workflow. Direct /review-* calls do not write here.
     Raw findings are review input (audit history), not implementation instructions. -->

[2026-05-12] plan → APPROVE | (no findings)

#### [2026-05-12] implementation task 2 → REQUEST_CHANGES
Critical issues (blocking):
- F1: Severity: BLOCKER | Confidence: HIGH | Category: scope | Evidence: `.agents/AGENTS.md` (worktree) contains no `## Pi Native Orchestration Workflow` heading; `grep -n "Pi Native"` returns no matches. The main repo's working directory at `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md:110` contains a 32-line `## Pi Native Orchestration Workflow` section that was never committed. The worktree's AGENTS.md skips directly from the OpenCode section's trailing `---` separator (line 108) to `## Git 運用` (line 110). | Why it matters: The task spec explicitly requires preservation of the Pi Native Orchestration Workflow section unchanged. Its absence means Pi-native OpenCode sessions will have no orchestration instructions, and a future merge could silently delete the Pi section if it's been committed elsewhere. | Recommended action: Merge the Pi section into the worktree file immediately after the OpenCode section's `---` separator (before `## Git 運用`). The exact text to insert is the `## Pi Native Orchestration Workflow` block from `/Users/haru256/Documents/projects/dotfiles/.agents/AGENTS.md` lines 110-141, followed by a `---` separator line. Alternatively, rebase the worktree onto a base that already contains the Pi section. | Must fix before merge: yes
Non-blocking suggestions:
- (none)

### Orchestrator Adjudication
<!-- Orchestrator appends adjudication tables for orchestrated workflow reviews.
     Only ACCEPT rows are implementation instructions:
     | ID | Severity | Decision | Reason | Action | -->

#### [2026-05-12] implementation task 2 adjudication
| ID | Severity | Decision | Reason | Action |
|----|----------|----------|--------|--------|
| F1 | BLOCKER | ACCEPT | The plan explicitly requires preserving the Pi Native Orchestration Workflow section. The isolated worktree was created from committed HEAD, while the main workspace has the Pi section as an uncommitted user change, so the worktree deliverable would otherwise regress that guidance. | Ask @implementer to copy the Pi Native Orchestration Workflow section from the main workspace into the worktree unchanged, placing it before `## Git 運用`. |

## Deviations from Plan
<!-- Implementer documents intentional deviations and reasons -->

## Open Questions
<!-- Any agent adds questions for orchestrator or arbiter -->
