# First-run questions: each profile's answers and defaults land in the config as expected.
for p in "${PROFILES[@]}"; do
  if ! setup_profile "$p"; then
    not_ok "$p: first-run questions answered" "$(tail -c 2000 "$WORK/$p/init.log" 2>/dev/null)"
    continue
  fi
  ok "$p: first-run questions answered"
  grep -v '^sourceDir = ' "$WORK/$p/init.toml" > "$WORK/$p/config.toml"
  same_as_expected "$p: config" "$REPO/test/expected/$p/config.toml" "$WORK/$p/config.toml"
done
