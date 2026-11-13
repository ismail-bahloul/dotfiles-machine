# dotfiles-machine

The CachyOS/Arch machine, applied by [chezmoi](https://chezmoi.io): KDE Plasma 6
on Wayland, dual-boot Windows 11, VFIO + Looking Glass, a PipeWire pro-audio
chain, fan/power management, a slimmed initramfs.

```bash
curl -fsSL https://ismailbahloul.com/m | bash
```

Arch/CachyOS only; on anything else it stops before cloning and points at `/d`.

The userspace layer (`~/.zshrc`, `~/.p10k.zsh`, kitty, git, gh) is
[`dotfiles`](https://github.com/ismail-bahloul/dotfiles); this installer applies
it from a pinned tag.

Details: [install](docs/install.md) · [components](docs/components.md) ·
[setup reference](docs/setup.md) · [boot](docs/boot-tuning.md) ·
[theming](docs/material-you.md) · [notes](docs/notes.md)

MIT, see [LICENSE](LICENSE). The two KDE plasmoids are fetched from upstream and
keep their own licenses.
