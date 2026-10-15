# The Brewfile 10-brew renders for each profile matches its snapshot, parses, and names only
# formulae and casks that exist.
for p in "${PROFILES[@]}"; do
  script=$(rendered "$p" 10-brew.sh)
  [ -f "$script" ] || { skip "$p: Brewfile (10-brew not rendered)"; continue; }
  brewfile=$WORK/$p/Brewfile
  sed -n "/<<'BREWFILE'/,/^BREWFILE$/p" "$script" | sed '1d;$d' > "$brewfile"
  same_as_expected "$p: Brewfile" "$REPO/test/expected/$p/Brewfile" "$brewfile"
  check "$p: Brewfile parses" brew bundle list --all --file="$brewfile"

  formulae=$(brew bundle list --formula --file="$brewfile" 2>/dev/null)
  casks=$(brew bundle list --cask --file="$brewfile" 2>/dev/null)
  # shellcheck disable=SC2086 # one name per word
  check "$p: every formula exists" brew info --json=v2 --formula $formulae
  # shellcheck disable=SC2086
  check "$p: every cask exists" brew info --json=v2 --cask $casks
done
