# Material You: “follows-the-wallpaper”

The desktop (terminal + system monitor + editor + prompt) takes the colors of the
wallpaper, recolored by **`kde-material-you-colors`** (AUR) on every wallpaper
change.

**Color source**: the Konsole colorscheme `MaterialYou.colorscheme` that
`kde-material-you-colors` regenerates (`~/.local/share/konsole/`). kitty, btop,
Zed and the p10k prompt all read that same file → total consistency. The parsing
is centralized in `material_you_lib.py` (a single source of truth).

**Chain**: wallpaper changed → `kde-material-you-colors` daemon regenerates the
Material You → `on_change_hook` (`kitty-material-you-hook.sh`) **delegates to
`material-you-refresh`** (kitty + btop + Zed + Zen + prompt cache) → kitty reloads
(`pkill -USR1`).

**kitty tab bar**: `powerline` style (set in the portable `kitty.conf`); the generator
emits `active_tab_background` = accent and `inactive_tab_background` = an
accent-tinted surface, so the bottom tabs follow the wallpaper as well.

**p10k prompt + `ls`**: `prompt.py` writes `~/.cache/material-you/prompt.zsh`
(accent `~`/`❯` **and** `LS_COLORS` with truecolor values from the same palette),
which `~/.config/zsh/machine.zsh` sources at startup and in `precmd` → the prompt, `ls` (via the
`ls/la/l` aliases) and the zsh completion list all follow the wallpaper, and are
refreshed on every change. **No process launched on every prompt** (previously:
2 `awk` per prompt).

**Zed**: `zed.py` writes `~/.config/zed/themes/materialyou.json`
(custom "Material You" theme, Ayu Dark structure + wallpaper colors). Zed watches
this folder and **hot-reloads**; no need to restart the editor. The theme is
selected via the `theme` key of `~/.config/zed/settings.json`.

**Zen Browser**: `zen.py` writes, into the active profile:

- `user.js`: `zen.theme.accent-color` (hex), `zen.theme.use-system-colors`, and
  `toolkit.legacyUserProfileCustomizations.stylesheets` (off by default, even in
  Zen, so `userChrome.css` would otherwise be ignored);
- `chrome/zen-material-you.css` (`userChrome`): forces the surfaces (background,
  toolbar, sidebar, URL bar, popups, selected tab) because Zen only mixes 20-30 %
  of the accent over near-black and keeps fixed greys for the big areas;
- `chrome/zen-material-you-content.css` (`userContent`): `about:newtab`,
  `about:home`, `about:blank`;
- `chrome/userChrome.css` / `userContent.css`: an `@import` of the two files above.

> ⚠️ The chrome rules use `*`, not `:root`: when a workspace has a theme (Zen
> stores `{type: gradient, opacity: 0.5}` per space), Zen sets
> `--zen-primary-color` / `--zen-background-opacity` **inline on descendant
> elements** (`#zen-browser-background`, the space element). An inline value on
> an element wins over the inherited `:root` value, so `:root` was silently
> ignored. The rules also force `--zen-background-opacity: 1`, which cancels the
> workspace theme's 50 % wash.

`user.js` and those stylesheets are read at startup → **restart Zen after a
wallpaper change** (unlike Zed, which hot-reloads). The profile is found through
`~/.config/zen/profiles.ini`, so nothing profile-specific is versioned.

**Removing it** (back to stock Zen): `zen.py --remove`. It drops the
`user.js` block, deletes the two generated stylesheets and removes their
`@import`s (a `userChrome.css` / `userContent.css` with other rules is kept). The
legacy pref stays `true` in `prefs.js`, which is harmless without the files.

> ℹ️ Plain Firefox has no equivalent pref: theming it would require a
> `userChrome.css` plus `toolkit.legacyUserProfileCustomizations.stylesheets=true`
> (defaults to `false`, including in Zen). That is why Zen is the supported route.

> ℹ️ `settings.json` **is not versioned**: Zed writes the agent's permissions
> there dynamically (absolute paths, network hosts) → it would create noise and a
> `chezmoi apply` would overwrite recent authorizations. Instead, `run_once_09`
> sets only the `theme` key (idempotent), and creates a minimal `settings.json` if
> absent (fresh machine).

## Transparency

**A single KWin rule, "everything at 90 %".**

- **kitty**: `background_opacity 0.85` (native kitty) → transparent background,
  **opaque text**.
- **All other windows**: a single KWin rule (group `Transparent_windows` in
  `kwinrulesrc`, **without `wmclass`** so it matches *all* windows) applies
  `opacity 90/90`. Konsole, Zed, Dolphin, System Settings are therefore glassy
  like the rest, by the same mechanism.
- **Currently disabled**: both rules are versioned with `Enabled=false`, so
  windows are opaque. Toggle them back in Window Rules (or drop the `Enabled`
  key and `chezmoi add`) to restore the glass.
- Adjust the level: Window Rules in Settings, or
  `kwriteconfig6 --file kwinrulesrc --group 1503ce0e-1799-40f2-9ec4-efa44a851115
  --key opacityactive 92` then `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`.
- `kwinrulesrc` **is versioned**: after a change via the UI, do another
  `chezmoi add` (otherwise an apply reverts it).

> Why: KWin does not render a transparent background, it **blurs what is behind**.
> Transparency must come from the app (background only) to keep the text sharp;
> possible only if the app exposes it (kitty yes; Konsole only for the terminal
> area). Otherwise the KWin rule multiplies the whole window (text dimmed 10 %).

## Blur: "everything" mode, no whitelist

`run_once_08` imposes `BlurMatching=false` + `BlurNonMatching=true` with
`WindowClasses` **empty** → every **translucent** window is blurred
automatically. It is simpler and it removes the class of bugs "translucent but not
blurred" (a forgotten class = glassy window but sharp) that we ran into several
times. `WindowClasses` now only serves as an **exceptions list** (a class will
appear there if one day something blurs badly). The blur is only visible under a
translucent window; the opaque ones do not change. (The "lag" we had attributed to
the global blur came in fact from `colorPowerTradeoff=PreferAccuracy` on DP-2, a
per-screen KWin setting.)

The **engine** itself is not pinned by the dotfiles: which blur runs is a
one-click choice in *System Settings → Desktop Effects*. What matters is that
`better-blur-dx` and the stock blur are **never enabled together** (two blurs =
double blur), so on a fresh install: enable `better-blur-dx`, disable the stock
one. The DX parameters themselves are imposed by `run_once_08` (they are what the
theming depends on, and they are not reachable by hand).

## Two fragile points (worth knowing)

1. **The `kde-material-you-colors` daemon** autostarts at login (reads
   `config.conf` where `on_change_hook` is set). If it dies mid-session, it does
   not restart on its own → use `material-refresh` to re-sync by hand. On reboot,
   the autostart restarts it.
2. **`kwin-effects-better-blur-dx`** (AUR, KWin blur effect) is **compiled against
   KWin**. After a Plasma/KWin update, it can break (the blur disappears) →
   **rebuild** it: `paru -S kwin-effects-better-blur-dx` (or a full `paru -Su`).
   This is the first thing to check if the blur disappears after an update.

---

This module is entirely separate in the repo: generators in
`dot_local/lib/material-you/` (internal, not on PATH), the two commands
(`material-you-refresh`, `kitty-material-you-hook.sh`) in `dot_local/bin/`,
configs in `dot_config/{kitty,btop}/`, and `run_once_09` which sets the
`on_change_hook` key + Zed's `theme` key (both idempotent).
