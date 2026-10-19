# ADR 0009 — Use macOS's own terminfo entries

- **Status:** Accepted (2026-10-19)
- **Date:** 2026-10-19

## Context

Vizion compiled two terminfo entries into `~/.terminfo`, and vizion 2 kept them (R6.2): `xterm-256color-italic` (`xterm-256color` plus `sitm`/`ritm`) and `tmux-256color` (italics, standout, Home/End, `Ms@`). Programs only use italics when `$TERM`'s entry lists `sitm`, and macOS used to ship ncurses 5.7 (2008), whose `xterm-256color` had no italics and which had no `tmux-256color` at all. So iTerm's Base profile reported `xterm-256color-italic`, and `~/.zshrc.aliases` exported `TERM=xterm-256color-italic` (and `~/.zshenv` `TERM=xterm-256color`). Both exports also ran inside tmux panes, overriding tmux's `tmux-256color`.

On macOS 15.7 (ncurses 6.0, checked 2026-10-19 with `infocmp -A /usr/share/terminfo`) the system `xterm-256color` has `sitm=\E[3m` and `ritm=\E[23m`, and the system `tmux-256color` has every capability the custom file set (`sitm`, `ritm`, `smso`, `rmso`, `khome`, `kend`; it has no `Ms` either, so `Ms@` changed nothing). True colour never depended on terminfo here: iTerm sets `COLORTERM=truecolor`, and tmux learns it from its `Tc` override.

## Options considered

| | Keep the custom entries | Use the system entries |
|---|---|---|
| Italics in iTerm, tmux, Neovim | Yes | Yes (macOS 15.7) |
| Setup code | `tic` step, hashes in the macOS script, README troubleshooting | None |
| `TERM` inside tmux | Overridden by the shell export | `tmux-256color`, as tmux sets it |
| Remote hosts (ssh) | Need the `ssh` alias that resets `TERM` | Standard name; the alias still helps from inside tmux |

## Decision

Use the system entries. Delete `linked/iterm2/terminfo/`, the `tic` step and both `TERM` exports (`~/.zshenv` stays managed, with only a comment, so an apply also clears the old line on existing machines). iTerm's Base profile reports `xterm-256color`, and tmux keeps `default-terminal tmux-256color` with only `Tc` in its overrides.

## Consequences

- The VM assertions check that macOS's `xterm-256color` and `tmux-256color` have `sitm`. If a macOS release loses them, that check fails, and this ADR gets superseded.
- Existing machines keep the old compiled files in `~/.terminfo` until they're deleted by hand (README troubleshooting). They're harmless: nothing references `xterm-256color-italic` any more, and the leftover `tmux-256color` matches the system one.
- Shells opened before the change keep the old `TERM` until a new tab or an iTerm restart.
