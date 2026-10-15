# ADR 0004 — iTerm2 profiles are edited in the UI (rewritable Dynamic Profiles, symlinked)

- **Status:** Accepted (2026-10-15)
- **Date:** 2026-10-15

## Context

ADR 0002 moved the iTerm2 profiles to Dynamic Profiles and accepted that changes made in iTerm's UI are not saved back: profiles were to be edited as JSON. Christopher edits iTerm settings in the UI, so that consequence doesn't fit.

iTerm2 has a per-profile `"Rewritable": true` key that makes it write UI changes back to the profile's file. Before deciding, it was tested on iTerm 3.7.3 with a parent and a rewritable child profile, both files symlinked into `~/Library/Application Support/iTerm2/DynamicProfiles/`, and a font and a colour changed in the UI:

- The symlinks survived and the change was written into the link targets in place (same inode).
- The child file kept only what differs from its parent (it even dropped a key equal to the parent's); inherited settings were not copied in.
- iTerm loaded the symlinked files and showed the profiles right away.
- iTerm rewrites the whole file in its own JSON layout (`" : "` separators, keys in no fixed order).

## Options considered

| | Edit JSON only (ADR 0002) | **Rewritable Dynamic Profiles, symlinked from `linked/`** | Regular profiles in the slim main plist |
|---|---|---|---|
| UI edits saved | No (reverted on reload) | Yes, into the repo | Yes, into the repo |
| Diffs | Small JSON | Small JSON; key order may change on a rewrite | Whole-plist reorders, as before ADR 0002 |
| Shared `Base` profile | Yes | Yes (iTerm writes only overrides) | No inheritance |
| File mode (ADR 0003) | Copied | Symlinked: iTerm rewrites the files | iTerm folder, no symlink |

## Decision

Every dynamic profile, including `Base`, sets `"Rewritable": true`. The JSON files live in `linked/iterm2/DynamicProfiles/`, and chezmoi deploys one `symlink_<file>.json.tmpl` per file into `~/Library/Application Support/iTerm2/DynamicProfiles/`, following ADR 0003's rule (symlink only what an app rewrites). This supersedes ADR 0002's "edit the JSON, not the UI" consequence; the rest of ADR 0002 (Dynamic Profiles, `Base` + one file per colour scheme, slim main plist) stands.

## Consequences

- Profile changes are made in iTerm's UI and land in the repo's working tree; commit them like any other change (auto-commit/push on personal machines).
- The first UI edit of a file reformats it into iTerm's layout, and later edits may reorder keys, so some diffs carry noise.
- Editing a setting in `Base` through the UI changes every profile that inherits it, which is the point of `Base`, but worth knowing.
- Profiles created in the UI as new profiles are regular profiles, saved in the main plist (`linked/iterm2`), not as dynamic profiles. Move them to a JSON file by hand if they should be dynamic.
- New profile files must also get a `symlink_*.json.tmpl`; a file without one is never deployed.
