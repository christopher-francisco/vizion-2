# Vizion 2

Rewrite of [vizion](../vizion), the script that provisions a brand new Mac with all my tools and dotfiles. Vizion is hand-written Ruby (Rake tasks, a custom installer, linker and logger) and installs everything or nothing. Vizion 2 replaces the custom code with off-the-shelf tooling (proposed: chezmoi + Homebrew Bundle) and adds profiles so a machine, such as a company laptop, can get only a subset of the setup.

## Core constraints

- macOS only (Apple Silicon first).
- No hand-written installer framework: lean on the tool's features and keep custom scripts small and idempotent.
- Selective install: every package and config belongs to a group, and each machine picks its groups.
- No Ruby. Shell for scripts, YAML for data, chezmoi (Go) templates.
- No secrets in the repo. Today none are needed: GitHub auth lives in gh. Git identity is chosen per machine.
- Neovim config must stay in sync across all machines via git. LazyVim is the default config (`~/.config/nvim`); the old one is `nvim-legacy`.
- Must work on a locked-down company laptop (no personal Apple ID; the account is a permanent admin, needed by the Homebrew install and the Karabiner cask).

## Current focus

Setup is built and VM-tested (ADRs 0001–0004, `docs/requirements/0.1.0_*`). Regression test suite (ADR 0005, `0.1.0_TEST_SUITE.md`) built through the guided steps (tasks 27–29); iTerm profiles rebuilt (task 35, ADR 0006, `0.2.0_ITERM_PROFILES.md`); tmux and Neovim follow the iTerm window's colour scheme and light/dark (task 38, ADR 0007, `0.3.0_COLOUR_SCHEME_SYNC.md`); LazyVim lualine matches the tmux bar (task 39, `0.4.0_NEOVIM_STATUSLINE.md`). iTerm's saved copies of dynamic profiles are stripped from the plist by a git clean filter (task 37, ADR 0008, `0.5.0_ITERM_PLIST_CLEAN.md`). Custom terminfo dropped for macOS's own entries (task 41, ADR 0009). Neovide and VS Code scratch buffers with Karabiner hotkeys (task 42, ADR 0010, `0.6.0_GUI_EDITORS.md`). Godot in LazyVim (task 43, `0.7.0_GODOT.md`; vim-godot rejected, ADR 0011). Claude Code follows the scheme and light/dark (task 45, ADR 0012, `0.8.0_CLAUDE_CODE_THEME.md`). Next: task 42's and 45's checks by hand, tasks 35, 37, 38 and 41's VM and guided checks with the next full run, then task 30 (more scenarios).
