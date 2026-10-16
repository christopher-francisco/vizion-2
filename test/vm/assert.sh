#!/bin/bash
# Runs inside a test VM after the bootstrap (test/vm.sh copies test/vm/ there). Prints one
# `ok`/`not ok` line per check; expected values come from the repo, not hard-coded counts.
# Usage: assert.sh <profile>
set -uo pipefail

profile=$1
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$here/lib.sh"

# --- chezmoi: applying again changes nothing and prints only the expected notices
apply_out=$(chezmoi apply 2>&1)
rc=$?
unexpected=$(printf '%s\n' "$apply_out" | grep -E '^(chezmoi:|warning|error)' || true)
if [ "$rc" = 0 ] && [ -z "$unexpected" ]; then ok "apply again: exit 0, no errors or warnings"
else not_ok "apply again: exit 0, no errors or warnings" "rc=$rc"$'\n'"$apply_out"; fi
# Plain run_after_ scripts (not run_once_/run_onchange_) run on every apply by design, so they're
# always pending.
always=$(for f in "$src"/.chezmoiscripts/run_after_*; do [ -e "$f" ] && basename "${f%.tmpl}" | sed 's/^run_after_//'; done)
status=$(chezmoi status 2>&1 | while IFS= read -r line; do
  name=${line##*/}
  [[ "$line" == *.chezmoiscripts/* ]] && grep -qxF "$name" <<< "$always" && continue
  echo "$line"
done)
missing "chezmoi status is empty (except scripts that run on every apply)" "$status"
missing "the source has no local changes (lock files not rewritten)" "$(git -C "$src" status --porcelain)"

# --- Homebrew
brewfile=$(mktemp)
chezmoi execute-template < "$src/.chezmoiscripts/run_onchange_before_10-brew.sh.tmpl" |
  sed -n "/<<'BREWFILE'/,/^BREWFILE$/p" | sed '1d;$d' > "$brewfile"
check "brew bundle check" brew bundle check --file="$brewfile"

# --- asdf runtimes from ~/.tool-versions
while read -r plugin version _; do
  [[ -z "$plugin" || "$plugin" == \#* ]] && continue
  check "asdf: $plugin $version installed" sh -c "asdf list $plugin | grep -qw -- '$version'"
done < "$HOME/.tool-versions"

# --- tmux plugins from the @plugin lines (tpm itself is a chezmoi external)
plugins=$(sed -n "s/^set -g @plugin '\(.*\)'.*/\1/p" "$HOME/.config/tmux/tmux.conf")
absent=
for p in $plugins; do
  [ -n "$(ls -A "$HOME/.config/tmux/plugins/${p##*/}" 2>/dev/null)" ] || absent+="$p"$'\n'
done
missing "tmux: all $(echo "$plugins" | wc -w | tr -d ' ') plugins installed" "${absent%$'\n'}"

# --- Neovim: every enabled plugin in lazy-lock.json installed at its locked commit (disabled
# plugins stay in the lock file but are never installed)
for app in nvim nvim-legacy; do
  lock=$HOME/.config/$app/lazy-lock.json
  enabled=$(NVIM_APPNAME=$app nvim --headless -c "luafile $here/lazy-enabled.lua" +qa 2>&1 | tr -d '\r')
  wrong=
  count=0
  while read -r name commit; do
    grep -qxF "$name" <<< "$enabled" || continue
    count=$((count + 1))
    head=$(git -C "$HOME/.local/share/$app/lazy/$name" rev-parse HEAD 2>/dev/null) || { wrong+="$name: not installed"$'\n'; continue; }
    [ "$head" = "$commit" ] || wrong+="$name: at ${head:0:7}, locked ${commit:0:7}"$'\n'
  done < <(jq -r 'to_entries[] | "\(.key) \(.value.commit)"' "$lock")
  missing "$app: all $count locked plugins at their commits" "${wrong%$'\n'}"
done

want=$(nvim --headless -c "luafile $here/mason-expected.lua" +qa 2>&1 | tr -d '\r' | grep -v '^$' | sort)
have=$(find "$HOME/.local/share/nvim/mason/packages" -mindepth 1 -maxdepth 1 -exec basename {} \; 2>/dev/null | sort)
if [ -z "$want" ]; then not_ok "Mason: expected list computed"
else missing "Mason: all $(echo "$want" | wc -l | tr -d ' ') packages installed" "$(comm -23 <(echo "$want") <(echo "$have"))"; fi

ts=$(nvim --headless -c "luafile $here/treesitter-missing.lua" +qa 2>&1 | tr -d '\r' | grep -v '^$')
missing "treesitter: every available ensure_installed parser installed" "$(grep -v '^unavailable: ' <<< "$ts")"
unavailable=$(sed -n 's/^unavailable: //p' <<< "$ts" | tr '\n' ' ')
[ -z "$unavailable" ] || echo "# treesitter: requested by LazyVim but not in nvim-treesitter: $unavailable"

# --- macOS settings and GUI apps
check "terminfo: xterm-256color-italic" infocmp -x xterm-256color-italic
check "terminfo: tmux-256color" infocmp -x tmux-256color
if [ "$(data '{{ .groups.gui }}')" = true ]; then
  folder=$(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>&1)
  if [ "$folder" = "$src/linked/iterm2" ] && [ "$(defaults read com.googlecode.iterm2 LoadPrefsFromCustomFolder 2>&1)" = 1 ]; then
    ok "iTerm: prefs folder is the repo's linked/iterm2"
  else
    not_ok "iTerm: prefs folder is the repo's linked/iterm2" "$folder"
  fi
  wrong=
  for f in "$src"/linked/iterm2/DynamicProfiles/*.json; do
    link="$HOME/Library/Application Support/iTerm2/DynamicProfiles/$(basename "$f")"
    [ "$(readlink "$link")" = "$f" ] || wrong+="$(basename "$f")"$'\n'
  done
  missing "iTerm: every Dynamic Profiles file linked" "${wrong%$'\n'}"
  # This Mac, the default profile, is rendered per machine (ADR 0006): a plain file, not a link.
  this_mac="$HOME/Library/Application Support/iTerm2/DynamicProfiles/zz-default.json"
  parent=$(jq -r '.Profiles[0]."Dynamic Profile Parent Name"' "$this_mac" 2>&1)
  if [ ! -L "$this_mac" ] && [ "$parent" = "$(data '{{ .iterm.defaultProfile }}')" ]; then
    ok "iTerm: This Mac inherits from the first-run answer ($parent)"
  else
    not_ok "iTerm: This Mac inherits from the first-run answer" "$parent"
  fi

  want=$(data '{{ range .packages.gui.vscode }}{{ . | lower }}{{ "\n" }}{{ end }}' | grep -v '^$' | sort)
  have=$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort)
  missing "VS Code: all $(echo "$want" | wc -l | tr -d ' ') extensions installed" "$(comm -23 <(echo "$want") <(echo "$have"))"
fi

# --- git and shell
check "git: identity from the first-run answers" test "$(git config user.name) <$(git config user.email)>" = "Test User <test@example.com>"
errors=$(zsh -ic 'type nvim-legacy >/dev/null && echo ZSH_OK' 2>&1 | grep -v "can't change option: zle")
if [ "$errors" = ZSH_OK ]; then ok "zsh: interactive shell starts cleanly, aliases loaded"
else not_ok "zsh: interactive shell starts cleanly, aliases loaded" "$errors"; fi

echo "# profile $profile, source $(git -C "$src" log --oneline -1)"
