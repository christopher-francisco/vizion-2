# Shared helpers for the test suite, sourced by test/run.sh and the files under test/host/.
# Results are printed as `ok`/`not ok`/`skip` lines; run.sh counts them and sets the exit code.

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
PROFILES=(personal work)

# Answers to the first-run questions; yes/no questions take their default (test/lib/init.exp).
ANSWER_NAME="Test User"
ANSWER_EMAIL="test@example.com"
ANSWER_HOST="github.example.com"

PASSED=0 FAILED=0 SKIPPED=0

ok() { PASSED=$((PASSED + 1)); echo "ok - $*"; }
skip() { SKIPPED=$((SKIPPED + 1)); echo "skip - $*"; }
not_ok() {
  FAILED=$((FAILED + 1))
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

# expect_none <description> <list>: ok if the list (of problems) is empty, else shows it.
expect_none() { if [ -z "$2" ]; then ok "$1"; else not_ok "$1" "$2"; fi; }

# same_as_expected <description> <expected file> <actual file>: compares against a snapshot in
# test/expected/. With --update (UPDATE=1) the snapshot is rewritten instead.
same_as_expected() {
  local desc=$1 expected=$2 actual=$3
  if [ "${UPDATE:-0}" = 1 ]; then
    mkdir -p "$(dirname "$expected")"
    cp "$actual" "$expected"
    ok "$desc (snapshot updated)"
  elif [ ! -f "$expected" ]; then
    not_ok "$desc" "no snapshot ${expected#"$REPO"/}; run with --update to create it"
  elif output=$(diff -u "$expected" "$actual"); then
    ok "$desc"
  else
    not_ok "$desc" "$output"
  fi
}

# cz <profile> <args…>: chezmoi on the repo with that profile's test config, a temp destination,
# state and cache. Never touches the real ~/.config/chezmoi or $HOME.
cz() {
  local dir=$WORK/$1
  shift
  chezmoi --source "$REPO" --config "$dir/chezmoi.toml" --persistent-state "$dir/state.boltdb" \
    --cache "$dir/cache" --destination "$dir/home" "$@"
}

# setup_profile <profile>: answers the first-run questions into $WORK/<profile>/chezmoi.toml.
setup_profile() {
  local dir=$WORK/$1
  mkdir -p "$dir/home"
  INIT_EXP_LOG=$dir/init.log "$REPO/test/lib/init.exp" "$1" "$ANSWER_NAME" "$ANSWER_EMAIL" "$ANSWER_HOST" \
    chezmoi init --source "$REPO" --config "$dir/chezmoi.toml" --persistent-state "$dir/state.boltdb" \
    --cache "$dir/cache" --destination "$dir/home" || return 1
  cp "$dir/chezmoi.toml" "$dir/init.toml"
  # The init above didn't record the template's hash in the real state; silence the resulting warning.
  printf '\n[warnings]\n  configFileTemplateHasChanged = false\n' >> "$dir/chezmoi.toml"
}

# rendered <profile> <script name>: path of a rendered .chezmoiscripts file (see host/20-render.sh).
rendered() { echo "$WORK/$1/archive/.chezmoiscripts/$2"; }

# Script tests: run a rendered script against the stubs in test/lib/stubs, in a clean environment.
# new_case resets the stub state; then `run_notty <script> [VAR=value…]` runs it with no terminal,
# `run_tty <script> [<pattern> <reply>]… [-- VAR=value…]` on one (answers via tty.exp). Both set
# $out (everything printed) and $rc.
new_case() {
  STUB_DIR=$(mktemp -d "$WORK/stub.XXXXXX")
  mkdir -p "$STUB_DIR/home" "$STUB_DIR/keychain"
  : > "$STUB_DIR/calls"
  STUB_GH_LOGGED_IN=
  STUB_GH_LOGIN_RC=0
}
stub_cmd() {
  CMD=(env -i HOME="$STUB_DIR/home" PATH="$REPO/test/lib/stubs:/usr/bin:/bin" STUB_LOG="$STUB_DIR/calls"
    STUB_KEYCHAIN="$STUB_DIR/keychain" STUB_GH_LOGGED_IN="$STUB_GH_LOGGED_IN" STUB_GH_LOGIN_RC="$STUB_GH_LOGIN_RC" "$@")
}
run_notty() {
  local script=$1
  shift
  stub_cmd "$@"
  rc=0
  out=$("${CMD[@]}" bash "$script" 2>&1 < /dev/null) || rc=$?
}
run_tty() {
  local script=$1 pairs=()
  shift
  while [ $# -gt 0 ] && [ "$1" != -- ]; do pairs+=("$1" "$2"); shift 2; done
  [ "${1:-}" = -- ] && shift
  stub_cmd "$@"
  rc=0
  out=$("$REPO/test/lib/tty.exp" ${pairs[@]+"${pairs[@]}"} --run "${CMD[@]}" bash "$script" 2>&1) || rc=$?
}
calls() { cat "$STUB_DIR/calls"; }

# expect_that <description> <condition…>: ok if the condition holds; on failure shows the case's
# exit code, output and stub calls.
expect_that() {
  local desc=$1
  shift
  if "$@"; then ok "$desc"; else not_ok "$desc" "rc=$rc"$'\n'"output:"$'\n'"$out"$'\n'"stub calls:"$'\n'"$(calls)"; fi
}
has() { [[ "$1" == *"$2"* ]]; }
