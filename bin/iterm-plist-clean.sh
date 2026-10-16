#!/bin/bash
# Removes the copies of dynamic profiles iTerm saves into its main plist (ADR 0008): whenever iTerm
# saves its settings it writes every loaded profile into `New Bookmarks`, dynamic ones included.
# Output is in iTerm's own XML layout (plutil), so a clean save shows no diff.
# Usage: iterm-plist-clean.sh < in > out    (git clean filter `iterm-plist`, see .gitattributes)
#        iterm-plist-clean.sh FILE…         (in place; quit iTerm first or it saves over it on quit)
set -euo pipefail

# clean <file>: strips the dynamic profiles from <file>, in place.
clean() {
  local n i
  n=$(plutil -extract "New Bookmarks" raw -o - "$1" 2>/dev/null) || n=0
  for ((i = n - 1; i >= 0; i--)); do
    if [ "$(plutil -extract "New Bookmarks.$i.Is Dynamic Profile" raw -o - "$1" 2>/dev/null)" = true ]; then
      plutil -remove "New Bookmarks.$i" "$1"
    fi
  done
  plutil -convert xml1 "$1"
}

if [ $# -gt 0 ]; then
  for f in "$@"; do clean "$f"; done
  exit
fi
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
cat > "$tmp"
clean "$tmp"
cat "$tmp"
