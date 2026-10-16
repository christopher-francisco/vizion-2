# ADR 0008 — Git strips iTerm's copies of dynamic profiles from the shared plist

- **Status:** Accepted (2026-10-16). Adds to ADR 0002's slim main plist: how it stays slim once iTerm saves into it.
- **Date:** 2026-10-16

## Context

iTerm reads and writes its global settings in `linked/iterm2` (ADR 0003), and the plist there holds no profiles but `iTerm defaults` (ADR 0006). Read from iTerm's source (`sources/Settings/iTermRemotePreferences.m`), matching 3.7.5 and what this Mac did on 2026-10-16:

- **When it saves.** The repo sets "save changes when quitting" (`NoSyncNeverRemindPrefsChangesLostForFile_selection` = 0; 1 is never, 2 is automatically). On quit iTerm saves if its settings differ from the folder's, comparing both **without dynamic profiles**. It also saves on Settings → Save Now and, in automatic mode, after every change. A dynamic profile change alone never causes a save: iTerm ran six hours here with all 16 dynamic profiles in its local settings and left the repo plist alone.
- **What it saves.** The whole local settings domain, filtered by key name only (`NoSync*`, `NS*`, …). Its `New Bookmarks` holds every loaded profile, dynamic ones included, fully resolved: about 1,000 lines each, 17k lines for this repo's set.

So any real setting change (one in the Settings window; iTerm's own, such as falling back to `iTerm defaults` when `This Mac` is missing; a migration after an iTerm update) followed by a quit writes every dynamic profile into the shared plist. Nothing in iTerm turns that off.

## Options considered

| | **Git clean filter** | Strip on `chezmoi apply` | Detect only (test + README) |
|---|---|---|---|
| Copies reach a commit | Never | Between applies, if committed | Unless the test is run first |
| `git status` after a copies-only save | Listed as modified, empty diff (corrected 2026-10-16, see Consequences) | Modified | Modified |
| Real setting changes | Committed as usual | Committed as usual | Committed as usual |
| Code | 30-line `plutil` script, two `git config` lines | Same script in a `run_` script | None |
| Working copy | Keeps the copies until cleaned | Cleaned on apply | Restored by hand |

## Decision

A git clean filter. `.gitattributes` sets `filter=iterm-plist` on `linked/iterm2/com.googlecode.iterm2.plist`; `bin/iterm-plist-clean.sh` removes every `New Bookmarks` entry with `Is Dynamic Profile` true and writes the result with `plutil` (iTerm's own XML layout, so a save that changes nothing else shows no diff). The macOS settings script sets `filter.iterm-plist.clean` and `required = true` in the source repo's git config, so a failing filter stops `git add` instead of storing the copies.

## Consequences

- The working copy may still hold the copies, and iTerm reads them at its next launch (not checked whether that has any effect: the dynamic profile files load over them by GUID). `bin/iterm-plist-clean.sh <plist>`, with iTerm quit, cleans it in place.
- `git status` lists the plist as modified whenever its size differs from the size recorded at the last `git add`, without running the filter: a copies-only save, or an in-place clean after the copies were staged through. `git diff` is empty; `git add` stages nothing and clears it. (Found 2026-10-16 after the first in-place clean; first written here as "clean".)
- The committed plist was converted once to `plutil`'s layout (`1` not `1.0`, 17-digit reals).
- A clone without the filter set up (no `chezmoi apply` yet) stores the copies raw; `test/host/45-iterm.sh` fails when the stored plist isn't already clean.
- iTerm also adds its own defaults to `iTerm defaults` (`Command`, `Jobs to Ignore`, …) on a save. They're real settings and get committed; `Base` sets each of them, so nothing inherits them.
- The save mode stays "when quitting": "automatically" saves after any setting change without checking whether the plist changed since launch, so it would silently write over a pulled plist. Pulled plist changes need an iTerm restart either way; an apply says so (`0.5.0_ITERM_PLIST_CLEAN.md`).
- Revisit if iTerm starts leaving dynamic profiles out of its saves, or changes the plist's layout.
