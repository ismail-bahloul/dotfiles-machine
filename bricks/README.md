# bricks: opt-in application bundles

The core machine (drivers, shell, KDE, VM, audio stack, theming) is installed by
chezmoi from `packages.d/`. A **brick** is everything that is an *application*
rather than a dependency of a versioned config: you install it by hand, when you
want it.

```bash
./bricks/install --list
./bricks/install audio-apps
./bricks/install creative misc-apps
```

| Brick | What it brings |
|---|---|
| `audio-apps` | REAPER + extensions (reapack, sws), qpwgraph, easyeffects, lsp-plugins, AUR plugin bundles |
| `creative` | Blender, OBS Studio, upscayl, shutter-encoder |
| `misc-apps` | obsidian, localsend, vesktop, zapzap, pcloud-drive |

Each brick is a pair of `<name>.pacman` / `<name>.aur` lists, installed with
`pacman -S --needed` then `paru -S --needed`. Adding a brick is just adding two
files; `test.sh` checks that it has no duplicate entry and is listed above.

**Nothing is uninstalled automatically.** Remove a brick with
`sudo pacman -Rns <packages>`; check the brick's files for the list.

## Why not in `packages.d/`?

Because these change with taste and time, and the core should not. `packages.d/`
is the answer to "what does this machine need to be this machine"; a brick is
the answer to "what do I feel like installing this month". Keeping them apart
means `chezmoi apply` stays fast, deterministic, and independent of your app
choices, and a brick can never block a bootstrap.
