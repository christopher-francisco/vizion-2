# Board

Statuses: `todo` · `in progress` · `blocked` · `done`

| # | Task | Status | Notes |
|---|---|---|---|
| 1 | Review and accept ADR 0001 (chezmoi + Homebrew Bundle) | done | Accepted 2026-10-15 |
| 2 | Agree requirements `0.1.0_MACHINE_PROVISIONING.md` and promote the chezmoi design to requirements | done | Both accepted 2026-10-15; design is now `requirements/0.1.0_CHEZMOI_DESIGN.md` |
| 3 | Decide keep/drop for each vizion item (cleanup table) | done | All decided 2026-10-15; see design "Cleanup" table |
| 4 | Init git repo and chezmoi source state (`.chezmoi.toml.tmpl` with profile/group prompts, `.chezmoiignore`) | done | Done 2026-10-15; verified with `chezmoi execute-template` + `managed`/`ignored` for both profiles |
| 5 | Package groups in `.chezmoidata/packages.yaml` + `run_onchange` brew bundle script | todo | |
| 6 | Port Neovim: LazyVim config (branch `lazyvim`) → `dot_config/nvim`, master's config → `dot_config/nvim-legacy` (copied files), each `lazy-lock.json` symlinked from `linked/`, `nvim-legacy` alias | todo | Legacy = `master`'s `nvim/` as-is; `next_nvim/` dropped. Verify lazy.nvim writes through the symlink |
| 15 | Port remaining dotfiles and `~/.config` directories | todo | Karabiner as a symlinked folder (`linked/karabiner`, ignore `automatic_backups/`); drop vendored tmux plugins and plug.vim; `.zshrc.aliases` merge per design "Shell" section; chezmoi-managed `~/.tool-versions` |
| 7 | Externals: oh-my-zsh, TPM | todo | |
| 8 | Runtimes and plugins: asdf (`.tool-versions`), plugin restore (TPM, lazy.nvim for both configs, Mason tools) | todo | No global npm, cargo, yarn, pynvim |
| 18 | VS Code: symlink `settings.json`/`keybindings.json`, rebuild + prune extension list from `code --list-extensions`, extension install script | todo | Verify VS Code writes through the symlink; Settings Sync stays off |
| 9 | Git identity per machine in `dot_gitconfig.tmpl` (name/email prompts) | todo | Replaces setup_gitconfig, `.gitconfig.local/.enterprise`, includeIf. No secrets step needed |
| 17 | GitHub access via `gh`: login for github.com (+ enterprise on work), `gh auth setup-git`, HTTPS protocol; drop hub, `HUB_PROTOCOL`, `setGithubVersion` | todo | Replaces SSH for GitHub |
| 11 | macOS settings script (iTerm prefs folder, terminfo, defaults) | todo | |
| 16 | Port iTerm2: convert `lazyvim` profiles to Dynamic Profiles (base + per-scheme JSON), rename duplicates, fix stale FiraCode names, slim the main plist, `GenerativeAIAllowed = false`, font casks (prefs folder = `<source>/linked/iterm2` via `PrefsCustomFolder`) | todo | ADR 0002 |
| 20 | Work-laptop push access: create fine-grained token (vizion-2 only, Contents RW, expiry), work-only credential entry in `dot_gitconfig.tmpl`, `[git] autoCommit/autoPush` off on work, README section incl. renewal | todo | Check company policy first |
| 12 | Bootstrap one-liner and README | todo | Port troubleshooting section |
| 13 | Test both profiles on a clean macOS VM | todo | e.g. Tart or UTM |
| 14 | Archive the old vizion repo | todo | |
| 19 | Look at `HOMEBREW_GITHUB_API_TOKEN`: still useful? If so, `export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)` in the shell | todo | Later; only remaining use of `.zshrc.tokens` |
| 10 | Evaluate whether SSH is still needed (non-GitHub servers, commit signing); if so, design key setup (ed25519, keychain) | todo | Write-up only, don't implement. GitHub is covered by gh |
