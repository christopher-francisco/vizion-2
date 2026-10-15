# Board

Statuses: `todo` · `in progress` · `blocked` · `done`

| # | Task | Status | Notes |
|---|---|---|---|
| 1 | Review and accept ADR 0001 (chezmoi + Homebrew Bundle) | done | Accepted 2026-10-15 |
| 2 | Agree requirements `0.1.0_MACHINE_PROVISIONING.md` and promote the chezmoi design to requirements | done | Both accepted 2026-10-15; design is now `requirements/0.1.0_CHEZMOI_DESIGN.md` |
| 3 | Decide keep/drop for each vizion item (cleanup table) | done | All decided 2026-10-15; see design "Cleanup" table |
| 4 | Init git repo and chezmoi source state (`.chezmoi.toml.tmpl` with profile/group prompts, `.chezmoiignore`) | done | Done 2026-10-15; verified with `chezmoi execute-template` + `managed`/`ignored` for both profiles |
| 5 | Package groups in `.chezmoidata/packages.yaml` + `run_onchange` brew bundle script | done | Done 2026-10-15; Brewfile rendered for both profiles, parsed by `brew bundle list`, all formula/cask names verified |
| 6 | Port Neovim: LazyVim config (branch `lazyvim`) → `dot_config/nvim`, master's config → `dot_config/nvim-legacy` (copied files), each `lazy-lock.json` symlinked from `linked/`, `nvim-legacy` alias | done | Done 2026-10-15. Legacy from local master incl. unpushed WIP 1655940. lazy.nvim verified writing through the symlink (`Lazy! update`, inode unchanged). `nvim-legacy` alias moved to task 15 |
| 15 | Port remaining dotfiles and `~/.config` directories | done | Done 2026-10-15. Karabiner as a symlinked folder (`linked/karabiner`, ignore `automatic_backups/`); drop vendored tmux plugins and plug.vim; `.zshrc.aliases` merge per design "Shell" section (incl. `nvim-legacy` alias from task 6); chezmoi-managed `~/.tool-versions`. Added `dot_zprofile` (brew shellenv). `~/.gitignore` merged into `~/.config/git/ignore`. Karabiner = master per design (live machine runs `lazyvim`'s) |
| 7 | Externals: oh-my-zsh, TPM | done | Done 2026-10-15. Verified in a temp home: both fetched, omz loads, re-apply clean, `exact` keeps `.oh-my-zsh/cache` (ignored) and removes strays. omz self-update disabled |
| 8 | Runtimes and plugins: asdf (`.tool-versions`), plugin restore (TPM, lazy.nvim for both configs, Mason tools) | done | Done 2026-10-15. No global npm, cargo, yarn, pynvim. Tested from clean in a temp home: asdf node, 8 tmux plugins, both nvim configs on locked commits, 16 Mason packages; re-run is a no-op. Workarounds: private tmux server for TPM, credential helper off, lock guard on first nvim start, headless mason-lspconfig install |
| 18 | VS Code: symlink `settings.json`/`keybindings.json`, rebuild + prune extension list from `code --list-extensions`, extension install script | done | Done 2026-10-15. Write-through verified (UI change landed in the link target, same inode). Settings from this Mac minus the dead Jenkins keys (incl. a token) and Live Share; 10 extensions (dropped Solarized, Live Share). Verify VS Code writes through the symlink; Settings Sync stays off |
| 9 | Git identity per machine in `dot_gitconfig.tmpl` (name/email prompts) | todo | Replaces setup_gitconfig, `.gitconfig.local/.enterprise`, includeIf. No secrets step needed. Drop `core.excludesfile = ~/.gitignore` (global ignore is now `~/.config/git/ignore`, which excludesfile was shadowing). Decide on the `dnav`/`dvsp` aliases: their `git config --global` writes the rendered copy (drift) |
| 17 | GitHub access via `gh`: login for github.com (+ enterprise on work), `gh auth setup-git`, HTTPS protocol; drop hub, `HUB_PROTOCOL`, `setGithubVersion` | todo | Replaces SSH for GitHub |
| 11 | macOS settings script (iTerm prefs folder, terminfo, defaults) | todo | |
| 16 | Port iTerm2: convert `lazyvim` profiles to Dynamic Profiles (base + per-scheme JSON), rename duplicates, fix stale FiraCode names, slim the main plist, `GenerativeAIAllowed = false`, font casks (prefs folder = `<source>/linked/iterm2` via `PrefsCustomFolder`) | todo | ADR 0002 |
| 20 | Work-laptop push access: create fine-grained token (vizion-2 only, Contents RW, expiry), work-only credential entry in `dot_gitconfig.tmpl`, `[git] autoCommit/autoPush` off on work, README section incl. renewal | todo | Check company policy first |
| 12 | Bootstrap one-liner and README | todo | Port troubleshooting section |
| 13 | Test both profiles on a clean macOS VM | todo | e.g. Tart or UTM |
| 22 | Remove the revoked Jenkins token and company Jenkins URLs from the public vizion repo (find it with `git log --all -S jenkins.pipeline.linter` in the old repo): delete the branch or make the repo private, before archiving | todo | Token revoked 2026-10-15 (by Christopher), so this is clean-up only. Found during task 18 |
| 14 | Archive the old vizion repo | todo | |
| 19 | Look at `HOMEBREW_GITHUB_API_TOKEN`: still useful? If so, `export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)` in the shell | todo | Later; only remaining use of `.zshrc.tokens` |
| 10 | Evaluate whether SSH is still needed (non-GitHub servers, commit signing); if so, design key setup (ed25519, keychain) | todo | Write-up only, don't implement. GitHub is covered by gh |
| 21 | oh-my-zsh custom themes: when needed, keep them outside `~/.oh-my-zsh` (`exact = true` deletes anything not in the archive) | todo | Only when a custom theme is wanted. Likely fix: set `ZSH_CUSTOM` in `dot_zshrc` to a chezmoi-managed dir (e.g. `~/.config/oh-my-zsh`) and put themes in `dot_config/oh-my-zsh/themes/`; alternative: `.oh-my-zsh/custom/**` in `.chezmoiignore` (unmanaged) |
