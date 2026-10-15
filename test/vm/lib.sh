# Shared by the scripts that run inside a test VM (assert.sh, guided-assert.sh). Prints one
# `ok`/`not ok` line per check, like test/lib/common.sh on the host.
export PATH="$HOME/.local/bin:$PATH"
eval "$(/opt/homebrew/bin/brew shellenv)"
src=$(chezmoi source-path)

ok() { echo "ok - $*"; }
not_ok() {
  echo "not ok - $1"
  [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/    /'
  return 0
}
# check <description> <command…>: ok if the command succeeds; its output is shown only on failure.
check() {
  local desc=$1 output
  shift
  if output=$("$@" 2>&1); then ok "$desc"; else not_ok "$desc" "$output"; fi
}
# missing <description> <list>: ok if the list (one item per line) is empty, else shows it.
missing() { if [ -z "$2" ]; then ok "$1"; else not_ok "$1" "missing:"$'\n'"$2"; fi; }
data() { chezmoi execute-template "$1"; }
