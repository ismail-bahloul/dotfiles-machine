# portable — the userspace core

The part of this repository that makes sense on **any** Linux: zsh, kitty, btop,
git, gh. No package manager, no root, no systemd, no KDE, no hardware.

This directory is a valid chezmoi source on its own — copy it out and it becomes
its own repo, unchanged.

```bash
curl -fsSL https://ismailbahloul.com/d | bash   # clone + apply
```

or, from a clone:

```bash
chezmoi --source ~/dotfiles/portable --dry-run apply   # preview
chezmoi --source ~/dotfiles/portable apply             # write the targets
```

`bootstrap.sh` refuses to overwrite a config that already exists — it lists the
files and stops — unless given `--force`. It also refuses to run on a host
already provisioned by the machine layer, whose dotfiles these would shadow
(`--force` overrides that too).

The targets are `~/.zshrc`, `~/.gitconfig` and `~/.config/{kitty,gh}`.

> Applying this source on a host that also has the machine layer prints
> `chezmoi: warning: config file template has changed`. That is expected:
> `portable/` has no `chezmoi.toml.tmpl`, so chezmoi compares the existing
> machine config against nothing. The apply is exact — `chezmoi --source …
> status` is empty afterwards.
>
> **Do not run `chezmoi init` to "fix" it.** With `--source portable` it would
> regenerate `~/.config/chezmoi/chezmoi.toml` from this source and drop the
> machine's `components` list.

## Extending it per machine

The two files that differ per host are **hooks**, not forks: the portable
sources leave a slot, the machine layer fills it.

| Hook | Provided by | Effect when absent |
|---|---|---|
| `~/.config/zsh/machine.zsh` | sourced at the end of `.zshrc` | nothing sourced |
| `~/.config/kitty/local.conf` | `globinclude` at the end of `kitty.conf` | silently nothing |

That is how the CachyOS layer adds the wallpaper palette and the
Limine/omenctl aliases without redeploying `~/.zshrc` or `kitty.conf`.

## Packages — nothing is installed for you

There are four packages and two optional ones. A three-line table beats a
multi-distro package abstraction:

| What | Arch | Fedora | Debian / Mint |
|---|---|---|---|
| shell | `zsh` | `zsh` | `zsh` |
| terminal | `kitty` | `kitty` | `kitty` |
| monitor | `btop` | `btop` | `btop` |
| GitHub CLI | `github-cli` | `gh` | `gh` |

Optional, used when present: `zsh-autosuggestions`, `zsh-syntax-highlighting`,
`zsh-history-substring-search`, `fzf`, `zoxide`, and powerlevel10k (Arch:
`zsh-theme-powerlevel10k`; elsewhere clone it into
`~/.local/share/powerlevel10k`). Each missing piece is reported once on stderr —
`zshrc: zsh-autosuggestions not found (install the distro package)` — rather
than degrading the shell silently.

## Font

`kitty.conf` asks for JetBrains Mono Nerd Font; kitty falls back to its builtin
monospace (with a log warning, not an error) when the family is absent. Nerd
Fonts are not packaged the same way everywhere, so the only distro-agnostic
route is the user font directory:

```bash
mkdir -p ~/.local/share/fonts
# drop JetBrainsMonoNerdFont*.ttf there, then:
fc-cache -f
```

## Deliberately absent

Material You / wallpaper theming, KDE `.rc` files, the Plasma plasmoids,
Limine and omenctl aliases, `etc/`, `packages.d/`, and the PipeWire/RME audio
config. Those are the machine layer: see the main repository and `docs/`.

Also absent: a `btop.conf`. btop has no include mechanism, so a wallpaper theme
name has to live *in* the file — the machine layer owns it outright and this
layer leaves btop on its defaults.

## Secrets

Neither the git identity (`~/.config/git/local`, pulled in by an `[include]`)
nor `~/.config/zsh/secrets` is versioned; `gh auth login` writes its own token
to `~/.config/gh/hosts.yml`.
