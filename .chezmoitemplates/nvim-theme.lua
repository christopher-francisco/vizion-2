{{- $cs := includeTemplate "colour-schemes.json" . | fromJson -}}
-- Rendered by chezmoi (.chezmoitemplates/nvim-theme.lua) from the first-run answer `theme` and the
-- iTerm theme profiles. docs/requirements/0.3.0_COLOUR_SCHEME_SYNC.md
return {
  -- The machine's colour scheme: used until the terminal says otherwise.
  default = {{ .theme | quote }},
  -- Each scheme's iTerm backgrounds (dark, light): a terminal background near one names the scheme.
  backgrounds = {
{{- range $scheme, $bg := $cs.schemes }}
    {{ $scheme }} = { {{ $bg.dark | quote }}, {{ $bg.light | quote }} },
{{- end }}
  },
}
