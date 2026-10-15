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
