# Material You

Le desktop (kitty, btop, prompt, Zed, Zen) suit les couleurs du fond d'écran.
`kde-material-you-colors` régénère la palette à chaque changement de wallpaper
et appelle le hook, qui relance les générateurs.

## Fichiers déjà dans `home/`

- `~/.local/lib/material-you/{kitty,btop,zed,zen,prompt}.py` (générateurs) ;
- `~/.local/bin/kitty-material-you-hook.sh` (hook) ;
- `~/.local/bin/material-you-refresh` (resynchronisation manuelle) ;
- `~/.config/kitty/local.conf` : `include theme-wallpaper.conf` (le thème
  généré) ;
- `~/.config/zsh/machine.zsh` : `_prompt_material` + alias `material-refresh`.

Applique-les d'abord (depuis la racine du dépôt) :

```bash
chezmoi --source "$PWD/home" apply
```

## Daemon

```bash
paru -S kde-material-you-colors
mkdir -p ~/.config/kde-material-you-colors
printf '[CUSTOM]\non_change_hook=%s\n' \
  "$HOME/.local/bin/kitty-material-you-hook.sh" \
  > ~/.config/kde-material-you-colors/config.conf
```

Le daemon démarre via l'autostart KDE
(`app-kde-material-you-colors@autostart.service`). S'il ne tourne pas :

```bash
kde-material-you-colors --stop 2>/dev/null || true
nohup kde-material-you-colors >/dev/null 2>&1 &
```

Premier rendu :

```bash
~/.local/bin/material-you-refresh
```

## Notes

- Zed et Zen ne relisent leurs couleurs qu'au démarrage ; `material-you-refresh`
  le rappelle.
- Le `50-tuxmix.conf.disabled` de PipeWire est le mode propriétaire RME ; voir
  `~/.config/pipewire/pipewire.conf.d/README.md` après application.
- Si tu n'utilises pas Zed/Zen, les générateurs correspondants sont inutiles
  mais inoffensifs.
