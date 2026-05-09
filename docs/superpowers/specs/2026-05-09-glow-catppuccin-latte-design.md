# Glow Catppuccin Latte Design

## Goal

Manage Glow configuration in this dotfiles repository and configure Glow syntax highlighting to use a Catppuccin Latte style.

## Scope

- Add Glow configuration at `.config/glow/glow.yml` if it is not already tracked.
- Install a symlink from `~/.config/glow/glow.yml` to the repository-managed file.
- If a pre-existing real file exists at `~/.config/glow/glow.yml`, it may be discarded after the repository-managed replacement is ready.

## Design

Use Glow's standard user configuration path so no aliases or wrapper scripts are required. Keep the repository layout consistent with the existing `.config/<tool>/...` pattern used for other terminal tools.

The implementation should prefer the smallest valid Glow configuration needed to select Catppuccin Latte syntax highlighting. If Glow requires a style file instead of a simple style name, add only the minimum Glow-specific theme asset required under `.config/glow/`.

## Constraints

- Do not modify unrelated dotfiles.
- Do not preserve an existing real `~/.config/glow/glow.yml` once the managed file is installed; replacing it is acceptable.
- Do not commit changes unless explicitly requested.

## Acceptance Criteria

- `.config/glow/glow.yml` is tracked in the repository.
- `~/.config/glow/glow.yml` is a symlink to the repository file.
- Glow configuration selects Catppuccin Latte syntax highlighting.
- Existing uncommitted changes unrelated to Glow are not modified.

## Open Questions

- None.
