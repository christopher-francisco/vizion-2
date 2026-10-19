# ADR 0011 — Add habamax/vim-godot to LazyVim

- **Status:** Rejected (2026-10-19)
- **Date:** 2026-10-19

## Context

Task 43 (`requirements/0.7.0_GODOT.md`) gave LazyVim Godot support without a plugin: the `gdscript`, `gdshader` and `godot_resource` treesitter parsers, nvim-lspconfig's `gdscript` server (served by the Godot editor) and a project socket for Godot's external editor. LazyVim has no Godot extra. The question was whether to add [habamax/vim-godot](https://github.com/habamax/vim-godot) on top, the usual Vim plugin for Godot (586 stars, last push 2025-12-15).

vim-godot ships ftdetect, syntax, indent, ftplugin and folding for GDScript, GSL (the old shader name) and resource files, a `godot` compiler file, and buffer-local commands to run a scene: `:GodotRun [scene]` (main scene by default, tab completion), `:GodotRunCurrent`, `:GodotRunLast`, `:GodotRunFZF` (fzf.vim). It calls `godot` on `PATH` or `g:godot_executable`, and runs synchronously unless vim-dispatch or asyncrun.vim is installed.

Neovim 0.12 already ships the same author's runtime files (`ftplugin/gdscript.vim` with tabs and width 4 and folding, `indent/gdscript.vim`, `syntax/gdscript.vim`, `gdshader.vim`, `gdresource.vim`), checked 2026-10-19 in Homebrew's 0.12.6 runtime.

## Options considered

| | Add vim-godot | No plugin (as built in task 43) |
|---|---|---|
| Highlighting | Regex syntax, which treesitter overrides anyway | Treesitter parsers |
| Indent, tabs, folding | Duplicates Neovim's built-in files | Neovim's built-in files (same author), LazyVim's treesitter folding |
| Resource and shader files | GSL and `gdresource` syntax | `godot_resource` and `gdshader` parsers, built-in syntax |
| Run a scene from Neovim | `:GodotRun*`; blocks Neovim without vim-dispatch/asyncrun; the picker needs fzf.vim (LazyVim uses the snacks picker) | Not available; F5 in the Godot editor, or a few lines of our own later |
| Cost | A plugin in `linked/nvim/lazy-lock.json` and the VM checks, every machine | None |

## Decision

Rejected. Its only new feature is the run commands, and those would need a second plugin (vim-dispatch or asyncrun) to stop blocking Neovim and fzf.vim for the picker. Everything else is already in Neovim's runtime or covered by treesitter.

## Consequences

- No run commands in Neovim: run scenes from the Godot editor (F5, F6).
- If running from Neovim is wanted, write a small user command in `config/autocmds.lua` instead of adding the plugin: `godot --path <project root> [scene]` in a snacks terminal, the scene picked with the snacks picker, Godot found at `/Applications/Godot.app/Contents/MacOS/Godot`.
- Revisit if vim-godot gains something beyond running scenes (e.g. debugging), or if Neovim drops the built-in Godot runtime files.
