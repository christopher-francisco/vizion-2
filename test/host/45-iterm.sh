# iTerm rewrites the Dynamic Profiles files through their symlinks (ADR 0004). A rewrite once cut the
# default profile down to five keys, dropping its parent, colours and font; the Mac that did it kept
# the old profile in memory, so only a fresh machine showed it. Every profile but Base must keep
# Base as its parent and its own theme.
dir=$REPO/linked/iterm2/DynamicProfiles
base=$(jq -r '.Profiles[] | select(.Name == "Base") | .Guid' "$dir/00-base.json")
for f in "$dir"/*.json; do
  [ "$f" = "$dir/00-base.json" ] && continue
  broken=$(jq -r --arg base "$base" '.Profiles[]
    | select(."Dynamic Profile Parent Name" != "Base" or ."Dynamic Profile Parent GUID" != $base
        or (has("Normal Font") and has("Background Color") and has("Ansi 0 Color") | not))
    | .Name' "$f")
  if [ -z "$broken" ]; then ok "iTerm: ${f##*/}: every profile inherits from Base and has its theme"
  else not_ok "iTerm: ${f##*/}: every profile inherits from Base and has its theme" "$broken"; fi
done
