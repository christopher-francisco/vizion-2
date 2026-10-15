#!/bin/bash
# Regression suite (docs/requirements/0.1.0_TEST_SUITE.md).
# Usage: test/run.sh [scenario…] [--host-only] [--update] [--keep] [--from-github]
#   scenario       VM scenarios to run (test/fixtures/<scenario>.sh); default: personal work
#   --host-only    host checks only (test/host/*.sh): seconds, no VM
#   --update       rewrite the snapshots in test/expected/ instead of comparing (review the diff!)
#   --keep         keep the VMs running afterwards (test/vm.sh)
#   --from-github  bootstrap the VMs from GitHub main instead of the working tree
# The host checks run first; the VMs (up to two at a time, tens of minutes) only if they pass.
# Results are printed and saved under test/out/<timestamp>/; exits non-zero if any check failed.
set -uo pipefail

host_only=0
UPDATE=0
vm_args=()
scenarios=()
for arg in "$@"; do
  case $arg in
    --host-only) host_only=1 ;;
    --update) UPDATE=1 ;;
    --keep | --from-github) vm_args+=("$arg") ;;
    -*) echo "unknown option: $arg" >&2; exit 2 ;;
    *) scenarios+=("$arg") ;;
  esac
done
[ ${#scenarios[@]} -gt 0 ] || scenarios=(personal work)

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
OUT=$REPO/test/out/$(date +%Y%m%d-%H%M%S)
WORK=$OUT/host-scratch
mkdir -p "$WORK"

{
  for f in "$REPO"/test/host/*.sh; do
    echo "# ${f#"$REPO"/}"
    # shellcheck source=/dev/null
    source "$f"
  done
  echo "# host: $PASSED passed, $FAILED failed, $SKIPPED skipped"
  [ "$FAILED" = 0 ]
} 2>&1 | tee "$OUT/host.txt"
host_rc=${PIPESTATUS[0]}

vm_rc=0
if [ "$host_only" = 0 ]; then
  if [ "$host_rc" != 0 ]; then
    echo "# VMs not started: fix the host checks first"
    vm_rc=1
  else
    # macOS runs at most two macOS VMs at once.
    for ((i = 0; i < ${#scenarios[@]}; i += 2)); do
      pids=()
      for s in "${scenarios[@]:i:2}"; do
        mkdir -p "$OUT/$s"
        "$REPO/test/vm.sh" "$s" "$OUT/$s" ${vm_args[@]+"${vm_args[@]}"} > "$OUT/$s/result.txt" 2>&1 &
        pids+=($!)
        echo "# $s: started (log: ${OUT#"$REPO"/}/$s/)"
      done
      for pid in "${pids[@]}"; do wait "$pid"; done
      for s in "${scenarios[@]:i:2}"; do cat "$OUT/$s/result.txt"; done
    done | tee "$OUT/vms.txt"
    vm_failed=$(grep -c '^not ok' "$OUT/vms.txt")
    echo "# VMs: $(grep -c '^ok' "$OUT/vms.txt") passed, $vm_failed failed" | tee -a "$OUT/vms.txt"
    [ "$vm_failed" = 0 ] || vm_rc=1
    echo "# guided steps (gh login, push token, GUI checks) come with board task 29"
  fi
fi

echo "# results: ${OUT#"$REPO"/}"
[ "$host_rc" = 0 ] && [ "$vm_rc" = 0 ]
