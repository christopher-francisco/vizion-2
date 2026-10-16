# iTerm profiles: the layout of ADR 0006 (docs/requirements/0.2.0_ITERM_PROFILES.md). iTerm rewrites
# the profile files through their symlinks (ADR 0004), so a UI edit can break any of this.
dir=$REPO/linked/iterm2/DynamicProfiles
plist=$(plutil -convert json -o - "$REPO/linked/iterm2/com.googlecode.iterm2.plist")
this_mac=B45E0000-0000-4000-8000-000000000002
# Every dynamic profile in load order (files by name, then order in the file), with its position.
dyn=$(for f in "$dir"/*.json; do jq --arg f "${f##*/}" '[.Profiles | to_entries[] | .value + {_file: $f, _pos: .key}]' "$f"; done | jq -s 'add')
# jqp <filter>: runs a filter over the profiles; prints the names it selects, one per line.
jqp() { jq -r "$1" <<< "$dyn"; }
# expect_none <description> <names>: ok if no profile was named.
expect_none() { if [ -z "$2" ]; then ok "$1"; else not_ok "$1" "$2"; fi; }

# The only regular profile is iTerm defaults, Base's parent: a dynamic profile without a parent would
# inherit from the default profile, which is Base's own descendant.
regular=$(jq -c '[."New Bookmarks"[] | {Name, Guid}]' <<< "$plist")
if [ "$regular" = '[{"Name":"iTerm defaults","Guid":"B45E0000-0000-4000-8000-000000000000"}]' ]; then
  ok "iTerm: the plist's only regular profile is iTerm defaults"
else not_ok "iTerm: the plist's only regular profile is iTerm defaults" "$regular"; fi
check "iTerm: the plist's default profile is This Mac" test "$(jq -r '."Default Bookmark Guid"' <<< "$plist")" = "$this_mac"
expect_none "iTerm: Base inherits from iTerm defaults" "$(jqp '.[] | select(.Name == "Base")
  | select(."Dynamic Profile Parent Name" != "iTerm defaults" or ."Dynamic Profile Parent GUID" != "B45E0000-0000-4000-8000-000000000000") | .Name')"

# Every other profile names its parent by name and GUID, and the parent loads first. A name alone
# makes iTerm's rewrite diff against the wrong profile; a later parent is "unknown" at load.
expect_none "iTerm: every profile names a parent that loads before it, by name and GUID" "$(jqp '. as $all | .[] | select(.Name != "Base") | . as $p
  | select([$all[] | select(.Guid == $p."Dynamic Profile Parent GUID" and .Name == $p."Dynamic Profile Parent Name"
      and (._file < $p._file or (._file == $p._file and ._pos < $p._pos)))] | length != 1) | .Name')"

# Themes (parent Base) hold the light and dark colours; sizes (parent a theme) only font, spacing, tags.
themes=$(jqp '[.[] | select(."Dynamic Profile Parent Name" == "Base") | .Name] | join(", ")')
check "iTerm: the themes are Everforest, Tokyonight" test "$themes" = "Everforest, Tokyonight"
expect_none "iTerm: every theme has light and dark colours" "$(jqp '.[] | select(."Dynamic Profile Parent Name" == "Base")
  | select(."Use Separate Colors for Light and Dark Mode" != true
      or ([range(16) as $i | "Ansi \($i) Color", "Background Color", "Foreground Color"] as $k
          | [$k[] | "\(.) (Light)", "\(.) (Dark)"] - keys | length > 0)) | .Name')"
expect_none "iTerm: size profiles set a font and no colours" "$(jqp '[.[] | select(."Dynamic Profile Parent Name" == "Base") | .Name] as $themes
  | .[] | select(."Dynamic Profile Parent Name" as $n | $themes | index($n))
  | select((has("Normal Font") | not) or (to_entries | any(.key | test("Color( \\((Light|Dark)\\))?$")))) | .Name')"
expect_none "iTerm: no profile sets Initial Text (THEME is gone)" "$(jqp '.[] | select(has("Initial Text")) | .Name')"

# Each monitor tag offers a small and a big size of each theme.
uneven=$(jqp '[.[] | select(."Dynamic Profile Parent Name" == "Base") | .Name] as $themes
  | [.[] | select(."Dynamic Profile Parent Name" as $n | $themes | index($n))] as $sizes
  | ["retina", "2k", "4k", "studio-display"][] as $m | $themes[] as $t
  | [$sizes[] | select(."Dynamic Profile Parent Name" == $t and (.Tags | index($m)))] | select(length != 2)
  | "\($m): \($t): \(map(.Name))"')
expect_none "iTerm: every monitor tag has two sizes of each theme" "$uneven"

# The first-run choice list is exactly the size profiles, and This Mac renders for each test profile.
sizes=$(jqp '[.[] | select(."Dynamic Profile Parent Name" == "Base") | .Name] as $themes
  | .[] | select(."Dynamic Profile Parent Name" as $n | $themes | index($n)) | .Name' | sort)
choices=$(sed -n 's/.*\$sizes := list \(.*\) }}$/\1/p' "$REPO/.chezmoi.toml.tmpl" | tr ' ' '\n' | paste -sd' ' - |
  grep -o '"[^"]*"' | tr -d '"' | sort)
if [ -n "$choices" ] && [ "$choices" = "$sizes" ]; then ok "iTerm: the default-profile choices are the size profiles"
else not_ok "iTerm: the default-profile choices are the size profiles" "$(diff <(echo "$choices") <(echo "$sizes"))"; fi
for p in "${PROFILES[@]}"; do
  f="$WORK/$p/archive/Library/Application Support/iTerm2/DynamicProfiles/zz-default.json"
  [ -f "$f" ] || { not_ok "$p: iTerm: This Mac rendered" "no ${f#"$WORK"/}"; continue; }
  want=$(jq -r '.iterm.defaultProfile' <<< "$(cz "$p" data --format json)")
  got=$(jq -c '.Profiles[0] | [.Name, .Guid, ."Dynamic Profile Parent Name", ."Dynamic Profile Parent GUID", .Tags]' "$f")
  guid=$(jqp ".[] | select(.Name == \"$want\") | .Guid")
  check "$p: iTerm: This Mac inherits from $want" test "$got" = "[\"This Mac\",\"$this_mac\",\"$want\",\"$guid\",[]]"
done
