#!/bin/bash
# Runs inside a test VM during the guided steps (test/guided.sh), after an apply a person drove in
# the VM's Terminal. Prints one `ok`/`not ok` line per check; never prints a token.
# Usage: guided-assert.sh <profile> login <login password>   after the apply with the logins
#        guided-assert.sh <profile> reapply <apply log>      after the apply that follows it
set -uo pipefail

profile=$1 mode=$2
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
source "$here/lib.sh"
enterprise=$(data '{{ .github.enterpriseHost }}')

# credential <url>: the password git gets for a URL, without ever asking.
credential() {
  printf 'url=%s\n\n' "$1" | GIT_TERMINAL_PROMPT=0 git credential fill 2>/dev/null | sed -n 's/^password=//p'
}
# Pushing a new branch with --dry-run needs write access but changes nothing on GitHub.
can_push() { GIT_TERMINAL_PROMPT=0 git -C "$src" push --dry-run origin HEAD:refs/heads/vizion-2-test-dry-run; }
remote=$(git -C "$src" remote get-url origin)

case $mode in
  login)
    # The apply ran in the VM's Terminal, where the login Keychain is unlocked; over SSH it's locked.
    security unlock-keychain -p "$3" "$HOME/Library/Keychains/login.keychain-db" ||
      not_ok "unlock the login Keychain over SSH"
    if [ "$profile" != work ]; then
      check "gh: logged in to github.com" gh auth status --hostname github.com
      check "gh: token in the login Keychain" security find-generic-password -s gh:github.com
      if grep -q oauth_token "$HOME/.config/gh/hosts.yml" 2>/dev/null; then
        not_ok "gh: no plain-text token in hosts.yml"
      else
        ok "gh: no plain-text token in hosts.yml"
      fi
      token=$(gh auth token --hostname github.com 2>/dev/null)
      check "git: gets gh's token for github.com" test -n "$token" -a "$(credential "$remote")" = "$token"
      check "git: push --dry-run to the repo over HTTPS" can_push
    else
      token=$(security find-generic-password -s vizion-2-push -w 2>/dev/null)
      check "push token: Keychain item vizion-2-push exists" test -n "$token"
      check "git: gets the push token for this repo" test -n "$token" -a "$(credential "$remote")" = "$token"
      check "git: push --dry-run from the source" can_push
      other=$(credential https://github.com/christopher-francisco/other.git)
      check "git: another github.com repo doesn't get the push token" test -z "$other" -o "$other" != "$token"
    fi
    # gh can offer to set up git itself; ~/.gitconfig is chezmoi's.
    check "git config unchanged by the logins (chezmoi verify ~/.gitconfig)" chezmoi verify "$HOME/.gitconfig"
    ;;
  reapply)
    # The log is the terminal transcript: drop terminal control sequences (colours, cursor and
    # background-colour queries), carriage returns, blank lines and script(1)'s ^D.
    out=$(perl -pe 's/\e\[[0-9;?]*[A-Za-z]//g; s/\e\][^\a\e]*(\a|\e\\)//g; s/\r//g' "$3" |
      grep -v '^[[:space:]]*$' | grep -v '^\^D' || true)
    # The enterprise host in the test fixtures doesn't exist, so its login fails on every apply; gh
    # adds a line of its own to the error.
    [ -n "$enterprise" ] && out=$(grep -vF -e "$enterprise" -e "check your internet connection" <<< "$out" || true)
    desc="apply again on the terminal: the gh and push-token steps print nothing"
    [ -n "$enterprise" ] && desc+=" (except the failed $enterprise login)"
    if [ -z "$out" ]; then ok "$desc"; else not_ok "$desc" "$out"; fi
    ;;
  *) echo "unknown mode: $mode" >&2; exit 2 ;;
esac
