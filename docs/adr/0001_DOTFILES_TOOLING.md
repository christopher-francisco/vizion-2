# ADR 0001 — Use chezmoi + Homebrew Bundle instead of custom Ruby

- **Status:** Accepted (2026-10-15)
- **Date:** 2026-10-15

## Context

Vizion provisions a Mac through a Rakefile plus three hand-written Ruby classes (`installer.rb`, `linker.rb`, `logger.rb`, ~600 lines). Most of that code re-implements things existing tools already do: it parses `brew` output to print status lines, symlinks files into `$HOME`, and chains shell scripts that prompt for tokens.

Problems:

1. **Maintenance cost.** Every new kind of thing to install means a new Rake task, new logger methods and new error handling. Parts have already rotted: `brew cask install` is no longer valid syntax, `nvim_plugs` runs vim-plug's `:PlugInstall` while the Neovim config now uses lazy.nvim, `ssh-add -K` is deprecated, and `install.sh` clones `chris-fran/vizion` while the README points at `christopher-francisco/vizion`.
2. **All or nothing.** `rake` runs `install:all`. A company laptop needs a subset (no Mac App Store apps, no Spotify/Telegram, a work git identity, no personal tokens). Today the only option is editing the Brewfile by hand.
3. **Secrets handling.** Tokens are typed into prompts and written to plain files (`~/.zshrc.tokens`, `~/.grip/settings.py`, SSH passphrase scripts in `~/.ssh`).
4. **Vendored third-party code.** tmux plugins and `plug.vim` are committed into the repo instead of being fetched.

## Options considered

| | **chezmoi + Brewfile** | **nix-darwin + home-manager** | GNU stow / dotbot + Brewfile + shell | Ansible | Keep Ruby, refactor |
|---|---|---|---|---|---|
| What it is | Dotfile manager: a git repo as source state, templates, scripts, externals | Declarative system config in the Nix language; packages, macOS defaults and dotfiles in one flake | Symlink farm + a bootstrap script | General config-management playbooks | Status quo |
| Selective install / profiles | Built in: per-machine config prompted once (`promptChoiceOnce`, `promptBoolOnce`), templates and templated `.chezmoiignore` | Built in: one `darwinConfiguration` per machine composed from shared modules | Hand-rolled in shell | Built in: tags, host vars | Hand-rolled |
| Packages | Delegated to `brew bundle`, triggered by `run_onchange_` scripts | nixpkgs, plus nix-darwin's `homebrew` module for casks and MAS | `brew bundle` | `community.general.homebrew` modules | Custom Ruby |
| Secrets | Native 1Password, Keychain, Bitwarden… template functions | Needs sops-nix/agenix or similar | Hand-rolled | Ansible Vault | Prompts to plain files |
| macOS defaults | Scripts calling `defaults write` | Typed `system.defaults.*` options | Scripts | `osx_defaults` module | Scripts |
| Learning curve | Low: Go templates + shell | High: Nix language, flakes, store semantics | Very low | Medium (YAML + Python runtime) | n/a |
| Footprint on a company laptop | Single static binary in `~/.local/bin` or via brew; no root | Creates a `/nix` APFS volume and a root daemon; often blocked by MDM/IT, and macOS upgrades have broken it | Minimal | Needs Python + Ansible | Needs Ruby + Rake |
| Editing configs day to day | `chezmoi edit`/`re-add`, or symlink mode | Files are read-only symlinks into `/nix/store`; every change needs `darwin-rebuild switch` (unless `mkOutOfStoreSymlink`) | Edit in place | Re-run playbook | Edit in place |
| Reproducibility | Brew installs latest versions | Exact pinned versions, rollbacks | Latest | Latest | Latest |

## Decision

**chezmoi** manages dotfiles, `~/.config`, per-machine profile data, secrets and run scripts. **Homebrew Bundle** (`brew bundle`) installs formulae, casks and MAS apps, fed by a Brewfile that chezmoi renders from package groups in `.chezmoidata/`.

Why not nix-darwin, though it is the most powerful option: the main pain is maintainability, and swapping Ruby for the Nix language trades one niche language for a harder one. Its root-level `/nix` volume and daemon are the part most likely to be refused on a company laptop, and casks and MAS apps would still go through Homebrew. chezmoi keeps the current mental model (a git repo of dotfiles + a Brewfile), needs no root, and provides the missing piece, per-machine profiles, out of the box.

## Consequences

- The Ruby code (`Rakefile`, `installer.rb`, `linker.rb`, `logger.rb`) is deleted; chezmoi's own output replaces the custom logger.
- No Ruby anywhere: chezmoi is a Go binary, templates are Go `text/template`, scripts are shell. The Brewfile (a Ruby DSL) is generated from YAML and never edited by hand.
- Files become chezmoi source names (`dot_zshrc`, `private_dot_ssh/…`) and are copied by default; editing goes through `chezmoi edit` / `chezmoi re-add`. Only files that apps rewrite themselves are symlinked into the repo (see ADR 0003).
- After the cleanup no secrets are left to manage (GitHub auth lives in gh), so the secrets integration isn't used for now; it remains available through `onepasswordRead` / `keyring` if one appears.
- Brew installs latest versions, so the setup is not bit-for-bit reproducible. Acceptable for a workstation.
- Every run script must be idempotent; chezmoi will re-run `run_onchange_` scripts whenever their rendered content changes.
- Revisit triggers: wanting pinned versions and rollbacks, managing several machines with diverging system-level settings, or IT permitting Nix. A later move to nix-darwin can reuse the same dotfiles through home-manager.
