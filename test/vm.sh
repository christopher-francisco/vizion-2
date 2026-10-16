#!/bin/bash
# One clean-VM scenario, unattended (docs/requirements/0.1.0_TEST_SUITE.md T3). Called by test/run.sh.
# Usage: test/vm.sh <scenario> <results dir> [--keep] [--from-github] [--guided]
#   --keep         leave the VM running afterwards (prints its name and IP)
#   --from-github  bootstrap from christopher-francisco/vizion-2 on GitHub instead of the working tree
#   --guided       open the VM's window, and if the checks ran, leave the VM running for test/guided.sh
#                  (its name and IP go to <results dir>/vm.env)
# Prints `ok`/`not ok` lines; logs go to the results dir.
set -uo pipefail

scenario=$1 dir=$2
shift 2
keep=0 from_github=0 guided=0
for arg in "$@"; do
  case $arg in
    --keep) keep=1 ;;
    --from-github) from_github=1 ;;
    --guided) guided=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
# shellcheck source=lib/vm.sh
source "$REPO/test/lib/vm.sh"
fixture=$REPO/test/fixtures/$scenario.sh
[ -f "$fixture" ] || { echo "no scenario $scenario (test/fixtures/$scenario.sh)" >&2; exit 2; }
# shellcheck source=fixtures/personal.sh
source "$fixture"

mkdir -p "$dir"
name=vizion2-test-$scenario-$$
log=$dir/vm.log
say() { echo "# $scenario: $*"; }
# Fails the scenario: everything after this step depends on it.
fatal() { not_ok "$scenario: $1" "${2:-see ${log#"$REPO"/}}"; exit 1; }

# Deleted at the end unless kept, or handed over to the guided steps (which delete it themselves).
handed_over=0
if [ "$keep" = 0 ]; then trap '[ "$handed_over" = 1 ] || vm_delete "$name"' EXIT; fi

# The source under test: the working tree as a commit (uncommitted and new files included), so a
# change can be tested before it's committed or pushed.
if [ "$from_github" = 0 ]; then
  src=$dir/src
  git clone -q "$REPO" "$src" || fatal "snapshot the working tree"
  (cd "$REPO" && git ls-files -z -co --exclude-standard) | rsync -a --from0 --files-from=- "$REPO/" "$src/"
  # Files in HEAD but not in the working tree: deleted or renamed, staged or not.
  (cd "$REPO" && git diff -z --name-only --no-renames --diff-filter=D HEAD) | (cd "$src" && xargs -0 rm -f --)
  # and the folders they leave empty (git tracks none), which chezmoi would still read as targets.
  find "$src" -path "$src/.git" -prune -o -type d -empty -delete
  git -C "$src" add -A
  git -C "$src" -c user.name=test -c user.email=test@example.com commit -q -m "Working tree under test" > /dev/null 2>&1
  git -C "$src" remote set-url origin https://github.com/christopher-francisco/vizion-2.git
  say "source: $(git -C "$src" log --oneline -1)"
  repo_arg=
else
  repo_arg=christopher-francisco/vizion-2
  say "source: GitHub main"
fi

say "booting $name"
window=
[ "$guided" = 1 ] && window=--window
ip=$(vm_boot "$name" "$log" $window) || fatal "boot the VM"
vm_authorize "$ip" >> "$log" 2>&1 || fatal "log in to the VM"
vm_make_clean "$ip" >> "$log" 2>&1 || fatal "remove CLT and passwordless sudo"
ok "$scenario: VM $name up at $ip, without CLT or passwordless sudo"
[ "$keep" = 1 ] && say "kept: $name ($ip); ssh -i $VM_KEY $VM_USER@$ip; delete with: tart delete $name"

# The working tree goes where the one-liner would clone it; chezmoi's built-in git can't clone a
# local path (it needs git-upload-pack, from the Command Line Tools), so only the clone is skipped.
if [ "$from_github" = 0 ]; then
  tar -C "$src" -c . | vm_ssh "$ip" 'mkdir -p ~/.local/share/chezmoi && tar -x -C ~/.local/share/chezmoi' ||
    fatal "copy the source"
fi

# The README one-liner (without the repo when the source is already there), on a terminal, with a
# person's answers.
say "bootstrap (tens of minutes)"
bootstrap="sh -c \"\$(curl -fsLS get.chezmoi.io)\" -- -b ~/.local/bin init --apply --use-builtin-git true $repo_arg"
INIT_EXP_LOG=$dir/bootstrap.log INIT_EXP_SET=$INIT_SET INIT_EXP_PASSWORD=$VM_PASSWORD INIT_EXP_UNATTENDED=1 \
  "$REPO/test/lib/init.exp" "$PROFILE" "$ANSWER_NAME" "$ANSWER_EMAIL" "$ANSWER_HOST" \
  ssh -tt -i "$VM_KEY" "${SSH_OPTS[@]}" "$VM_USER@$ip" "$bootstrap"
rc=$?
# Ctrl-C at the gh browser login (init.exp, unattended) stops that apply; the next one finishes it.
if grep -aqi "one-time code" "$dir/bootstrap.log"; then
  ok "$scenario: bootstrap ran up to the gh browser login (exit $rc after Ctrl-C there)"
elif [ "$rc" = 0 ]; then
  ok "$scenario: bootstrap exits 0"
else
  fatal "bootstrap exits 0" "exit $rc; see ${dir#"$REPO"/}/bootstrap.log"
fi

# What a person would do next without a terminal: apply again; it must finish cleanly.
vm_ssh "$ip" 'export PATH=$HOME/.local/bin:$PATH; chezmoi apply' > "$dir/apply2.log" 2>&1
rc=$?
if [ "$rc" = 0 ]; then ok "$scenario: second apply (no terminal) exits 0"
else not_ok "$scenario: second apply (no terminal) exits 0" "exit $rc:"$'\n'"$(tail -20 "$dir/apply2.log")"; fi

# The checks come from this working tree, also with --from-github.
tar -C "$REPO/test" -c vm | vm_ssh "$ip" 'mkdir -p ~/vizion-2-test && tar -x -C ~/vizion-2-test' &&
  vm_ssh "$ip" "bash ~/vizion-2-test/vm/assert.sh $PROFILE" > "$dir/assert.txt" 2>&1
grep -q '^ok' "$dir/assert.txt" || not_ok "$scenario: run the checks in the VM" "$(tail -20 "$dir/assert.txt")"
sed -E "s/^(not ok|ok) - /\1 - $scenario: /" "$dir/assert.txt"

if [ "$guided" = 1 ] && grep -q '^ok' "$dir/assert.txt"; then
  printf 'name=%q\nip=%q\n' "$name" "$ip" > "$dir/vm.env"
  handed_over=1
fi
