# ADR 0006 — iTerm2 profiles: Base → theme → size, and a default per machine

- **Status:** Accepted (2026-10-16). Supersedes ADR 0002's profile layout ("`Base` + one file per colour scheme, each profile sets its colours, font, size and spacing"). The rest of ADR 0002 (Dynamic Profiles, slim main plist) and ADR 0004 (rewritable, symlinked) stand.
- **Date:** 2026-10-16

## Context

ADR 0002 ported 17 profiles in 7 files, each with a full copy of its colours. Seven Tokyonight profiles had the same colours and differed only in font size and spacing, two of them were identical, and the names didn't say the size. Light and dark were separate profiles that told Neovim which one they were through `Initial Text: export THEME=…`. The default profile was the same on every machine, but the work laptop is almost always on a big monitor.

The default is `Default Bookmark Guid` in the main plist, which iTerm reads from the repo and saves back to on quit, so it can't be templated per machine; the profile files are symlinks into the repo (ADR 0004), so they can't differ per machine either.

A VM run (iTerm 3.7.5, `docs/requirements/0.2.0_ITERM_PROFILES.md`, "Verified") found two more problems with the shape ADR 0002 left:

- A dynamic profile with no parent inherits from the *default profile*. `Base` had none, and the default is a descendant of `Base`, so after any reload while iTerm runs, `Base` took the default's settings and passed them to every profile. Likely the cause of task 32's stripped profile.
- A child that names its parent only by `Dynamic Profile Parent Name` inherits its parent's parent GUID; iTerm's rewrite then diffs against the wrong profile and copies inherited keys (colours) into the child.

## Options considered

| | ADR 0002 layout | **Base → theme → size, monitors as tags** | One profile per theme, size per machine only |
|---|---|---|---|
| Profiles (Tokyonight + Everforest) | 16 | 10 (+ `iTerm defaults`, `This Mac`) | 2 |
| Colours stored | Once per profile | Once per theme | Once per theme |
| Pick a size per monitor from the Profiles menu | Yes | Yes (tags) | No |

| Default per machine | Outcome |
|---|---|
| **Per-machine dynamic profile (`This Mac`) with a fixed GUID, rendered by chezmoi, whose parent is a first-run answer** | Plist value identical everywhere; switching is a config edit + `chezmoi apply`, picked up live |
| `defaults write` of `Default Bookmark Guid` | iTerm writes it back into the shared plist: flips in git |
| Templated plist | Breaks UI sync of global settings (ADR 0003) |
| Font by display (iTerm Python API script) | A script running all the time and the API server on; not worth it while the laptop is almost always docked |

## Decision

- **Levels.** `iTerm defaults` (a regular profile in the slim plist, fixed GUID, no settings) → `Base` (shared settings) → theme profiles `Tokyonight`, `Everforest` (light and dark colours via `Use Separate Colors for Light and Dark Mode`, font family) → size profiles `<Theme> 11/13/16/20` (font and line spacing). Monitor tags (`retina`, `2k`, `4k`, `studio-display`) on the size profiles drive the Profiles menu.
- **Parents.** Every dynamic profile sets both `Dynamic Profile Parent Name` and `Dynamic Profile Parent GUID`, and parents load first (file name order, then order in the file).
- **Default.** `This Mac` (rendered `zz-default.json`, not rewritable, `Tags: []`) inherits from the size profile picked by the first-run answer `iterm.defaultProfile`; `Default Bookmark Guid` points at it. Not named `Default`: iTerm uses that name for its own regular profile.
- **Themes.** Tokyonight (Night/Day) and Everforest only; the other five are dropped. `THEME` and `Initial Text` are dropped; following the appearance in tmux and Neovim is task 36.

## Consequences

- A colour change is made once, on the theme profile; a size change on the size profile. Editing `This Mac` in the UI is not saved (not rewritable): edit the profile it points to.
- iTerm adds `Use Separate Colors for Light and Dark Mode` to a size profile when it rewrites it; harmless, allowed by the host check.
- A size profile renamed or removed must also leave the `iterm.defaultProfile` choice list (host check).
- The `DynamicProfiles` target folder is `exact_`, so chezmoi removes links to dropped files.
- Machines set up before this keep iTerm's own regular `Default` profile in the plist until iTerm next saves it; harmless, and the shared plist only ships `iTerm defaults`.
