# run_after_50-gh-auth: logs gh in to each host of the profile, only on a terminal, never failing
# the apply, and never handing gh a token from the environment.
for p in "${PROFILES[@]}"; do
  script=$(rendered "$p" 50-gh-auth.sh)
  [ -s "$script" ] || { not_ok "$p: 50-gh-auth renders"; continue; }
  if [ "$p" = work ]; then host=$ANSWER_HOST other=github.com; else host=github.com other=$ANSWER_HOST; fi
  login="gh auth login --hostname $host --git-protocol https --web"

  new_case
  run_notty "$script"
  expect_that "$p: 50: logged out, no terminal: prints the login command, exits 0" \
    eval '[ $rc = 0 ] && has "$out" "not logged in to $host; run: $login" && ! has "$(calls)" "auth login"'
  expect_that "$p: 50: only asks about $host" \
    eval 'has "$(calls)" "--hostname $host" && ! has "$(calls)" "--hostname $other "'

  new_case
  run_tty "$script"
  expect_that "$p: 50: logged out, terminal: runs the login" \
    eval '[ $rc = 0 ] && has "$(calls)" "$login" && ! has "$out" failed'

  new_case
  STUB_GH_LOGIN_RC=1
  run_tty "$script"
  expect_that "$p: 50: failed login: warns, exits 0" \
    eval '[ $rc = 0 ] && has "$out" "gh: login to $host failed; run: $login"'

  new_case
  STUB_GH_LOGGED_IN=$host
  run_tty "$script"
  expect_that "$p: 50: logged in: silent, no login" \
    eval '[ $rc = 0 ] && [ -z "$out" ] && ! has "$(calls)" "auth login"'

  new_case
  run_tty "$script" -- GITHUB_TOKEN=t1 GH_TOKEN=t2 GH_ENTERPRISE_TOKEN=t3 GITHUB_ENTERPRISE_TOKEN=t4
  expect_that "$p: 50: token env vars never reach gh" \
    eval '[ -n "$(calls)" ] && ! grep -v "\[env: none\]" "$STUB_DIR/calls" | grep -q .'
done
