# Vizion 2

Provisions a Mac with my tools and dotfiles, using [chezmoi](https://www.chezmoi.io) and Homebrew Bundle. Each machine picks a profile (`personal` or `work`) and the groups it wants, so a company laptop can get only part of the setup.

Design and decisions: [`docs/requirements/0.1.0_CHEZMOI_DESIGN.md`](docs/requirements/0.1.0_CHEZMOI_DESIGN.md), [`docs/adr/`](docs/adr). Work queue: [`docs/BOARD.md`](docs/BOARD.md).

## Set up a new Mac

Before you start:

- You need an admin password once, for Homebrew.
- If you'll say yes to Mac App Store apps, sign in to the App Store first.
- Quit iTerm2 if it's running (it saves its settings on quit and would overwrite the new ones).

Then run:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply --use-builtin-git true christopher-francisco/vizion-2
```

This installs chezmoi into `~/.local/bin`, clones this repo to `~/.local/share/chezmoi` (with chezmoi's built-in git, since a new Mac has no git yet), asks the first-run questions and applies everything. `--use-builtin-git` is only needed for this first clone.

### First-run questions

Answers are saved in `~/.config/chezmoi/chezmoi.toml` and asked only once. The profile only sets the defaults for the questions after it.

| Question | `personal` default | `work` default |
|---|---|---|
| Machine profile | | |
| Git name, git email for this machine | | |
| Install GUI apps (iTerm, VS Code, Karabiner…) | yes | yes |
| Install personal apps (1Password, Spotify) | yes | no |
| Install Mac App Store apps | yes | no |
| Log gh in to a GitHub Enterprise host (then: which host) | no | yes |
| Is CrowdStrike installed (inline tmux navigator bindings)? | no | yes |

To change an answer later: `chezmoi init --prompt`, then `chezmoi apply`.

### What runs, in order

1. `00-prereqs`: Homebrew (and with it the Xcode Command Line Tools). Once.
2. `10-brew`: `brew bundle` with the packages of every enabled group (`.chezmoidata/packages.yaml`).
3. The dotfiles, plus oh-my-zsh and TPM (`.chezmoiexternal.toml`).
4. `20-runtimes`: asdf plugins and runtimes from `~/.tool-versions`.
5. `25-vscode-extensions`: the VS Code extensions in `packages.yaml`.
6. `30-macos`: terminfo entries, iTerm2's settings folder, `defaults write` settings (`.chezmoidata/macos.yaml`).
7. `40-plugins`: tmux plugins, Neovim plugins for both configs (from their `lazy-lock.json`), LazyVim's Mason tools.
8. `50-gh-auth`: `gh auth login` in the browser for each GitHub host without a stored login. Once.

Steps 2 and 4–7 re-run by themselves whenever what they install changes.

### Use an existing clone

On a machine that already has the repo checked out (e.g. the one it's developed on):

```sh
chezmoi init --source ~/Developer/code/vizion-2 --apply
```

The clone's path is saved as `sourceDir`, so chezmoi keeps using it.

## Day to day

- **Pull changes from other machines:** `chezmoi update` (git pull + apply).
- **Files you edit yourself** (shell, tmux, git, both Neovim configs…) are copies. Edit with `chezmoi edit --apply <file>` (`--watch` re-applies on every save), or edit in place and run `chezmoi re-add <file>`. `chezmoi diff` shows what drifted. Templates (`~/.gitconfig`, `tmux.conf`) can only be changed with `chezmoi edit`.
- **Both Neovim configs are owned exactly:** `chezmoi apply` deletes any file in `~/.config/nvim` or `~/.config/nvim-legacy` that isn't in the repo. Add a new file with `chezmoi add <file>` before the next apply.
- **Files apps rewrite** are symlinks into `linked/`, so the app's changes land straight in the repo: both Neovim `lazy-lock.json` files, VS Code `settings.json` and `keybindings.json`, the Karabiner folder and the iTerm2 Dynamic Profiles. iTerm2's global settings are read from `linked/iterm2` directly.
- **iTerm2:** change profiles in iTerm's UI; the change is written to `linked/iterm2/DynamicProfiles/` (ADR 0004). Profiles inherit from `Base`, so a change to `Base` affects all of them.
- **Committing:** on personal machines chezmoi commits and pushes after every `chezmoi edit`/`re-add`. On the work laptop that's off: `chezmoi cd`, review, commit and push by hand. Changes apps make to `linked/` files are never auto-committed: commit them from `chezmoi cd`.
- `chezmoi cd` (alias `vizion`) opens a shell in the repo.

## Adding things

- **A Homebrew package, cask or App Store app:** add it to its group in `.chezmoidata/packages.yaml`. The next `chezmoi apply` installs it. Removing an entry uninstalls nothing; use `brew bundle cleanup` for that.
- **A VS Code extension:** add its ID under `packages.gui.vscode` (`code --list-extensions` prints them). VS Code Settings Sync stays off on every machine: the repo is the source of truth.
- **A macOS setting:** add a `{domain, key, type, value}` entry to its group in `.chezmoidata/macos.yaml`.
- **An iTerm2 profile file:** put the JSON in `linked/iterm2/DynamicProfiles/` and add a matching `symlink_<file>.json.tmpl` under `private_Library/Application Support/iTerm2/DynamicProfiles/`.
- **A language runtime:** add it to `dot_tool-versions`.
- **Machine-specific shell lines:** put them in `~/.zshrc.aliases.local` (not managed).

## Work laptop

The work laptop uses the company email and the enterprise GitHub host, and doesn't log in to the personal GitHub account. It can pull this repo (it's public) but not push to it yet: a repo-scoped token for that is planned (board task 20), pending a check of company policy.

## Troubleshooting

> Neovim is all blue

Run iTerm, not the Terminal app.

> zsh `autosuggest-accept` (Ctrl+Space) doesn't work

macOS uses Ctrl+Space to switch input sources. Disable it in System Settings → Keyboard → Keyboard Shortcuts → Input Sources.

> `can't find terminal definition for xterm-256color-italic`

The terminfo entries aren't compiled yet. Run `chezmoi apply`, or `tic -x linked/iterm2/terminfo/*.terminfo` from `chezmoi cd`.

> `warning: nvim's lazy-lock.json changed during restore`

The plugin restore found a lock file that differs from the repo's. Check with `chezmoi git diff` and either commit the change or `chezmoi git -- checkout -- linked/` to keep the repo's version.
