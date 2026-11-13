# Install

CachyOS or Arch only. On anything else `bootstrap-machine.sh` stops before
cloning and points at `/d`.

## One line

```bash
curl -fsSL https://ismailbahloul.com/m | bash
```

It clones this repository into `~/dotfiles`, installs `paru` and `chezmoi` if
missing, applies the machine source, then applies the userspace layer
(`dotfiles`) from its pinned tag into `~/.local/share/dotfiles-portable`.

`--dry-run` and `--validate` are forwarded to `install.sh`:

```bash
curl -fsSL https://ismailbahloul.com/m | bash -s -- --dry-run
```

## From a clone

```bash
git clone https://github.com/ismail-bahloul/dotfiles-machine.git ~/dotfiles-machine
~/dotfiles-machine/install.sh
```

## What install.sh does

1. checks Arch/CachyOS, non-root and network, then installs `paru` + `chezmoi`
2. `chezmoi init --apply` (or `chezmoi update --apply`) for this repository
3. applies the userspace layer at `DOTFILES_PORTABLE_REF` (`v1.1.0`)
4. runs `validate.sh` on a fresh install, or with `--validate`

`DOTFILES_PORTABLE_SRC=/path/to/dotfiles` uses a local userspace checkout
instead of the pinned clone.

A userspace checkout that sits on `main` is left alone: `install.sh` never
moves it back to the pinned tag, because `/d` follows `main` and rewinding it
here would undo a `/d` run. Bump `DOTFILES_PORTABLE_REF` to move the pin
forward, or set `DOTFILES_PORTABLE_ALLOW_DOWNGRADE=1` to force a checkout back
to the tag.

## [multilib]

A stock **Arch** needs `[multilib]` enabled in `/etc/pacman.conf` (`pacman -Sy`
afterwards): the 32-bit Wine/Steam/NVIDIA/Mesa packages live there. CachyOS
enables it by default, and `run_once_01` uncomments it when it finds the block
disabled, so a fresh Arch usually needs nothing.

## Updating

```bash
~/dotfiles/install.sh
```

A bare `chezmoi update --apply` only covers the machine half.

## Tests

| Command | What it does |
|---|---|
| `./install.sh --dry-run` | prerequisites only, nothing is changed |
| `./install.sh --validate` | + full machine audit (`validate.sh`) |
| `./smoke.sh` | `install.sh` and `bootstrap-machine.sh` control flow, offline |
| `./test.sh` | repo lint, run before pushing |

The blocks above carry no `#` comments on purpose: a stock zsh has
`interactive_comments` off, so pasting a commented block executes `#` as a
command.
