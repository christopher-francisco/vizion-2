# Colour schemes in tmux and Neovim (docs/requirements/0.3.0_COLOUR_SCHEME_SYNC.md): every iTerm theme
# has a tmux dark/light pair and Neovim backgrounds; the rendered hook and Neovim modules pick the
# right scheme. The attach flow itself runs in the VMs (test/vm/attach.py).
themes=$REPO/dot_config/tmux/themes
printf 'theme = "tokyonight"\n' > "$WORK/colour-schemes.toml" # the template reads only the profiles
schemes_json=$(chezmoi --source "$REPO" --config "$WORK/colour-schemes.toml" execute-template '{{ includeTemplate "colour-schemes.json" . }}' 2>&1)
schemes=$(jq -r '.schemes | keys[]' <<< "$schemes_json" 2>/dev/null)
check "colour schemes: read from the iTerm theme profiles (everforest, tokyonight)" test "$(paste -sd' ' - <<< "$schemes")" = "everforest tokyonight"

# tmux: a dark and a light theme per scheme, setting the same options (a re-source replaces them all).
bad=
for s in $schemes; do
  for a in dark light; do [ -f "$themes/$s-$a.tmux.conf" ] || bad+="$s-$a.tmux.conf missing"$'\n'; done
  [ -f "$themes/$s-dark.tmux.conf" ] && [ -f "$themes/$s-light.tmux.conf" ] || continue
  diff=$(diff <(grep -o '^set -g @[a-z_]*' "$themes/$s-dark.tmux.conf") <(grep -o '^set -g @[a-z_]*' "$themes/$s-light.tmux.conf")) ||
    bad+="$s: dark and light set different options:"$'\n'"$diff"$'\n'
done
expect_none "tmux: every scheme has a dark and a light theme with the same options" "${bad%$'\n'}"

# Neovim: no config sets 'background', or Neovim stops following the terminal's light/dark.
# follow_terminal.lua sets it on purpose, from tmux's choice, after taking Neovim's own following out.
set_bg=$(grep -rnE "(vim\.(o|opt|go)|opt)\.background *=|set (bg|background)=|nvim_set_option_value\(['\"]background" \
  "$REPO/dot_config/exact_nvim" "$REPO/dot_config/exact_nvim-legacy" | grep -v "/follow_terminal.lua:" || true)
expect_none "Neovim: no config sets 'background'" "$set_bg"

# Neovim: the nearest-background match, on iTerm-style answers (4 and 2 hex digits per channel).
mod=$REPO/dot_config/exact_nvim/exact_lua/exact_config/follow_terminal.lua
printf '%s' "$schemes_json" > "$WORK/colour-schemes.json"
cat > "$WORK/match.lua" <<EOF
local data = vim.json.decode(io.open("$WORK/colour-schemes.json"):read("a"))
local backgrounds = {}
for scheme, bg in pairs(data.schemes) do backgrounds[scheme] = { bg.dark, bg.light } end
package.loaded["config.theme"] = { backgrounds = backgrounds }
local m = dofile("$mod")
local wrong = {}
local function expect(sequence, want)
  local got = m.scheme_for(sequence)
  if got ~= want then table.insert(wrong, ("%q: got %s, want %s"):format(sequence, tostring(got), tostring(want))) end
end
for scheme, bg in pairs(data.schemes) do
  for _, hex in ipairs({ bg.dark, bg.light }) do
    local r, g, b = hex:sub(2, 3), hex:sub(4, 5), hex:sub(6, 7)
    expect("\27]11;rgb:" .. r .. r .. "/" .. g .. g .. "/" .. b .. b, scheme)
    expect("\27]11;rgb:" .. r .. "/" .. g .. "/" .. b, scheme)
  end
end
expect("\27]11;rgb:8080/8080/8080", nil) -- another terminal's grey: keep the scheme
expect("\27]10;rgb:1a1a/1b1b/2626", nil) -- a foreground answer
io.write(table.concat(wrong, "\n"))
EOF
expect_none "Neovim: each iTerm background picks its scheme, others none" "$(nvim --clean --headless -l "$WORK/match.lua" 2>&1)"

# Neovim: a headless run inside tmux (chezmoi's plugin sync) sets nothing up and raises nothing.
expect_none "Neovim: follow_terminal in a headless Neovim inside tmux: no errors" "$(TMUX=/tmp/none,1,0 TMUX_PANE=%0 \
  nvim --clean --headless --cmd "lua package.loaded['config.theme'] = { default = 'tokyonight', backgrounds = {} }" \
  -c "lua dofile('$mod').setup()" +qa 2>&1)"

for p in "${PROFILES[@]}"; do
  arch=$WORK/$p/archive
  [ -d "$arch" ] || { skip "$p: colour schemes (not rendered)"; continue; }
  theme=$(cz "$p" execute-template '{{ .theme }}')

  # Neovim: both configs default to the answer and know every scheme's backgrounds.
  for app in nvim nvim-legacy; do
    got=$(nvim --clean --headless -l /dev/stdin <<< "io.write(vim.json.encode(dofile('$arch/.config/$app/lua/config/theme.lua')))" 2>&1)
    want=$(jq -c --arg t "$theme" '{default: $t, backgrounds: (.schemes | map_values([.dark, .light]))}' <<< "$schemes_json")
    check "$p: $app: theme.lua: the $theme default and every scheme's backgrounds" test "$(jq -cS . <<< "$got" 2>&1)" = "$(jq -cS . <<< "$want")"
  done

  # tmux: the hook maps every iTerm profile to its scheme, and anything else to the answer.
  hook=$arch/.config/tmux/theme.sh
  [ "${have_shellcheck:-0}" = 1 ] && check "$p: tmux: theme.sh: shellcheck" shellcheck --norc --shell=sh "$hook"
  mkdir -p "$WORK/stub-tmux"
  # A tmux that keeps options as files in $STUB_OPTS, answers for one client (ITERM_PROFILE
  # $FAKE_PROFILE, light/dark $FAKE_THEME) and prints what it's asked to source.
  cat > "$WORK/stub-tmux/tmux" <<'STUB'
#!/bin/sh
case $1 in
  display) case $5 in *client_session*) echo s ;; *client_theme*) echo "$FAKE_THEME" ;; esac ;;
  show-environment) echo "ITERM_PROFILE=$FAKE_PROFILE" ;;
  set) [ "$2" = -s ] || [ "$2" = -g ]; printf '%s' "$4" > "$STUB_OPTS/$3" ;;
  show) cat "$STUB_OPTS/$3" 2>/dev/null ;;
  source-file) echo "$2" ;;
esac
STUB
  chmod +x "$WORK/stub-tmux/tmux"
  bad=
  while IFS=$'\t' read -r name scheme; do
    for a in dark light; do
      opts=$(mktemp -d "$WORK/opts.XXXXXX")
      got=$(STUB_OPTS=$opts FAKE_PROFILE=$name FAKE_THEME=$a HOME=/h PATH="$WORK/stub-tmux:$PATH" sh "$hook" attached /dev/ttys001)
      [ "$got" = "/h/.config/tmux/themes/$scheme-$a.tmux.conf" ] || bad+="$name $a: $got"$'\n'
    done
  done < <(jq -r '.profiles | to_entries[] | "\(.key)\t\(.value)"' <<< "$schemes_json"; printf 'This Mac\t%s\n' "$theme")
  expect_none "$p: tmux: theme.sh sources each iTerm profile's scheme, This Mac's is $theme" "${bad%$'\n'}"
done
