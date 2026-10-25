# Claude Code's theme follows the iTerm window (docs/requirements/0.8.0_CLAUDE_CODE_THEME.md): a
# palette per scheme and light/dark, the sync script picking the right one, the settings merge.
palettes=$REPO/dot_claude/vizion/themes
[ -n "${schemes_json:-}" ] || { skip "Claude Code theme (no colour schemes: 46-colour-schemes.sh)"; return 0; }
schemes=$(jq -r '.schemes | keys[]' <<< "$schemes_json")

# A palette for each scheme's dark and light, on the matching base, with the same tokens, all colours.
bad=
for s in $schemes; do
  for a in dark light; do
    f=$palettes/$s-$a.json
    [ -f "$f" ] || { bad+="$s-$a.json missing"$'\n'; continue; }
    jq -e --arg a "$a" '.base == $a and (.overrides | length > 0) and all(.overrides[]; test("^#[0-9a-f]{6}$"))' "$f" > /dev/null ||
      bad+="$s-$a.json: base isn't $a, or a value isn't #rrggbb"$'\n'
  done
  [ -f "$palettes/$s-dark.json" ] && [ -f "$palettes/$s-light.json" ] || continue
  diff=$(diff <(jq -r '.overrides | keys[]' "$palettes/$s-dark.json") <(jq -r '.overrides | keys[]' "$palettes/$s-light.json")) ||
    bad+="$s: dark and light set different tokens:"$'\n'"$diff"$'\n'
done
expect_none "Claude Code: every scheme has a dark and a light palette with the same tokens" "${bad%$'\n'}"

mkdir -p "$WORK/stub-claude"
# A tmux whose @theme is $FAKE_TMUX_THEME, and a `defaults` answering AppleInterfaceStyle with $FAKE_STYLE.
cat > "$WORK/stub-claude/tmux" <<'STUB'
#!/bin/sh
[ "$1 $2 $3" = "show -gv @theme" ] && printf '%s\n' "$FAKE_TMUX_THEME"
STUB
cat > "$WORK/stub-claude/defaults" <<'STUB'
#!/bin/sh
[ -n "$FAKE_STYLE" ] && printf '%s\n' "$FAKE_STYLE" || exit 1
STUB
chmod +x "$WORK/stub-claude/tmux" "$WORK/stub-claude/defaults"

for p in "${PROFILES[@]}"; do
  arch=$WORK/$p/archive
  [ -d "$arch" ] || { skip "$p: Claude Code theme (not rendered)"; continue; }
  theme=$(cz "$p" execute-template '{{ .theme }}')
  sync=$arch/.claude/vizion/theme.sh

  check "$p: Claude Code: themes/vizion.json starts as $theme-dark" cmp "$palettes/$theme-dark.json" "$arch/.claude/themes/vizion.json"
  [ "${have_shellcheck:-0}" = 1 ] && check "$p: Claude Code: theme.sh: shellcheck" shellcheck --norc --shell=sh "$sync"

  # run_sync <expected palette> <args…> [-- VAR=value…]: theme.sh in a fresh home; vizion.json must
  # be that palette (or absent for "none") and nothing printed.
  run_sync() {
    local want=$1 args=() home
    shift
    while [ $# -gt 0 ] && [ "$1" != -- ]; do args+=("$1"); shift; done
    [ "${1:-}" = -- ] && shift
    home=$(mktemp -d "$WORK/claude-home.XXXXXX")
    mkdir -p "$home/.claude/vizion" && cp -R "$arch/.claude/vizion/themes" "$home/.claude/vizion/"
    local out rc=0
    out=$(env -i HOME="$home" PATH="$WORK/stub-claude:/usr/bin:/bin" "$@" sh "$sync" ${args[@]+"${args[@]}"} 2>&1 < /dev/null) || rc=$?
    if [ "$rc" != 0 ] || [ -n "$out" ]; then echo "rc=$rc output: $out"
    elif [ "$want" = none ]; then [ ! -e "$home/.claude/themes/vizion.json" ] || echo "wrote $(jq -r .name "$home/.claude/themes/vizion.json")"
    else cmp -s "$palettes/$want.json" "$home/.claude/themes/vizion.json" || echo "got $(jq -r .name "$home/.claude/themes/vizion.json" 2>&1)"
    fi
  }

  # Outside tmux: the window's iTerm profile, the macOS appearance.
  bad=
  while IFS=$'\t' read -r name scheme; do
    got=$(run_sync "$scheme-dark" -- ITERM_PROFILE="$name" FAKE_STYLE=Dark) && [ -z "$got" ] || bad+="$name dark: $got"$'\n'
    got=$(run_sync "$scheme-light" -- ITERM_PROFILE="$name") && [ -z "$got" ] || bad+="$name light: $got"$'\n'
  done < <(jq -r '.profiles | to_entries[] | "\(.key)\t\(.value)"' <<< "$schemes_json"; printf 'This Mac\t%s\n' "$theme")
  got=$(run_sync "$theme-dark" -- FAKE_STYLE=Dark) && [ -z "$got" ] || bad+="no iTerm profile: $got"$'\n'
  expect_none "$p: Claude Code: outside tmux, each iTerm profile's scheme in the macOS appearance; This Mac's is $theme" "${bad%$'\n'}"

  # Inside tmux: tmux's choice, whatever the window; from tmux's hook: its arguments.
  expect_none "$p: Claude Code: inside tmux, tmux's @theme" \
    "$(run_sync everforest-light -- TMUX=/tmp/t,1,0 FAKE_TMUX_THEME=everforest-light ITERM_PROFILE=Tokyonight FAKE_STYLE=Dark)"
  expect_none "$p: Claude Code: inside tmux with no @theme yet, the window" \
    "$(run_sync tokyonight-dark -- TMUX=/tmp/t,1,0 ITERM_PROFILE=Tokyonight FAKE_STYLE=Dark)"
  expect_none "$p: Claude Code: from tmux's hook, its scheme and appearance" "$(run_sync tokyonight-light tokyonight light)"
  expect_none "$p: Claude Code: an unknown scheme writes nothing" "$(run_sync none nosuch dark)"

  # tmux's hook hands the window's scheme to Claude Code's.
  home=$(mktemp -d "$WORK/claude-home.XXXXXX") opts=$(mktemp -d "$WORK/opts.XXXXXX")
  mkdir -p "$home/.claude/vizion"
  printf '#!/bin/sh\necho "claude $*"\n' > "$home/.claude/vizion/theme.sh" && chmod +x "$home/.claude/vizion/theme.sh"
  got=$(STUB_OPTS=$opts FAKE_PROFILE="Everforest" FAKE_THEME=light HOME=$home PATH="$WORK/stub-tmux:$PATH" \
    sh "$arch/.config/tmux/theme.sh" attached /dev/ttys001 | grep '^claude')
  check "$p: tmux: theme.sh tells Claude Code the window's scheme" test "$got" = "claude everforest light"

  # settings.json: the theme and the two hooks, once, leaving the rest.
  modify=$WORK/$p/modify_settings.sh
  cz "$p" execute-template < "$REPO/dot_claude/modify_settings.json.tmpl" > "$modify"
  [ "${have_shellcheck:-0}" = 1 ] && check "$p: Claude Code: modify_settings.json: shellcheck" shellcheck --norc --shell=sh "$modify"
  cmd=$(cz "$p" execute-template '{{ joinPath .chezmoi.homeDir ".claude/vizion/theme.sh" }}')
  mine='{"theme":"auto","model":"x","hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"/other"}]}],"Stop":[{"hooks":[{"type":"command","command":"/other"}]}]}}'
  once=$(sh "$modify" <<< "$mine") twice=$(sh "$modify" <<< "$once")
  want=$(jq -c --arg c "$cmd" '.theme = "custom:vizion" | .hooks.SessionStart += [{hooks: [{type: "command", command: $c}]}]
    | .hooks.UserPromptSubmit = [{hooks: [{type: "command", command: $c}]}]' <<< "$mine")
  check "$p: Claude Code: settings.json gets the theme and both hooks, keeping the rest" test "$(jq -c . <<< "$once")" = "$want"
  check "$p: Claude Code: settings.json: a second apply changes nothing" test "$twice" = "$once"
  check "$p: Claude Code: settings.json: created when missing" test "$(sh "$modify" < /dev/null | jq -c '[.theme, (.hooks | keys)]')" = '["custom:vizion",["SessionStart","UserPromptSubmit"]]'
  check "$p: Claude Code: settings.json: not JSON, left as it is" test "$(sh "$modify" <<< 'not json')" = "not json"
  mkdir -p "$WORK/no-jq" && ln -sf /bin/cat "$WORK/no-jq/cat" # macOS has a /usr/bin/jq
  check "$p: Claude Code: settings.json: no jq, left as it is" test "$(env -i PATH="$WORK/no-jq" /bin/sh "$modify" <<< "$mine")" = "$mine"
done
