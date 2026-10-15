# ADR 0003 — Copy by default; symlink only files apps rewrite

- **Status:** Accepted (2026-10-15)
- **Date:** 2026-10-15

## Context

The first draft of the design symlinked whole config folders into the repo (`~/.config/nvim`, `~/.config/nvim-legacy`, `~/.config/karabiner`, `~/.iterm2`) to keep vizion's edit-in-place workflow. The goal is to use chezmoi the way it is designed to be used, not to work around it.

What the docs say:

- **chezmoi FAQ (design):** chezmoi writes regular files by default, because templates, encryption, executable and private files can't be symlinks. A global "symlink mode" exists "if you really want to use symlinks", and it can't link whole directories.
- **chezmoi user guide, "Handle configuration files which are externally modified":** for a file a program rewrites, keep the real file in the source directory, add it to `.chezmoiignore`, and create `symlink_<name>.tmpl` containing `{{ .chezmoi.sourceDir }}/<file>`. Its worked example is VS Code's `settings.json`.
- **Karabiner-Elements docs (configuration file path):** link the `~/.config/karabiner` folder, not `karabiner.json`, or Karabiner fails to detect config changes.
- **iTerm2** can load its preferences from any folder ("Load preferences from a custom folder", `PrefsCustomFolder`).

## Options considered

| | Folder symlinks (first draft) | Global symlink mode | **Copy by default + targeted symlinks** | Copy everything |
|---|---|---|---|---|
| Matches chezmoi's intended use | No: goes beyond the documented pattern | Supported but discouraged | Yes: the documented pattern | Yes |
| Neovim edits | In place | In place for non-template files | `chezmoi edit --apply`/`--watch`, or edit + `re-add` | Same |
| Files apps rewrite (lazy-lock, VS Code, Karabiner, iTerm) | Picked up | Picked up | Picked up | Overwritten on `apply` unless `re-add` first |
| Karabiner change detection | OK (folder) | Breaks (file link) | OK (folder link, per Karabiner's docs) | OK |

## Decision

- Every managed file is a normal copied chezmoi file by default, including both Neovim configs.
- A file gets a `symlink_` entry into `linked/` only when an app rewrites it on its own:
  - VS Code `settings.json`, `keybindings.json`
  - `lazy-lock.json` of each Neovim config
  - `~/.config/karabiner`, as a folder, because Karabiner requires it
- iTerm2 needs no symlink: its custom preferences folder is set to `<source>/linked/iterm2`. This amends ADR 0002, which kept the plist in a symlinked `~/.iterm2`.

## Consequences

- Editing Neovim config goes through `chezmoi edit --apply` (`--watch` for live reload) or edit + `chezmoi re-add`. `chezmoi status` shows forgotten edits, and `chezmoi apply` asks before overwriting them.
- VS Code and lazy.nvim must write through the symlink rather than replace it; verify during the port, and fall back to copy + `re-add` for any file that doesn't.
- `linked/` holds only app-rewritten files and is listed in `.chezmoiignore`.
- Revisit if editing Neovim config through chezmoi turns out to be a real burden.
