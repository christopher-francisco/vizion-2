# iTerm profiles: themes, sizes and a default per machine

- **Status:** Direction agreed (2026-10-16): three-level profiles, Tokyonight and Everforest only, one profile for light and dark, `THEME` dropped, per-machine default. Pending the checks under "To verify"; once they pass, write ADR 0006 (supersedes ADR 0002's profile layout) and promote this to `requirements/`.

## Problem

1. **Too many near-identical profiles.** 17 profiles in 7 files. The 7 Tokyonight profiles have the same colours and differ only in font size and line spacing; two are identical (`- Big` and `- 5k`: 16pt, 1.5). Names say nothing about size (`- 4k small` is the smallest, 11pt; `- Small` is 13pt). Every profile repeats keys that never vary (`Non Ascii Font`, `Minimum Contrast`, `Horizontal Spacing`, `Transparency`, `Blur`, `Shortcut`, `Background Image Location`).
2. **Light and dark are separate profiles** (`Everforest Light`/`Dark`), and each tells Neovim which one it is through `Initial Text: export THEME=…`, which only works in the first shell of a session and never reaches tmux.
3. **The default profile is the same on every machine.** The work laptop is almost always on a big monitor and wants a larger font. The default is `Default Bookmark Guid` in the main plist, which iTerm reads straight from the repo and saves back into on quit, so it can't be templated, and a per-machine `defaults write` would flip the value in git on every quit. The profile files are symlinks into the repo (ADR 0004), so they can't differ per machine either.

## Proposal

### Three levels: Base → theme → size

```
Base                         keyboard, terminal, behaviour + the keys every profile repeats today
├─ Tokyonight                light + dark colours, font family; tag "base"
│  ├─ Tokyonight 11          Normal Font + Vertical Spacing + monitor tags
│  ├─ Tokyonight 13
│  ├─ Tokyonight 16
│  └─ Tokyonight 20
└─ Everforest                (same shape)
   └─ Everforest 11 … 20
Default                      rendered per machine; parent = one size profile
```

- **Theme profiles** (`Tokyonight`, `Everforest`) hold only colours and the font family. They're parents, not meant to be opened, so they carry the tag `base` to sit in the same submenu as `Base`, out of the way.
- **Size profiles** set `Normal Font` (family + size: iTerm keeps both in one string, so each theme has its own sizes) and `Vertical Spacing`, and are tagged with the monitors they're for. Named by point size, so the name says what you get.
- **Monitor tags** drive the Profiles menu, as today (`Profiles > retina > Tokyonight 13`). A size used on several monitors is one profile with several tags instead of one copy per monitor. Each profile also has its theme tag (`tokyonight`, `everforest`) so `Profiles > tokyonight` lists every size.

Small and big per monitor, from today's profiles:

| Monitor tag | Small | Big | Today |
|---|---|---|---|
| `retina` (MacBook) | 13 | 16 | `(Night)` 13 / 1.5, `- Big` 16 / 1.5 |
| `2k` | 13 | 20 | `- Small` 13 / 1.33, `- 2k` 20 / 1.7 |
| `4k` | 11 | 16 | `- 4k small` 11 / 1.5, `- 4k` 16 / 1.7 |
| `studio-display` (5K) | 13 | 16 | only `- 5k` 16 / 1.5 (tag `5k`); small is new |

So four size profiles per theme:

| Profile | Font | Line spacing | Tags |
|---|---|---|---|
| `Tokyonight 11` | IntoneMonoNF 11 | 1.5 | `tokyonight`, `4k` |
| `Tokyonight 13` | IntoneMonoNF 13 | 1.5 | `tokyonight`, `retina`, `2k`, `studio-display` |
| `Tokyonight 16` | IntoneMonoNF 16 | 1.7 | `tokyonight`, `retina`, `4k`, `studio-display` |
| `Tokyonight 20` | IntoneMonoNF 20 | 1.7 | `tokyonight`, `2k` |

`Everforest 11…20` are the same with `MesloLGSDZNFM-Regular` (Everforest used 12 and 16 so far; moving to the shared scale keeps the menus the same for both themes). Merging changes two spacings: 2k small goes 1.33 → 1.5, retina big 1.5 → 1.7. Tune in the UI afterwards; the change lands in the repo (ADR 0004).

10 profiles instead of 17, and a colour change is made once per theme.

### One profile for light and dark

iTerm 3.5+ keeps two colour sets in one profile (`Use Separate Colors for Light and Dark Mode: true`, keys `Ansi 0 Color (Light)`, `Ansi 0 Color (Dark)`, …) and follows the macOS appearance live.

- **Everforest:** dark from `Everforest Dark` (the "soft" background, `#333C43`), light from `Everforest Light`. `Everforest Dark - 4k` used a different background (`#293136`) and is dropped.
- **Tokyonight:** dark from today's `Tokyonight (Night)`. There's no light set in the repo: take Tokyonight Day from tokyonight.nvim's `extras/iterm/` (same source as the Night colours).
- **`THEME` goes.** No `Initial Text` in any profile, and the `vim.opt.background = vim.env.THEME or "dark"` lines in both Neovim `options.lua` files are removed. Until the follow-up idea (task 36) lands, Neovim falls back to its own background detection at startup (it asks the terminal for its background colour, Neovim 0.10+).

### Default per machine

A `Default` dynamic profile with a fixed GUID, whose parent is chosen per machine. The shared plist always points at it, so its value never flips between machines.

1. **First-run answer** in `.chezmoi.toml.tmpl`:

   ```
   [data.iterm]
     {{- $sizes := list "Tokyonight 11" "Tokyonight 13" "Tokyonight 16" "Tokyonight 20" "Everforest 11" "Everforest 13" "Everforest 16" "Everforest 20" }}
     defaultProfile = {{ promptChoiceOnce . "iterm.defaultProfile" "iTerm default profile" $sizes (ternary "Tokyonight 16" "Tokyonight 11" $isWork) | quote }}
   ```

   A choice from the size profiles, so a typo can't reach the file. The list is written out in the template and has to follow the profile files; the host check below fails when they differ. Personal keeps today's 11pt; work gets 16pt. Changed later in `~/.config/chezmoi/chezmoi.toml` + `chezmoi apply`.

2. **`zz-default.json.tmpl`**, a rendered copy (not a symlink), loaded last:

   ```json
   {
     "Profiles": [
       {
         "Name": "Default",
         "Guid": "B45E0000-0000-4000-8000-000000000002",
         "Dynamic Profile Parent Name": {{ .iterm.defaultProfile | quote }},
         "Tags": [],
         "Rewritable": false
       }
     ]
   }
   ```

   It holds no settings of its own: font and colours are changed on the size or theme profile it points to, which stay rewritable and synced. `Tags: []` keeps it out of the monitor submenus it would otherwise inherit.

3. **Shared plist:** `Default Bookmark Guid` → `B45E0000-0000-4000-8000-000000000002`.

### Files

```
linked/iterm2/DynamicProfiles/
  00-base.json        Base (+ the moved keys)
  everforest.json     Everforest, then Everforest 11/13/16/20 (parent first in the file)
  tokyonight.json     Tokyonight, then Tokyonight 11/13/16/20
private_Library/Application Support/iTerm2/exact_DynamicProfiles/
  symlink_00-base.json.tmpl, symlink_everforest.json.tmpl, symlink_tokyonight.json.tmpl
  zz-default.json.tmpl
```

- `catppuccin`, `cyberdream`, `one-dark`, `rigel`, `solarized` and their symlink templates are deleted.
- The target folder becomes `exact_`, so chezmoi removes the five dropped symlinks on machines that have them (else they dangle). Nothing else lives there: profiles made in the UI go to the main plist (ADR 0004).
- Existing GUIDs are kept where a profile maps over (`Tokyonight 11` keeps `- 4k small`'s, `Tokyonight 13` keeps `(Night)`'s, …); the rest are new.
- Generated by a one-off script from today's files, like the ADR 0002 port, then a round-trip check: every size profile resolves to the same colours and font as the old profile it replaces (allowing the two spacing changes above).

### Tests

- Host, `test/host/45-iterm.sh` rewritten for the new shape:
  - theme profiles: parent `Base`, `Use Separate Colors for Light and Dark Mode` true, both `(Light)` and `(Dark)` colour sets;
  - size profiles: parent is a theme in the same file, `Normal Font` set, no colour keys (colours only come from the theme);
  - every monitor tag (`retina`, `2k`, `4k`, `studio-display`) has exactly two sizes per theme;
  - no profile sets `Initial Text`;
  - the plist's `Default Bookmark Guid` is the `Default` GUID;
  - the `defaultProfile` choice list in `.chezmoi.toml.tmpl` is exactly the size profiles in `linked/iterm2/DynamicProfiles/`, and `zz-default.json` rendered for both profiles names one of them (a rename would otherwise silently fall back to `Base`).
- `test/expected/{personal,work}/config.toml` and `managed.txt` snapshots updated.
- VM guided step: default profile has the expected size (11 personal, 16 work); switching macOS to light mode changes the colours of an open window.

## To verify (in a VM, not on this Mac's live iTerm)

- A dynamic profile whose parent is itself a dynamic child resolves through both levels (`Default` → `Tokyonight 16` → `Tokyonight` → `Base`: three levels for `Default`).
- Load order: files by name, profiles in file order (the `00-`/`zz-` prefixes and "parent first in the file" rely on it).
- `"Tags": []` on a child overrides the parent's tags instead of inheriting them.
- A rewrite from the UI on a size profile still writes only its overrides (ADR 0004), now that its parent is not `Base`. Also watch for the stripped-profile bug from task 32.
- `(Light)`/`(Dark)` colour keys are inherited from a parent like the plain ones.

## Options considered

### Profile layout

| | Two levels, one profile per monitor × size (today) | **Base → theme → size, monitors as tags** | One profile per theme, size only per machine |
|---|---|---|---|
| Profiles (2 themes) | 2 × 8 = 16 | 2 + 2 × 4 = 10 | 2 |
| Colours stored | Once per profile | Once per theme | Once per theme |
| Browse by monitor in the Profiles menu | Yes | Yes | No; Cmd+/- per session |

### Default per machine

| | **Per-machine `Default` child** | `Default Bookmark Guid` per machine (`defaults write`) | Template the plist | Switch font by display (iTerm Python API) |
|---|---|---|---|---|
| Survives iTerm save-on-quit | Yes, plist value is the same everywhere | No, flips in git | No: a rendered copy breaks UI sync of global settings | n/a |
| Custom code | One small template + one answer | Script + guard against drift | Changes ADR 0003's plist setup | A script running all the time, API server on (off by design) |
| Follows the monitor on the fly | No | No | No | Yes |

iTerm's Automatic Profile Switching matches host, user, path and job, not displays. Not worth a script while the work laptop is almost always docked; on an undocked day, pick `Profiles > retina > …`.

## Resolved questions (2026-10-16)

- Studio Display small: 13pt.
- Studio Display tag: `studio-display` (was `5k`).
- `defaultProfile`: `promptChoiceOnce` from a fixed list of the size profiles, kept in step with the files by a host check.
