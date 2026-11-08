# Setup reference

The parts of this machine that a bootstrap does not need to read: the repository
map, how a component gates its scripts, the `etc/` convention, and the hardware
notes. Back to the [main README](../README.md).

## Where the source lives

`chezmoi` reads its source directory from `~/.local/share/chezmoi`. On the
development machine that path is a **symlink to this repository**, so editing a
file here and running `chezmoi apply` are the same operation, there is no second
copy that can silently drift. A fresh machine gets a real clone at the same path
from `install.sh`; the commands are identical either way.

```bash
# one-time, on a machine where the repo already lives elsewhere
mv ~/.local/share/chezmoi ~/.local/share/chezmoi.bak
ln -s ~/DATA/05_Code/Projects/dotfiles-machine ~/.local/share/chezmoi
```

`~/dotfiles` (the path the README's bootstrap block clones to) is a symlink to
the same repository on the development machine, for the same reason: a real
second clone would only lag behind and run a stale `install.sh`.

```bash
ln -s ~/DATA/05_Code/Projects/dotfiles-machine ~/dotfiles
```

The userspace checkout sits next to it at `~/DATA/05_Code/Projects/dotfiles`:
the repository named `dotfiles` is the userspace layer, this one is
`dotfiles-machine`. Set `DOTFILES_PORTABLE_SRC` to that path to make
`install.sh` use the checkout instead of cloning the pinned tag.

A fresh machine keeps real clones at both paths: `bootstrap-machine.sh` needs
`~/dotfiles` to run `install.sh`, and `install.sh` then lets chezmoi clone its
source at `~/.local/share/chezmoi`.

The userspace layer is a **separate repository** (`dotfiles`). `/d`
clones it at `~/.local/share/dotfiles-portable` and applies it with
`chezmoi --source`, which is why a userspace-only machine never creates
`~/.local/share/chezmoi`. `install.sh` applies the same repository from a pinned
tag (`DOTFILES_PORTABLE_REF`, `v1.0.2`) into the same directory, and
`DOTFILES_PORTABLE_SRC=/path/to/checkout` short-circuits the fetch.

## Repository map

```
dotfiles/
├── bootstrap-machine.sh              # machine entry point (Arch/CachyOS) → install.sh
├── install.sh                        # machine bootstrap (paru + chezmoi + apply, + portable layer)
├── validate.sh                       # post-install verification script
├── test.sh                           # pre-push lint of the repo (bash -n, JSON, untracked)
├── smoke.sh                          # offline test of install.sh and bootstrap-machine.sh
├── .chezmoiscripts/                   # scripts run by chezmoi, never deployed
│   ├── run_once_01-packages.sh.tmpl      # base + enabled components (packages.d/)
│   ├── run_once_02-wine-staging.sh.tmpl  # wine-staging runner (optional: "wine" component)
│   ├── run_onchange_03-omenctl.sh        # omenctl (fans + power profiles), pinned ref
│   ├── run_once_04-omenctl.sh.tmpl       # omenctl units + udev rules
│   ├── run_once_05-vfio-setup.sh.tmpl    # GPU passthrough (VFIO), virtualization
│   ├── run_once_06-libvirt-setup.sh.tmpl # libvirt services + groups, virtualization
│   ├── run_onchange_07-looking-glass.sh.tmpl # Looking Glass shared memory, looking_glass
│   ├── run_once_08-kde-settings.sh       # KDE settings enforced via kwriteconfig6
│   ├── run_once_09-material-you.sh       # Material You “follows-the-wallpaper” (kitty/btop/zed hook)
│   ├── run_once_10-fstab-shared.sh       # shared NTFS partition in fstab
│   ├── run_once_11-boot-tuning.sh.tmpl   # initramfs slimming + Limine snapshot cap
│   ├── run_onchange_12-peripherals.sh.tmpl # logid config (MX Master 3S), peripherals
│   └── run_onchange_13-plasmoids.sh      # KDE widgets, fetched at a pinned commit
├── lib/                               # shell libraries, sourced by the scripts above
│   ├── logging.sh                     # log_* helpers (+ summary counters)
│   └── system.sh                      # install_system_file: etc/… → /etc/…
├── .chezmoitemplates/
│   └── component-guard                # no-op a script when its component is off
├── packages.d/                       # package registry: one file per component
│   ├── base.pacman                   # always installed
│   ├── audio_pro.pacman              # e.g. audio stack (also audio_pro.aur)
│   └── <component>.{pacman,aur}      # installed when listed in `components`
├── bricks/                           # opt-in application bundles (never installed by chezmoi)
│   ├── install                       # ./bricks/install audio-apps
│   ├── audio-apps.{pacman,aur}       # REAPER, plugins
│   ├── creative.{pacman,aur}         # Blender, OBS, upscayl, shutter-encoder
│   └── misc-apps.{pacman,aur}        # obsidian, localsend, vesktop…
├── dot_p10k.zsh                      # p10k prompt config (regenerate: `p10k configure` + `chezmoi add`)
├── etc/                              # system files (units, udev, initcpio, tmpfiles, sysctl, logid)
│   ├── initcpio/install/no-nouveau    # mkinitcpio hook: drop nouveau + GSP fw
│   └── mkinitcpio.conf.d/20-no-nouveau.conf
├── docs/                              # why the config here is the way it is
│   ├── README.md                             # index
│   ├── setup.md                              # this file: map, gating, hardware
│   ├── boot-tuning.md                        # initramfs slimming + UEFI boot entries
│   ├── material-you.md                       # wallpaper-driven theming + KWin rules
│   └── notes.md                              # versioned-vs-not, audio, SSH keys
├── dot_config/create_*                # created only if absent (Plasma/Kate own them afterwards)
│   └── plasma-*.appletsrc             # panel/widgets layout (volatile → apply once)
├── dot_config/
│   ├── zsh/machine.zsh               # machine fragment sourced by the portable .zshrc
│   ├── kitty/local.conf              # globincluded by the portable kitty.conf (theme)
│   ├── btop/btop.conf                 # no include mechanism → machine-owned outright
│   ├── pipewire/pipewire.conf.d/      # PipeWire: global quantum + proprietary RME mode (TuxMix)
│   ├── wireplumber/wireplumber.conf.d/# WirePlumber: per-interface RME (CC) rules + Ryzen onboard
│   └── *.rc                           # KDE config STABLE only (kwin rules, kate/dolphin/konsole)
├── dot_local/
│   ├── bin/                          # commands on PATH
│   │   ├── limine-boot-win           # one-time boot to Windows
│   │   ├── limine-boot-vfio          # one-time boot to VFIO kernel
│   │   ├── limine-boot-linux         # restore boot to Linux
│   │   ├── backup-data               # backup DATA to external drive
│   │   ├── omenctl-tui               # desktop launcher wrapper (sudo + terminal)
│   │   ├── mount-shared              # mount Windows SHARED (NTFS) in rw
│   │   ├── umount-shared             # unmount SHARED before rebooting to Windows
│   │   ├── .add-vfio-entry           # (internal) adds the VFIO entry to limine.conf
│   │   ├── kitty-material-you-hook.sh# run by kde-material-you-colors → delegates to material-you-refresh
│   │   └── material-you-refresh      # manual re-sync (safety net)
│   ├── lib/material-you/             # generators (internal, NOT on PATH)
│   │   ├── material_you_lib.py       # shared palette parser (single source of truth)
│   │   ├── kitty.py                  # kitty colors ← wallpaper
│   │   ├── btop.py                   # btop theme ← wallpaper
│   │   ├── zed.py                    # Zed theme ← wallpaper (hot-reloads)
│   │   ├── zen.py                    # Zen accent + userChrome (restart Zen)
│   │   └── prompt.py                 # p10k prompt + LS_COLORS (1x, not per prompt)
│   ├── share/applications/omenctl.desktop  # application-menu entry for the TUI
│   └── share/icons/hicolor/scalable/apps/omenctl.svg  # launcher icon
```

Scripts live in `.chezmoiscripts/` (a chezmoi special directory: run, never
deployed). chezmoi applies entries in target-path order, so `.chezmoiscripts/`
sorts **before** `~/.config` and `~/.local`: a run script must read the repo
assets it needs from `$CHEZMOI_SOURCE_DIR`, not from `~`, or it will not find
them on a fresh machine.

## How components gate scripts

What a machine installs is driven by the `components` list in
`~/.config/chezmoi/chezmoi.toml`. `chezmoi init` seeds the file at its defaults
(everything enabled except `wine`); change the list there and re-apply. (No
prompt: `chezmoi init --apply` runs from `install.sh` and must not block.) A
config that has **no** `components` key at all (written before the registry
existed) keeps the previous behaviour: every component except `wine`. `wine =
true` is still honoured as a legacy switch, equivalent to adding `wine` to the
list.

A component switch does not only gate packages: the scripts that belong to it
call `component-guard` (`.chezmoitemplates/component-guard`) right after sourcing
the logging library, which renders a `log_skip` + `exit 0` when the component is
absent. Dropping `virtualization` therefore skips `run_once_05` (VFIO) and
`run_once_06` (libvirt).

| Gated script | Component |
|---|---|
| `run_once_02-wine-staging.sh.tmpl` | `wine` |
| `run_once_05-vfio-setup.sh.tmpl` | `virtualization` |
| `run_once_06-libvirt-setup.sh.tmpl` | `virtualization` |
| `run_onchange_07-looking-glass.sh.tmpl` | `looking_glass` (with teardown) |
| `run_onchange_12-peripherals.sh.tmpl` | `peripherals` |

The rest of the `run_once_*` scripts are machine-wide (packages, omenctl, KDE
settings, boot tuning, fstab) and have no component to belong to.

`looking_glass` goes one step further and **tears its own configuration down**:
its script is `run_onchange_` (not `run_once_`, which keys its state on every
content hash ever seen and would skip a second disable after a re-enable), and
the guard also calls `looking-glass-teardown`, which removes the tmpfiles/sysctl
drop-ins and `/dev/shm/looking-glass`. Packages are still never removed. Others
only gate; adding a teardown is a per-component decision (pass its template name
to the guard).

## System files (`etc/`)

Files that live outside `~` (mkinitcpio hooks, systemd units, udev rules,
tmpfiles/sysctl drop-ins, the logid config) are versioned under `etc/` with the
**same path they have on the machine**, so the repo tree mirrors `/etc`. They are
not deployed by chezmoi itself (`etc` is in `.chezmoiignore`); a script in
`.chezmoiscripts/` installs them:

- `run_onchange_12-peripherals.sh.tmpl`, `/etc/logid.cfg`
- `run_once_04-omenctl.sh.tmpl`, the omenctl profile/watch units and udev rules
- `run_onchange_07-looking-glass.sh.tmpl`, the IVSHMEM tmpfiles entry and the hugepages sysctl
- `run_once_11-boot-tuning.sh.tmpl`, the initramfs hooks and the VFIO drop-in

They all use `install_system_file` (`lib/system.sh`), which copies a file only if
it differs from the installed one. They are **templates** whose header carries an
`etc-hash:` line: a hash of the `etc/` files the script installs. chezmoi re-runs
a `run_once_` script only when its own content changes, so without that line
editing a unit would never be redeployed. **When you add a file under `etc/`, add
its path to the `etc-hash` list of the script that installs it.**

`packages.d/` uses the same trick: `run_once_01` carries a `pkg-hash:` line over
`packages.d/*`, so editing a package list re-runs the install (and is
idempotent: `pacman -S --needed`, so a re-run installs nothing when the machine
is up to date). `test.sh` enforces both: one hash per `etc/` file (coverage
check) and one hash per `packages.d/` list (count check).

`validate.sh` compares every file under `etc/` with its installed copy, so a
missing hash entry or a hand-edited `/etc` file shows up as a failure.

## Hardware

| Component | Model |
|---|---|
| **Laptop** | HP OMEN 15-en1037nf (4J8B4EA) |
| **CPU** | AMD Ryzen 7 5800H (8C/16T, Zen 3) |
| **iGPU** | AMD Radeon Graphics (Vega) |
| **dGPU** | NVIDIA GeForce RTX 3070 Mobile (GA104, 8 GB GDDR6) |
| **RAM** | 2× 16 GB DDR4-3200 |
| **Storage** | SK Hynix 512 GB (NVMe) + Crucial 1 TB (NVMe) |
| **Network** | Realtek RTL8111/8168 (Ethernet) + Intel Wi-Fi 6 AX200 |
| **Display** | LG UltraGear 27GP850 (2560x1440 @ 144 Hz, DP, wired to the dGPU: no external output on the iGPU) |

## Stack

- **OS**: Dualboot (Linux CachyOS + Windows 11)
- **Shell**: zsh + Powerlevel10k
- **DE**: KDE Plasma 6 (Wayland)
- **GPU**: NVIDIA RTX 3070 + AMD Vega (VFIO passthrough for VM)
- **Audio**: Pipewire (JACK) + realtime privileges, yabridge (Windows VST bridge); REAPER and plugins are an opt-in brick
- **Virtualization**: QEMU + virt-manager + distrobox
- **Fan control**: omenctl (EC setpoints, tuned curve, safety contract)
- **Power mgmt**: omenctl profile (auto/quiet/eco/perf, AC/battery) + RyzenAdj + NVIDIA
- **Wine**: wine-staging 9.21 standalone runner (~/.local/share/wine-runners/)
- **Peripherals**: Logitech MX Master 3S (logiops)

## Omenctl

`omenctl` is the single tool for the fans and the power profiles on this machine:
it owns the two EC fan setpoints, runs the tuned curve at 1 Hz, and applies
`auto` / `quiet` / `eco` / `perf` across the CPU limits, the platform profile and
the dGPU lock. It replaces both `nbfc` and the old `power-profile` bash script
(kept in `myomen15/omenctl/legacy/power-profile/` for reference).

- Upstream: <https://github.com/ismail-bahloul/omenctl> (**private**, on purpose)
  (it drives this laptop's EC fans; the public dotfiles must work without it).
  The installer picks, in order: a local checkout
  (`OMENCTL_SRC`, default `~/DATA/05_Code/Projects/myomen15/omenctl`), `gh repo
  clone` when `gh auth status` is ok (`gh auth login` once per machine), then a
  non-interactive `git clone` (SSH works via `OMENCTL_REPO`). Without any of
  those it warns and skips, and `run_once_04` then skips the units too, so a
  machine without omenctl does not end up with services pointing at nothing.
- Installed by `run_onchange_03-omenctl.sh`: a local checkout is used when
  `OMENCTL_SRC` points at one (default: `myomen15/omenctl`), otherwise the pinned
  tag (`OMENCTL_REF`, default `v0.4.0`) is cloned. Bump the ref in the script to
  publish an update; `run_onchange_` re-runs on the changed content.
- Units: `omenctl.service` (fan governor), `omenctl-profile.service` +
  `omenctl-profile.timer` (periodic re-apply), `omenctl-watch.service`
  (inotify/drift watcher), and the AC udev rule `99-omenctl.rules`.
- Commands: `omenctl status`, `omenctl profile auto|quiet|eco|perf`,
  `omenctl fan cpu|gpu|all 0-100|auto`, `omenctl tui`, `omenctl curve cpu|gpu`,
  `omenctl start|stop`.
- Rollback: `sudo systemctl stop omenctl` writes `255` to both setpoints and
  hands the fans back to the EC's own (louder) curve. The dotfiles never install
  or start `nbfc`; omenctl is the only fan/power stack they set up.
- Desktop: the application-menu entry
  (`dot_local/share/applications/omenctl.desktop`) calls
  `/usr/local/bin/omenctl-tui`, a symlink created by `run_onchange_03` to the
  chezmoi-deployed `~/.local/bin/omenctl-tui`. The icon is
  `dot_local/share/icons/hicolor/scalable/apps/omenctl.svg` (installed as
  `~/.local/share/icons/hicolor/scalable/apps/omenctl.svg`). The wrapper runs
  `sudo -n omenctl tui` (falling back to an interactive prompt) and
  `Terminal=true` opens it in the default terminal. If KDE asks to trust the
  desktop file, right-click it and choose “Allow launching”. Pin it to the
  desktop from the application menu if you want a shortcut there.

## Aliases

| Alias | Action |
|---|---|
| `ff` | fastfetch |
| `ww` | One-time boot to Windows |
| `vv` | One-time boot to VFIO GPU passthrough kernel |
| `ll` | One-time boot to default Linux kernel |
| `backup` | Backup DATA to external drive |
| `power` | Show power status (CPU/GPU temps, limits, fans) |
| `auto` | Follow AC/battery (default profile) |
| `quiet` | AC/battery with CPU boost off (cooler/silent) |
| `eco` | Battery envelope even on AC (15 W / 2.4 GHz) |
| `perf` | Switch to performance mode (4.47 GHz / GPU unlocked) |
| `material-refresh` | Re-sync kitty/btop/zed/prompt to current wallpaper colors |
| `uu` | Full update: repos + AUR + Flatpak + orphan/cache cleanup |

`uu` runs `arch-auto-update`, versioned in its own private repo
(<https://github.com/ismail-bahloul/arch-auto-update>) and checked out at
`~/DATA/05_Code/Projects/arch-auto-update`. Useful flags: `-c` preview the
available updates, `-n` dry run, `--force` bypass the news guard once a
manual-intervention announcement has been read.

## Third-party widgets

Neither KDE plasmoid is vendored here. `run_onchange_13-plasmoids.sh` fetches
them from upstream at a **pinned commit** (a tag can be moved, a commit cannot)
and installs them into `~/.local/share/plasma/plasmoids/`. Bumping the ref in
that script changes its content, which is what makes chezmoi re-run it.

Their licenses apply to their own code, independently of this repo's MIT
license:

| Plasmoid | License | Upstream | Pinned |
|---|---|---|---|
| `org.kde.olib.thermalmonitor` | MIT | https://invent.kde.org/olib/thermalmonitor | `v0.2.7` |
| `com.github.mazen.salatprayertime` | GPL-3.0+ | https://github.com/mazenmohamed203/salaatprayertime | `v2.5.6` |

They are fetched because neither is reliably packaged, and because the prayer
time widget ships a 2.7 MB adhan recording: a vendored copy was 76 % of this
repository's size and drifted from upstream. A download failure is a warning,
not a failed apply: the installed copy stays.

Replacing the directory means local edits to a plasmoid are lost; that is the
price of not vendoring it.

---

Back to the [main README](../README.md).
