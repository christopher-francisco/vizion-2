# ADR 0007 — tmux and Neovim take their colour scheme and light/dark from the iTerm window in use

- **Status:** Accepted (2026-10-16)
- **Date:** 2026-10-16

## Context

ADR 0006 gave iTerm one profile per colour scheme with light and dark colours, picked by the macOS appearance, and dropped `THEME`, the variable that told Neovim which profile it was in. tmux stayed hard-coded to Tokyonight Night and LazyVim to Tokyonight.

Schemes are switched per window, not inside one: open a new iTerm window with another profile or appearance and `tmux attach`, and older windows often stay attached; going back to one should bring its scheme back. Whatever decides tmux's and Neovim's colours has to see the window in use. Findings and measurements: `docs/requirements/0.3.0_COLOUR_SCHEME_SYNC.md`.

- iTerm 3.7 reports light/dark (mode 2031) when a session's background changes darkness, not a scheme change.
- tmux 3.8 runs hooks on attach, focus and light/dark changes, naming the client (`#{hook_client}`); it doesn't expose a window's colours, but `update-environment` copies `ITERM_PROFILE` from the attaching window.
- Neovim 0.12 follows light/dark by itself and gets FocusGained on attach. Through tmux, its OSC 11 question and light/dark notifications reflect the **first** attached window, not the one in use.
- Outside tmux, Neovim talks to iTerm directly: OSC 11 gives the window's exact background.

## Options considered

| | Scheme source | Follows the attaching window | Cost |
|---|---|---|---|
| Per-machine answer only | `theme` in chezmoi data | No | Smallest |
| Read the window on attach, each on its own | tmux: `ITERM_PROFILE` → scheme; Neovim: OSC 11 background → nearest scheme | Only with one window attached: Neovim gets the first window's colours (built first, failed on this Mac) | Small |
| **tmux follows the window in use, Neovim follows tmux** | tmux: the window's `ITERM_PROFILE` (kept per client from its attach) and light/dark, on attach, focus and appearance changes; tells the Neovims inside it. Outside tmux, Neovim: OSC 11 → nearest scheme. Tables rendered from the iTerm profiles | Yes, including back to an older window | A hook script and a Neovim module |
| iTerm Python API | A script watching profile changes, pushing into tmux and Neovim | Yes, also inside a window | API server on, a script always running, a channel to build; rejected in ADR 0006 for fonts too |
| Per-profile `Initial Text` / environment variable | The first shell of a window | Only that shell; stale in tmux | What `THEME` was |

Light/dark: the macOS appearance, through iTerm, is the single source; tmux's hooks and Neovim's own handling of mode 2031 follow it. No per-machine light/dark setting.

## Decision

- **The window in use decides; inside tmux, tmux is the one place that decides.** tmux keeps each window's `ITERM_PROFILE` from its attach, and on attach, focus and light/dark changes of the window in use sources `<scheme>-<dark|light>.tmux.conf` and tells every Neovim inside it (`nvim --server`; each Neovim registers its address on its pane). Neovim inside tmux reads tmux's choice at startup and drops its own light/dark following, which would track the first attached window.
- **Outside tmux, Neovim asks iTerm**: OSC 11 at startup and on focus, the scheme whose iTerm background is nearest; light/dark its own.
- Both tables are rendered by chezmoi from `linked/iterm2/DynamicProfiles`, so a new theme profile needs no change in tmux or Neovim.
- **The first-run answer is a top-level `theme`** (was `iterm.theme`): the scheme of iTerm's `This Mac`, tmux's startup theme, Neovim's default and the fallback for other terminals.
- **nvim-legacy** takes the answer but doesn't follow the window.

## Consequences

- A new window + `tmux attach` switches; clicking back to an older window switches back. Flipping the appearance recolours the window in use.
- tmux options are global: two windows on screen at once both show the active one's colours.
- A profile switched inside an attached window isn't seen until the next attach (`ITERM_PROFILE` is read then).
- Neovim inside tmux depends on tmux's hook reaching it; a Neovim busy at that moment catches up on the next change.
- tmux shows the previous window's colours for under a second on attach.
- Each scheme needs a tmux `-dark`/`-light` pair setting the same options, and a Neovim colour scheme of the same name (host checks).
- Machines set up before run `chezmoi update --init` once to answer `theme` (default: their `iterm.theme`).
- Revisit if iTerm sends mode 2031 reports on any colour change (Ghostty does), or tmux exposes the client's colours.
