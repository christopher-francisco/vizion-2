#!/bin/bash
# Regression suite (docs/requirements/0.1.0_TEST_SUITE.md).
# Usage: test/run.sh --host-only [--update]
#   --host-only  host checks only (test/host/*.sh): seconds, no VM
#   --update     rewrite the snapshots in test/expected/ instead of comparing (review the diff!)
# Results are printed and saved under test/out/<timestamp>/; exits non-zero if any check failed.
set -uo pipefail

host_only=0
UPDATE=0
for arg in "$@"; do
  case $arg in
    --host-only) host_only=1 ;;
    --update) UPDATE=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done
if [ "$host_only" = 0 ]; then
  echo "VM runs aren't built yet (board task 28); use --host-only" >&2
  exit 2
fi

# shellcheck source=test/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
OUT=$REPO/test/out/$(date +%Y%m%d-%H%M%S)
WORK=$OUT/work
mkdir -p "$WORK"

{
  for f in "$REPO"/test/host/*.sh; do
    echo "# ${f#"$REPO"/}"
    # shellcheck source=/dev/null
    source "$f"
  done
  echo "# $PASSED passed, $FAILED failed, $SKIPPED skipped"
  echo "# results: ${OUT#"$REPO"/}"
  [ "$FAILED" = 0 ]
} 2>&1 | tee "$OUT/summary.txt"
