# ADR 0010 — GUI editors for scratch buffers: Neovide and VS Code

- **Status:** Accepted (2026-10-19)
- **Date:** 2026-10-19

## Context

Christopher wants Neovim as a GUI app, mainly to open a blank buffer as fast as possible, with no intention of saving it, and the option to save it later. The Neovim config must stay the shared LazyVim one (`~/.config/nvim`). VS Code is already installed and managed (task 18). No launcher app (Raycast, Hammerspoon) is installed; Karabiner is, and its config is in the repo.

## Options considered

| | Neovide | VS Code + vscode-neovim |
|---|---|---|
| Neovim | the real config and UI (lualine, pickers, which-key) | normal mode only; insert mode, UI and `<leader>` maps are VS Code's (LazyVim `vscode` extra) |
| Blank buffer | needs config: `nofile` scratch buffer, `:Keep` to save | built in: untitled files |
| Unsaved text survives | no: gone with the window | yes: hot exit on Cmd+Q, restored on launch |
| Start from hotkey | new window in the running app (~60 ms hand-off), Neovim ~22 ms | `code -n`: new Electron window |
| New install | `neovide-app` cask | extension only |

Ways to tell a Neovide scratch window from a normal one: a Neovim argument (`-- --cmd 'let g:scratch=1'`) is dropped when `--reuse-instance` hands the request to the running app (tested with 0.16.2); "a Neovide window without files" needs nothing passed. Ways to make it not ask to save: `buftype=nofile` (Neovim never asks; `:w <file>` still works) vs turning off `g:neovide_confirm_quit` (still asks through `:q`).

For VS Code: a new untitled tab in the existing window from outside (`code -r --file-uri untitled:…`) opens nothing; `code -n` opens a window with an untitled file.

## Decision

Both, as asked, in the `gui` group:

- **Neovide** (`neovide-app` cask): every window started without files is a scratch window with one `nofile` buffer; `:Keep`/Cmd+S/`<leader>ww` saves it and makes it an ordinary buffer. Hotkey Ctrl+Opt+Cmd+N through Karabiner. Light/dark from macOS (Neovide sets `'background'`); `follow_terminal.lua` skips Neovide and VS Code.
- **VS Code**: `vscode-neovim` extension, LazyVim's `vscode` extra, hotkey Ctrl+Opt+Cmd+V running `code -n`; hot exit stays at its default.

Neovide is for "throw it away unless I keep it" with the real Neovim; VS Code is for "keep it around without thinking", with Neovim's motions.

## Consequences

- Neovide opened from the Dock without files is a scratch window too, and shows no dashboard. Use terminal Neovim or `neovide <file>` for project work.
- Closing a Neovide scratch window loses its text without asking. That's the point, and the cost.
- Closing a single VS Code window with unsaved untitled files asks to save; only Cmd+Q keeps them silently.
- The hotkeys live in `linked/karabiner/karabiner.json`, in all three Karabiner profiles; a new profile made in Karabiner's UI won't have them.
- Revisit if Neovide's `--reuse-instance` starts passing Neovim arguments (a scratch flag would then let Dock-launched windows keep the dashboard), or if a launcher app joins the setup (hotkeys move there).
