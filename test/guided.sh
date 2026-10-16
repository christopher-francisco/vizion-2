#!/bin/bash
# Guided steps for one VM scenario (docs/requirements/0.1.0_TEST_SUITE.md T4): what only a person
# can do, at the VM's window. Called by test/run.sh after `test/vm.sh --guided` left the VM running.
# Usage: test/guided.sh <scenario> <results dir> [--keep]
#   --keep   leave the VM running afterwards
# Instructions go to the terminal (stderr); `ok`/`not ok` lines to stdout. Deletes the VM at the end.
set -uo pipefail

scenario=$1 dir=$2
shift 2
keep=0
for arg in "$@"; do
  case $arg in
    --keep) keep=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
# shellcheck source=lib/vm.sh
source "$REPO/test/lib/vm.sh"
# shellcheck source=fixtures/personal.sh
source "$REPO/test/fixtures/$scenario.sh"
# shellcheck source=/dev/null
source "$dir/vm.env" # name, ip

if [ "$keep" = 0 ]; then trap 'vm_delete "$name"' EXIT; fi

tell() { printf '%s\n' "$@" >&2; }
pause() { read -r -p "${1:-Press Enter to continue.} " _ < /dev/tty; }
# ask <check> <what to do>: a check only a person can make, answered y/n.
ask() {
  local answer why
  tell "" "$2"
  while :; do
    read -r -p "$1? [y/n] " answer < /dev/tty
    case $answer in
      y | Y) ok "$scenario: $1 (checked by hand)"; return ;;
      n | N)
        read -r -p "What did you see? " why < /dev/tty
        not_ok "$scenario: $1 (checked by hand)" "$why"
        return
        ;;
    esac
  done
}
in_vm() { sed -E "s/^(not ok|ok) - /\1 - $scenario: /"; }

# apply <n>: runs `chezmoi apply` in a new Terminal window in the VM: on its own terminal, where the
# login Keychain is unlocked (over SSH, gh could save its token to a plain-text file instead).
# Transcript and exit code go to ~/vizion-2-test/apply-<n>.log and .rc.
apply() {
  vm_ssh "$ip" "f=~/vizion-2-test/apply-$1.command && rm -f \${f%.command}.rc && cat > \$f && chmod +x \$f && open -a Terminal \$f" <<'COMMAND'
#!/bin/bash
# Written by test/guided.sh: one chezmoi apply on the VM's own terminal.
run=${0%.command}
export PATH=$HOME/.local/bin:$PATH
script -q "$run.log" bash -c 'chezmoi apply; echo $? > "$1.rc.part"' _ "$run"
mv "$run.rc.part" "$run.rc"
echo
echo "vizion-2 test: apply finished (exit $(cat "$run.rc")). Back to the terminal on the Mac."
COMMAND
}
# wait_apply <n> <description> <timeout in s>: waits for apply <n> to finish; ok if it exits 0.
wait_apply() {
  local rc waited=0
  tell "Waiting for the apply in the VM's Terminal to finish…"
  until rc=$(vm_ssh "$ip" "cat ~/vizion-2-test/apply-$1.rc" 2>/dev/null); do
    sleep 5
    waited=$((waited + 5))
    if [ "$waited" -ge "$3" ]; then
      not_ok "$scenario: $2" "not finished after $3 s; see the VM's Terminal"
      return 1
    fi
  done
  vm_ssh "$ip" "cat ~/vizion-2-test/apply-$1.log" > "$dir/guided-apply-$1.log" 2>&1
  if [ "$rc" = 0 ]; then ok "$scenario: $2"
  else not_ok "$scenario: $2" "exit $rc:"$'\n'"$(tail -20 "$dir/guided-apply-$1.log")"; fi
}
# The checks come from this working tree.
tar -C "$REPO/test" -c vm | vm_ssh "$ip" 'mkdir -p ~/vizion-2-test && tar -x -C ~/vizion-2-test'
vm_assert() { vm_ssh "$ip" "bash ~/vizion-2-test/vm/guided-assert.sh $PROFILE $*" 2>&1 | in_vm; }

printf '\a' >&2
osascript -e "display notification \"$scenario: the VM needs you\" with title \"vizion-2 tests\"" 2>/dev/null
tell "" "=== Guided steps: $scenario, in the VM window \"$name\" ($ip) ===" ""
if [ "$PROFILE" = work ]; then
  tell "You'll create a 1-day push token on github.com, store it in the VM, then check iTerm and Karabiner."
else
  tell "You'll log gh in to github.com from the VM, then check iTerm and Karabiner."
fi
pause "Press Enter when you're at the VM window."

# --- T4.3/T4.4: the apply with the logins
apply 1
if [ "$PROFILE" = work ]; then
  tell "" "A Terminal window in the VM runs chezmoi apply and asks for the vizion-2 push token." \
    "The gh login to $ANSWER_HOST fails first: that host doesn't exist, it's expected." \
    "1. On this Mac, signed in to the personal account, open:" \
    "   https://github.com/settings/personal-access-tokens/new" \
    "   - Name: vizion-2 test $(date +%Y-%m-%d), Expiration: Custom, tomorrow" \
    "   - Repository access: Only select repositories → christopher-francisco/vizion-2" \
    "   - Repository permissions → Contents: Read and write (nothing else)" \
    "2. Paste the token here: it goes on the VM's clipboard (input hidden; Enter alone skips this)."
  IFS= read -rs token < /dev/tty
  tell ""
  [ -n "$token" ] && printf %s "$token" | vm_ssh "$ip" pbcopy
  unset token
  tell "3. In the VM's Terminal: Enter, then Cmd+V and Enter, twice."
else
  tell "" "A Terminal window in the VM runs chezmoi apply and shows gh's one-time code." \
    "1. Press Enter in the VM's Terminal (Safari opens there; use it, or ignore it)." \
    "2. Open https://github.com/login/device (on this Mac or in the VM), signed in to the account" \
    "   that owns the repo, enter the code and authorize GitHub CLI." \
    "3. If gh asks anything else in the VM's Terminal, take its default (Enter)."
fi
wait_apply 1 "apply with the logins, on the VM's terminal, exits 0" 1800
[ "$PROFILE" = work ] && vm_ssh "$ip" 'pbcopy < /dev/null'
vm_assert login "$VM_PASSWORD"

# --- T4.5: once logged in, an apply has nothing to ask
tell "" "Applying again in a new Terminal window in the VM; nothing to do."
apply 2
wait_apply 2 "apply again on the VM's terminal exits 0" 900 &&
  vm_assert reapply '$HOME/vizion-2-test/apply-2.log'

# --- T4.6: what only shows on screen
if [ "$(vm_ssh "$ip" 'PATH=$HOME/.local/bin:$PATH chezmoi execute-template "{{ .groups.gui }}"')" = true ]; then
  # The default is "This Mac", which inherits from the size profile answered on first run (ADR 0006).
  parent=$(vm_ssh "$ip" 'PATH=$HOME/.local/bin:$PATH chezmoi execute-template "{{ .iterm.defaultProfile }}"')
  vm_ssh "$ip" 'open -a iTerm'
  ask "iTerm opens on the \"This Mac\" profile, at the size of $parent" \
    "iTerm just opened in the VM. Session → Edit Session… shows the window's profile (This Mac); its Text tab shows the font size (${parent##* }pt)."
  ask "iTerm's colours follow the macOS appearance" \
    "Leave that iTerm window open and switch the VM between Light and Dark in System Settings → Appearance: the window's colours should change each time (Tokyonight Day / Night)."
  ask "Option+Left/Right jump by word in iTerm" \
    "In that iTerm window, type: echo one two three, then press Option+Left twice and Option+Right once."
  profiles=$(jq -r '[.profiles[].name] | join(", ")' "$REPO/linked/karabiner/karabiner.json")
  vm_ssh "$ip" 'open -a Karabiner-Elements'
  ask "Karabiner loads its config (profiles $profiles)" \
    "Karabiner-Elements just opened in the VM (skip its requests to allow the driver: a VM can't load it)." \
    "Its Profiles page should list: $profiles."
fi

# --- T4.7: what outlives the VM
tell "" "Before you go, clean up on github.com (deleting the VM doesn't):"
if [ "$PROFILE" = work ]; then
  tell "- Delete the test token: https://github.com/settings/personal-access-tokens (it expires tomorrow anyway)."
else
  tell "- gh's token from this login: https://github.com/settings/applications → Authorized OAuth Apps →" \
    "  GitHub CLI → Revoke. That revokes every gh login of the account, this Mac's included:" \
    "  run gh auth login here afterwards. (The token itself is gone with the VM.)"
fi
if [ "$keep" = 1 ]; then
  tell "Kept: $name ($ip); ssh -i $VM_KEY $VM_USER@$ip; delete with: tart delete $name"
else
  pause "Press Enter to delete the VM."
fi
