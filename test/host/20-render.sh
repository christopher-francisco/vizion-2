# Every file and script renders for each profile; the managed and ignored target lists match the
# snapshots; rendered scripts pass `bash -n` and shellcheck.
if command -v shellcheck >/dev/null; then have_shellcheck=1; else have_shellcheck=0; fi

for p in "${PROFILES[@]}"; do
  [ -f "$WORK/$p/chezmoi.toml" ] || { skip "$p: rendering (no config)"; continue; }

  mkdir -p "$WORK/$p/archive"
  if output=$(cz "$p" archive --exclude externals --format tar 2>&1 > "$WORK/$p/archive.tar"); then
    tar -xf "$WORK/$p/archive.tar" -C "$WORK/$p/archive"
    ok "$p: every template renders"
  else
    not_ok "$p: every template renders" "$output"
    continue
  fi

  cz "$p" managed --exclude externals > "$WORK/$p/managed.txt" 2>&1
  same_as_expected "$p: managed targets" "$REPO/test/expected/$p/managed.txt" "$WORK/$p/managed.txt"
  cz "$p" ignored > "$WORK/$p/ignored.txt" 2>&1
  same_as_expected "$p: ignored targets" "$REPO/test/expected/$p/ignored.txt" "$WORK/$p/ignored.txt"

  for script in "$WORK/$p/archive/.chezmoiscripts/"*; do
    name=$(basename "$script")
    check "$p: $name: bash -n" bash -n "$script"
    if [ "$have_shellcheck" = 1 ]; then
      check "$p: $name: shellcheck" shellcheck --norc --shell=bash "$script"
    fi
  done
done
[ "$have_shellcheck" = 1 ] || skip "shellcheck (not installed: brew install shellcheck)"

# The suite's own scripts
if [ "$have_shellcheck" = 1 ]; then
  check "test/: shellcheck" shellcheck --shell=bash "$REPO"/test/run.sh "$REPO"/test/lib/common.sh \
    "$REPO"/test/lib/stubs/* "$REPO"/test/host/*.sh
fi
