# Components

`components` in `~/.config/chezmoi/chezmoi.toml` decides what the machine is:
one name per `packages.d/<name>.pacman` (plus an optional `.aur`). Edit the list
and re-apply. A disabled component stops being installed; it is **not**
uninstalled.

```toml
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

A component also gates its scripts (`component-guard`): disabling one turns its
`run_` scripts into no-ops. Details in [setup.md](setup.md#how-components-gate-scripts).

## Applications (bricks)

Applications are not components: they live in `bricks/`, are never installed by
an apply, and are installed by hand.

```bash
./bricks/install --list
./bricks/install audio-apps          # REAPER, qpwgraph, lsp-plugins, AUR bundles
./bricks/install creative misc-apps  # Blender, OBS… / obsidian, localsend…
```

See [`bricks/README.md`](../bricks/README.md).
