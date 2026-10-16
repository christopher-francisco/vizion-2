# Every group named in .chezmoidata (packages, macOS defaults) is one the first-run config defines.
p=${PROFILES[0]}
if [ -f "$WORK/$p/chezmoi.toml" ]; then
  known=$(cz "$p" execute-template '{{ range $g, $_ := .groups }}{{ $g }} {{ end }}')
  used=$(cz "$p" execute-template \
    '{{ range $g, $_ := .packages }}packages.{{ $g }} {{ end }}{{ range $g, $_ := .macos.defaults }}macos.defaults.{{ $g }} {{ end }}')
  unknown=
  for entry in $used; do
    [[ " $known " == *" ${entry##*.} "* ]] || unknown+="$entry is not a group in .chezmoi.toml.tmpl"$'\n'
  done
  if [ -z "$unknown" ]; then ok "every group in .chezmoidata exists"; else not_ok "every group in .chezmoidata exists" "$unknown"; fi
else
  skip "groups in .chezmoidata (no config)"
fi

# chezmoi merges every .chezmoidata it finds in the source tree, ignored paths included, so a stray
# copy (e.g. a source snapshot left in the repo) silently overrides the real data.
stray=$(find "$REPO" -path "$REPO/.git" -prune -o -name '.chezmoidata*' ! -path "$REPO/.chezmoidata" -print)
if [ -z "$stray" ]; then ok "no .chezmoidata outside the root"; else not_ok "no .chezmoidata outside the root" "$stray"; fi
