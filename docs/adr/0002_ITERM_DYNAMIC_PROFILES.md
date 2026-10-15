# ADR 0002 — iTerm2 profiles as Dynamic Profiles

- **Status:** Accepted (2026-10-15). Where the main plist lives is amended by ADR 0003.
- **Date:** 2026-10-15

## Context

Vizion keeps all of iTerm2's settings in one file, `~/.iterm2/com.googlecode.iterm2.plist`, which iTerm loads through "Load preferences from a custom folder". That file mixes profiles (fonts, colours, key maps) with global settings and UI state that iTerm rewrites on its own (window frames, update timestamps, AI settings). As a result:

- Diffs are unreadable: the `lazyvim` branch's profile work is an 8,600-line diff, mostly reordering and UI state.
- Merging two machines' changes means comparing parsed plists by script.
- Profiles can't differ per machine.
- Duplicate profile names slipped in unnoticed (`Tokyonight (Night)` and `Everforest Dark` exist twice on `lazyvim`).

iTerm2 also supports **Dynamic Profiles**: JSON (or plist) files in `~/Library/Application Support/iTerm2/DynamicProfiles/`, reloaded automatically when they change. A dynamic profile can inherit from another through `"Dynamic Profile Parent Name"`, so shared settings are written once.

## Options considered

| | Main plist only (today) | **Dynamic Profiles + slim main plist** | Dynamic Profiles, no custom prefs folder |
|---|---|---|---|
| Profile diffs | Unreadable | One small JSON file per profile family | Same |
| Shared settings across profiles | Copied into every profile | Base profile + `Dynamic Profile Parent Name` | Same |
| Per-machine profiles | No | Possible (chezmoi templates) | Possible |
| Global settings (AI off, default profile, key bindings) | In the plist | Still in the slim plist | Set by `defaults write` in a script; nothing stops later UI changes from drifting |
| Editing in the iTerm UI | Saved to the plist | Not saved back to the file (iTerm reverts on reload); edit the JSON instead | Same |

## Decision

All profiles move to Dynamic Profiles, generated once from the `lazyvim` branch's plist:

- `00-base.json` holds a `Base` profile with what every profile shares (keyboard, terminal, behaviour). The `00-` prefix makes it load first, before the profiles that inherit from it.
- One file per colour scheme (`tokyonight.json`, `everforest.json`, `catppuccin.json`, …). Each profile sets only its colours, font, size and spacing, with `"Dynamic Profile Parent Name": "Base"`.
- Duplicate names get unique ones (`Tokyonight (Night) - 5k`, `Everforest Dark - 4k`), and every profile keeps a fixed GUID.

The main plist stays in the symlinked `~/.iterm2` folder but holds only global settings. Profiles are removed from it, and `Default Bookmark Guid` points at the default dynamic profile's GUID.

## Consequences

- Profile changes are made in the JSON (`chezmoi edit --apply`), not in iTerm's UI; iTerm picks them up on save. This is documented in the README.
- The `.itermcolors` files are no longer needed for setup: colours live in the profile JSON. They can be dropped or kept as reference.
- Profiles can later be templated per machine (e.g. a smaller set on the work laptop) with no change to the approach.
- If a dynamic profile file is removed, iTerm falls back to another default profile. That's harmless but visible.
