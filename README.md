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
| Install personal apps (1Password, Spotify, Blender…) | yes | no |
| Install Mac App Store apps | yes | no |
| Log gh in to a GitHub Enterprise host (then: which host) | no | yes |
| Is CrowdStrike installed (inline tmux navigator bindings)? | no | yes |
| Colour scheme (iTerm, tmux, Neovim) | tokyonight | tokyonight |
| Main monitor, font size on it (small/big): iTerm's default profile, only with GUI apps | retina, big | 4k, big |

To change an answer later: `chezmoi init --prompt`, then `chezmoi apply`.

### What runs, in order

1. `00-prereqs`: Homebrew (and with it the Xcode Command Line Tools). Once.
2. `10-brew`: `brew bundle` with the packages of every enabled group (`.chezmoidata/packages.yaml`).
3. The dotfiles, plus oh-my-zsh and TPM (`.chezmoiexternal.toml`).
4. `20-runtimes`: asdf plugins and runtimes from `~/.tool-versions`.
5. `25-vscode-extensions`: the VS Code extensions in `packages.yaml`.
6. `30-macos`: terminfo entries, iTerm2's settings folder, `defaults write` settings (`.chezmoidata/macos.yaml`).
7. `40-plugins`: tmux plugins, Neovim plugins for both configs (from their `lazy-lock.json`), LazyVim's Mason tools.
8. `50-gh-auth`: `gh auth login` in the browser for each GitHub host without a stored login. Runs on every apply, so a skipped or failed login is offered again (on a terminal; otherwise it prints the command). A logged-in machine sees no output.
9. `55-work-push-token` (work only): if the token for pushing this repo isn't in the Keychain yet, prints how to create it and waits; press Enter to paste and store it, or `s` to skip. Offered on every apply until stored (see [Work laptop](#work-laptop)).

Steps 2 and 4–7 re-run by themselves whenever what they install changes.

### Use an existing clone

On a machine that already has the repo checked out (e.g. the one it's developed on):

```sh
chezmoi init --source ~/Developer/code/vizion-2 --apply
```

The clone's path is saved as `sourceDir`, so chezmoi keeps using it.

## Day to day

- **Pull changes from other machines:** `chezmoi update` (git pull + apply). If the pull adds a first-run question, `chezmoi update` stops at the first file that needs it: run `chezmoi update --init` instead (asks only the new questions).
- **Files you edit yourself** (shell, tmux, git, both Neovim configs…) are copies. Edit with `chezmoi edit --apply <file>` (`--watch` re-applies on every save), or edit in place and run `chezmoi re-add <file>`. `chezmoi diff` shows what drifted. Templates (`~/.gitconfig`, `tmux.conf`) can only be changed with `chezmoi edit`.
- **Both Neovim configs are owned exactly:** `chezmoi apply` deletes any file in `~/.config/nvim` or `~/.config/nvim-legacy` that isn't in the repo. Add a new file with `chezmoi add <file>` before the next apply.
- **Files apps rewrite** are symlinks into `linked/`, so the app's changes land straight in the repo: both Neovim `lazy-lock.json` files, VS Code `settings.json` and `keybindings.json`, the Karabiner folder and the iTerm2 Dynamic Profiles. iTerm2's global settings are read from `linked/iterm2` directly; iTerm saves a copy of every dynamic profile into that plist when it saves on quit, and git leaves them out (ADR 0008), so only real setting changes show up in `git status`. iTerm reads that plist only at launch: when a `chezmoi update` changes it while iTerm runs, the apply says to restart iTerm. If iTerm then asks to overwrite its settings on quit, choose Discard Local Changes, unless you meant to keep a setting you just changed (profile changes need no restart).
- **iTerm2:** change profiles in iTerm's UI; the change is written to `linked/iterm2/DynamicProfiles/` (ADR 0004). Profiles inherit in levels (ADR 0006): `Base` (keys, terminal, behaviour) → a theme (`Tokyonight`, `Everforest`: light and dark colours, following the macOS appearance) → a size (`Tokyonight 11/13/16/20`, plus `13 tight`/`16 tight` with less line spacing, …: font and line spacing). Change colours on the theme and sizes on the size profile; a change to `Base` affects all of them. Pick a size for a monitor from Profiles → `retina`/`2k`/`4k`/`studio-display`.
- **iTerm2 default profile:** new windows open in `This Mac`, which inherits from the profile of your colour scheme tagged with your main monitor, small or big (first-run answers `theme`, `iterm.monitor`, `iterm.size`). To switch, change them in `~/.config/chezmoi/chezmoi.toml` and `chezmoi apply`; iTerm picks it up without a restart. `This Mac` itself isn't saved from the UI: edit the profile it inherits from.
- **Colour scheme and light/dark in tmux and Neovim** follow the iTerm window in use (ADR 0007): open a window from another profile (Profiles → retina → Everforest 13) or in another appearance and `tmux attach`; tmux and LazyVim switch to match, and back when you click an older window still attached. The macOS appearance is the only light/dark switch. Outside iTerm, and in `nvim-legacy`, it's the first-run `theme`. `tmux show -gv @theme` shows what tmux loaded.
- **Committing:** on personal machines chezmoi commits and pushes after every `chezmoi edit`/`re-add`. On the work laptop that's off: `chezmoi cd`, review, commit and push by hand. Changes apps make to `linked/` files are never auto-committed: commit them from `chezmoi cd`.
- `chezmoi cd` (alias `vizion`) opens a shell in the repo.

## Adding things

- **A Homebrew package, cask or App Store app:** add it to its group in `.chezmoidata/packages.yaml`. The next `chezmoi apply` installs it. Removing an entry uninstalls nothing; use `brew bundle cleanup` for that.
- **A VS Code extension:** add its ID under `packages.gui.vscode` (`code --list-extensions` prints them). VS Code Settings Sync stays off on every machine: the repo is the source of truth.
- **A macOS setting:** add a `{domain, key, type, value}` entry to its group in `.chezmoidata/macos.yaml`.
- **An iTerm2 theme:** a new file in `linked/iterm2/DynamicProfiles/` with the theme profile (parent `Base`, `(Light)`/`(Dark)` colours) first, then its four sizes with the same monitor tags; every profile names its parent by both `Dynamic Profile Parent Name` and `Dynamic Profile Parent GUID`. Add a matching `symlink_<file>.json.tmpl` under `private_Library/Application Support/iTerm2/exact_DynamicProfiles/` (the first-run theme and monitor choices are read from the profile files). For tmux, add `dot_config/tmux/themes/<theme>-dark.tmux.conf` and `-light` setting the same `@` options as the others; for Neovim, a colour scheme plugin named like the theme (lower case). `test/run.sh --host-only` checks all of this. Profiles created in iTerm's UI are regular profiles in the main plist, not dynamic ones.
- **A language runtime:** add it to `dot_tool-versions`.
- **Machine-specific shell lines:** put them in `~/.zshrc.aliases.local` (not managed).

## Testing

- `test/run.sh --host-only` checks both profiles on this Mac in about 15 seconds, without touching `$HOME`: it answers the first-run questions, renders every file and script (shellcheck included), checks the Brewfile names exist, and runs the gh-login and push-token scripts against stubs.
- `test/run.sh` also bootstraps a clean Tart VM per profile from the working tree, two at a time (about 40 minutes), then checks the result: a further apply changes nothing, the Brewfile is satisfied, runtimes and tmux/Neovim plugins are installed at their locked commits, Mason tools, treesitter parsers, iTerm, VS Code, git and zsh. The VMs are deleted afterwards (`--keep` keeps them, `--from-github` tests `main` on GitHub instead). Needs Tart; the test SSH key lives in `~/.cache/vizion-2-test/`.
- After each pair of VMs, `test/run.sh` waits for you at each VM's window (a notification says when) and walks you through what it can't do alone: the gh browser login (personal), a 1-day push token (work), and a look at iTerm and Karabiner. It checks each result and records your y/n answers, then reminds you what to revoke on github.com and deletes the VM. `--unattended` skips this part.
- Results land in `~/.cache/vizion-2-test/out/<timestamp>/`. A change to the config, the managed files or the Brewfile shows up as a snapshot diff: if it's intended, run `test/run.sh --host-only --update` and commit the new `test/expected/` files with it.
## Work laptop

The work laptop uses the company email and the enterprise GitHub host, and doesn't log in to the personal GitHub account. It pulls this repo without credentials (it's public). To push, it uses a token that can only write to this repo, stored in its own Keychain item; `~/.gitconfig` hands it to git for this repo's URL only. Auto-commit and auto-push are off: commit and push by hand from `chezmoi cd`.

**Create the token** (on github.com, signed in to the personal account): Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token.

- Expiration: up to a year (GitHub emails before it expires).
- Repository access: Only select repositories → `christopher-francisco/vizion-2`.
- Permissions → Repository permissions → Contents: Read and write. Nothing else (Metadata: Read-only is added automatically).

**Store it on the laptop:** `chezmoi apply` offers this until it's done (step 9 above). By hand, it's this (asks for the token twice; paste it):

```sh
security add-generic-password -U -s vizion-2-push -a christopher-francisco -w
```

Check with `chezmoi cd` then `git push --dry-run`. Without the Keychain item git falls back to asking for a username and password on every push.

**Renew:** when it expires (pushes fail with `Authentication failed`), regenerate the token on GitHub (same page → the token → Regenerate) and run the same `security` command with the new value; `-U` replaces the old one. To remove it: `security delete-generic-password -s vizion-2-push`.

The token isn't part of chezmoi or the repo; a wiped or lost laptop can only ever touch this repo with it. Revoke it on GitHub if that happens.

## Troubleshooting

> Neovim is all blue

Run iTerm, not the Terminal app.

> zsh `autosuggest-accept` (Ctrl+Space) doesn't work

macOS uses Ctrl+Space to switch input sources. Disable it in System Settings → Keyboard → Keyboard Shortcuts → Input Sources.

> `can't find terminal definition for xterm-256color-italic`

The terminfo entries aren't compiled yet. Run `chezmoi apply`, or `tic -x linked/iterm2/terminfo/*.terminfo` from `chezmoi cd`.

> `linked/iterm2/com.googlecode.iterm2.plist` has thousands of lines of profiles

iTerm saved its copies of the dynamic profiles (ADR 0008). Git doesn't store them, so nothing to commit. To clean the file itself, quit iTerm and run `bin/iterm-plist-clean.sh linked/iterm2/com.googlecode.iterm2.plist` from `chezmoi cd`. If `git diff` shows them, the filter isn't set up in this clone: run `chezmoi apply` (the macOS settings script sets it), then `git add --renormalize linked/iterm2/com.googlecode.iterm2.plist`.

> `warning: nvim's lazy-lock.json changed during restore`

The plugin restore found a lock file that differs from the repo's. Check with `chezmoi git diff` and either commit the change or `chezmoi git -- checkout -- linked/` to keep the repo's version.
