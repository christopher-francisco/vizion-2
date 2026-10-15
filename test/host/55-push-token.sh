# run_after_55-work-push-token (work only): offers to store the push token while the Keychain item
# is missing; waits only on a terminal and never fails the apply.
script=$(rendered personal 55-work-push-token.sh)
check "personal: 55 renders to nothing" test ! -s "$script"

script=$(rendered work 55-work-push-token.sh)
if [ ! -s "$script" ]; then
  not_ok "work: 55-work-push-token renders"
else
  item=vizion-2-push
  prompt="or type s to skip"

  new_case
  echo token > "$STUB_DIR/keychain/$item"
  run_tty "$script"
  expect_that "work: 55: already stored: silent" eval '[ $rc = 0 ] && [ -z "$out" ]'

  new_case
  run_notty "$script"
  expect_that "work: 55: no terminal: prints the steps, stores nothing, exits 0" \
    eval '[ $rc = 0 ] && has "$out" "personal-access-tokens/new" && has "$out" "no terminal" && [ ! -e "$STUB_DIR/keychain/$item" ]'

  new_case
  run_tty "$script" "$prompt" s
  expect_that "work: 55: skip" eval '[ $rc = 0 ] && has "$out" skipped && [ ! -e "$STUB_DIR/keychain/$item" ]'

  new_case
  run_tty "$script" "$prompt" "" "password data" secret "retype password" secret
  expect_that "work: 55: store" \
    eval '[ $rc = 0 ] && has "$out" "token stored" && [ "$(cat "$STUB_DIR/keychain/$item" 2>/dev/null)" = secret ]'

  new_case
  run_tty "$script" "$prompt" "" "password data" secret "retype password" typo
  expect_that "work: 55: mismatched retype: not stored, exits 0" \
    eval '[ $rc = 0 ] && has "$out" "token not stored" && [ ! -e "$STUB_DIR/keychain/$item" ]'
fi
