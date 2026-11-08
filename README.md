# My Dotfiles

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Platform: Arch Linux](https://img.shields.io/badge/Platform-Arch_Linux-1793D1.svg)
![Managed with chezmoi](https://img.shields.io/badge/Managed_with-chezmoi-00A0B0.svg)

A reproducible **CachyOS** (Arch) laptop setup managed with
[chezmoi](https://chezmoi.io): KDE Plasma 6 on Wayland, dual-boot with Windows 11,
GPU passthrough (VFIO) for a Windows VM, a PipeWire pro-audio chain, fan/power
management and a slimmed initramfs.

Repository map: [`docs/setup.md`](docs/setup.md). The measurements behind the
non-obvious choices: [`docs/`](docs/).

## Install

One line, always the latest `main`:

```bash
curl -fsSL https://ismailbahloul.com/d | bash
```

`ismailbahloul.com/d` redirects to [`bootstrap.sh`](bootstrap.sh) in this repo.
Drop the pipe (`curl -fsSL https://ismailbahloul.com/d`) to read it first.
`--dry-run` and `--validate` are forwarded:

```bash
curl -fsSL https://ismailbahloul.com/d | bash -s -- --dry-run
```

Or clone and run it locally:

```bash
[ -d ~/dotfiles/.git ] || git clone https://github.com/ismail-bahloul/dotfiles.git ~/dotfiles
git -C ~/dotfiles pull --ff-only
~/dotfiles/install.sh
```

To update a machine that is already set up:

```bash
chezmoi update --apply
```

SSH works too: `git@github.com:ismail-bahloul/dotfiles.git`.

A stock **Arch** needs `[multilib]` enabled in `/etc/pacman.conf` (`pacman -Sy`
afterwards): the 32-bit Wine/Steam/NVIDIA/Mesa packages live there. CachyOS
enables it by default, a fresh Arch does not — the CachyOS repos ship a few
`lib32-*` builds but not their dependencies, so without it the package step fails.

The blocks above carry no `#` comments on purpose: a stock zsh has
`interactive_comments` off, so pasting a commented block executes `#` as a
command (and the parentheses in the text break the parse).

| Command | What it does |
|---|---|
| `~/dotfiles/install.sh --dry-run` | prerequisites only, nothing is changed |
| `~/dotfiles/install.sh --validate` | + full machine audit (`validate.sh`) |
| `~/dotfiles/smoke.sh` | `install.sh`'s branches, offline (fake chezmoi, no sudo) |
| `~/dotfiles/test.sh` | repo lint, run before pushing |

`install.sh` installs `paru` and `chezmoi` if missing, applies everything and
exits non-zero on the first failure. An update is only applied, so it reports
`✔ APPLIED`: it verifies the apply converged (`chezmoi status` empty) but not the
machine. `--validate` adds that audit.

## What gets installed

`components` in `~/.config/chezmoi/chezmoi.toml` decides what the machine is: one
name per `packages.d/<name>.pacman` (plus an optional `.aur`). Edit the list and
re-apply. A disabled component stops being installed; it is **not** uninstalled.

```toml
# ~/.config/chezmoi/chezmoi.toml
[data]
    components = ["shell", "monitoring", "audio_pro", "apps"]
```

| Component | What it brings |
|---|---|
| `base` | always installed, not a switch: git, python, rsync, ripgrep, snapper, fwupd, openssh… |
| `shell` | zsh + Powerlevel10k + autosuggestions/syntax-highlighting/zoxide |
| `monitoring` | btop, nvtop, duf, fastfetch, plocate |
| `gpu_nvidia` | NVIDIA driver stack (libva-nvidia-driver, opencl, vulkan layers) |
| `hardware_amd` | iGPU Vulkan, amd-ucode, acpi_call, ryzenadj + ryzen_smu |
| `audio_pro` | PipeWire/JACK stack, realtime group, rtirq, samba (winbind for Wine) |
| `virtualization` | QEMU, libvirt, virt-manager, OVMF/swtpm |
| `containers` | podman, distrobox |
| `network_security` | ufw, proton-vpn-cli |
| `apps` | firefox, zed, bitwarden(+cli), Material You theming packages |
| `peripherals` | logiops + the MX Master 3S `logid` config |
| `looking_glass` | Looking Glass host client (IVSHMEM) |
| `wine` | wine-staging 9.21 standalone runner, winetricks, yabridge — **off by default** |

Applications are not components: they live in `bricks/`, are never installed by an
apply, and are installed by hand when wanted. See
[`bricks/README.md`](bricks/README.md).

```bash
./bricks/install --list
./bricks/install audio-apps           # REAPER, qpwgraph, lsp-plugins, AUR bundles
./bricks/install creative misc-apps   # Blender, OBS… / obsidian, localsend…
```

## Scripts

`.chezmoiscripts/` is a chezmoi special directory: run, never deployed. They run
in filename order, hence the numbers.

| Script | What it does |
|---|---|
| `run_once_01-packages.sh.tmpl` | installs `base` + the enabled components (`packages.d/`) |
| `run_once_02-wine-staging.sh.tmpl` | wine-staging runner (`wine`) |
| `run_onchange_03-omenctl.sh` | fetches omenctl at a pinned ref |
| `run_once_04-omenctl.sh.tmpl` | omenctl units + udev rules |
| `run_once_05-vfio-setup.sh.tmpl` | GPU passthrough (`virtualization`) |
| `run_once_06-libvirt-setup.sh.tmpl` | libvirt services + groups (`virtualization`) |
| `run_onchange_07-looking-glass.sh.tmpl` | Looking Glass shm/sysctl, with teardown (`looking_glass`) |
| `run_once_08-kde-settings.sh` | KDE settings via `kwriteconfig6` |
| `run_once_09-material-you.sh` | Material You “follows-the-wallpaper” hook |
| `run_once_10-fstab-shared.sh` | shared NTFS partition in fstab |
| `run_once_11-boot-tuning.sh.tmpl` | initramfs slimming + Limine snapshot cap |
| `run_onchange_12-peripherals.sh.tmpl` | `logid` config for the MX Master 3S (`peripherals`) |

A component switch also gates its scripts: they call `component-guard` and no-op
when the component is off. Details in [`docs/setup.md`](docs/setup.md#how-components-gate-scripts).

Two trees are not deployed by chezmoi — `etc/` (system files) and `packages.d/` —
because a script installs them. That script therefore carries a hash of what it
installs, so editing the content re-runs it: **when you add a file under `etc/`,
add its path to the `etc-hash:` line of the script that installs it.** Without it
chezmoi sees an unchanged script and never redeploys. `pkg-hash:` in
`run_once_01` covers `packages.d/` the same way, automatically.

## Reference

| Document | What it covers |
|---|---|
| [`docs/setup.md`](docs/setup.md) | repository map, component gating, `etc/` files, hardware, stack, omenctl, aliases |
| [`docs/boot-tuning.md`](docs/boot-tuning.md) | initramfs slimming, UEFI boot entries |
| [`docs/material-you.md`](docs/material-you.md) | wallpaper-driven theming, KWin transparency/blur |
| [`docs/notes.md`](docs/notes.md) | versioned vs. not, PipeWire, SSH keys |
| [`bricks/README.md`](bricks/README.md) | opt-in application bundles |

## License

MIT for this repository. The two KDE plasmoids under
`dot_local/share/plasma/plasmoids/` are vendored upstream projects and keep their
own licenses (MIT / GPL-3.0+, see [`docs/setup.md`](docs/setup.md#vendored-third-party-widgets)).
