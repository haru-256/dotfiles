# Herdr Agent Aggressive Slim Design

## Goal

Slim the Herdr agent scripts so they rely on the skill package as the canonical runtime surface. If the slimmed scripts stop working, treat that as a package/install defect rather than preserving old fallback paths.

## Scope

In scope:
- `.agents/skills/using-herdr-agents/scripts/herdr-agent`
- `.agents/skills/using-herdr-agents/scripts/herdr-agent-session`
- `.agents/skills/using-herdr-agents/tests/herdr-agent.sh`
- related README or skill text only if behavior or documented commands change

Out of scope:
- changing role/model defaults
- redesigning prompts
- changing OpenCode `scout_v2`
- changing Herdr config/keybindings

## Design

`herdr-agent` should resolve its own real path through symlinks and use the sibling package prompt directory as the normal prompt source. It may keep `HERDR_AGENT_PROMPT_DIR` for tests and explicit debugging, but it should remove fallback discovery for `~/.config/herdr/agents` and old dotfiles prompt locations.

Scout still supports `HERDR_AGENT_SCOUT_BACKEND=opencode|cline`. OpenCode remains the default. Cline is a fallback, but Cline launch should be mise-owned: call `mise exec -- cline ...` directly. Do not keep `CLINE_BIN_PATH`, hard-coded version paths, npm-global paths, Bun paths, Homebrew paths, `mise which cline`, or plain `command -v cline` fallback.

Low-value Scout overrides should be removed:
- `HERDR_AGENT_SCOUT_OPENCODE_AGENT`
- `HERDR_AGENT_SCOUT_CLINE_PROVIDER`
- `HERDR_AGENT_SCOUT_CLINE_THINKING`

The script should hard-code the local defaults these represented:
- OpenCode agent: `scout_v2`
- Cline provider: `cline-pass`
- Cline thinking: `low`

Model overrides remain because subscription/quota fallback is part of the workflow:
- `HERDR_AGENT_SCOUT_MODEL`
- `HERDR_AGENT_SCOUT_CLINE_MODEL`
- `HERDR_AGENT_CODER_MODEL`
- `HERDR_AGENT_AUDITOR_MODEL`
- `HERDR_AGENT_ADVISOR_MODEL`
- `HERDR_AGENT_ADVISOR_THINKING`

`herdr-agent-session` should stop accepting unknown Scout backends when deriving session names. Invalid `HERDR_AGENT_SCOUT_BACKEND` should fail clearly before a Herdr pane is created.

## Error Handling

Missing package prompts should fail with the existing readable-file errors. Missing `mise` for OpenCode or Cline should fail with `exit 127` and a clear message. Invalid enum-like environment values should fail with `exit 65`.

## Testing

Update package tests to prove:
- one-shot Scout still routes to OpenCode `opencode-go/deepseek-v4-flash` and `scout_v2`
- Cline Scout dry-run still routes to `cline-pass`, `deepseek-v4-flash`, and `low`
- removed Scout override environment variables no longer affect dry-run output
- nonexistent `HERDR_AGENT_PROMPT_DIR` falls back only to package prompts
- invalid Scout backend fails in both `herdr-agent` and `herdr-agent-session`
- installed symlink entrypoints still resolve package prompts and package runner
- shell syntax checks pass

## Acceptance Criteria

- `sh tests/herdr-agent.sh` passes.
- `sh -n` passes for the Herdr scripts and package test.
- `HERDR_AGENT_DRY_RUN=1 herdr-agent scout "find files"` reports package prompts.
- `HERDR_AGENT_SESSION_DRY_RUN=1 HERDR_AGENT_REUSE=never herdr-agent-session scout "find files"` reports the package runner.
- No old prompt fallback or Cline binary discovery remains in `herdr-agent`.
