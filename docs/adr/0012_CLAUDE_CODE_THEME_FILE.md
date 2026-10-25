# ADR 0012 — Claude Code follows the iTerm window through one rewritten custom theme

- **Status:** Accepted (2026-10-25)
- **Date:** 2026-10-25

## Context

Claude Code should use the Tokyonight and Everforest colours in light and dark and switch with the iTerm window, as tmux and Neovim do (ADR 0007). Claude Code 2.1.310 has custom themes (`~/.claude/themes/<slug>.json`, `"theme": "custom:<slug>"`) and reloads them live when a file changes. But a custom theme has one fixed base, and `auto` follows light/dark only between the built-in presets. Nothing in Claude Code switches between custom themes. `requirements/0.8.0_CLAUDE_CODE_THEME.md` has the findings.

## Options considered

| | One theme file, rewritten (`custom:vizion`) | Four custom themes, switching `theme` in settings.json | One all-`ansi:` theme |
|---|---|---|---|
| Colours | The schemes' own, backgrounds included | The schemes' own | The window's 16 ANSI colours; diff and message backgrounds become loud blocks |
| Follows the window | Rewritten by tmux's hook and by Claude Code's hooks | Same triggers, but writing the user's settings.json on every switch | Per window, by itself |
| Live in running sessions | Yes: the themes folder is watched | Not documented for `theme` | Yes |
| `/theme` | Lists one theme | Lists four | Lists one |
| Several windows of different schemes | Last to act wins | Last to act wins | Each right |

## Decision

One theme file, rewritten. Its reload is documented, it never writes the user's settings at run time, and it keeps the schemes' real colours. The four palettes are static files that `~/.claude/vizion/theme.sh` copies over `~/.claude/themes/vizion.json`. tmux's theme hook calls it (immediate inside tmux). Claude Code's `SessionStart` and `UserPromptSubmit` hooks call it too (outside tmux, at the next prompt). chezmoi creates `vizion.json` once and merges the theme and hooks into `settings.json` with a `modify_` script, leaving the rest of the file to Claude Code.

## Consequences

- One theme for every session, like tmux's global options: windows of different schemes take turns.
- Outside tmux, a light/dark flip shows at the next prompt.
- `/theme` to another theme lasts until the next `chezmoi apply`, which sets `custom:vizion` back.
- A new iTerm theme needs `dot_claude/vizion/themes/<theme>-dark.json` and `-light` (the host check fails without them).
- Revisit if Claude Code gets custom themes with a light and a dark side (a custom `auto` pair), or a way to set the theme from outside. Then the files can stay and the rewriting can go.
