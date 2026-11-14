# Wine (VST Windows)

Désactivé par défaut : uniquement utile pour les VST Windows via yabridge.
Le script d'origine est `run_once_02-wine-staging.sh` dans `dotfiles-machine`
(tag `v2-full`).

## Ce qu'il fait

- installe `winetricks` (dépôt) et `yabridge`/`yabridgectl` (AUR) ;
- retire les paquets système conflictuels `wine`, `wine-staging`,
  `wine-cachyos` et nettoie `IgnorePkg` dans `/etc/pacman.conf` ;
- télécharge `wine-staging-9.21-1-x86_64.pkg.tar.zst` depuis
  `archive.archlinux.org` ;
- l'extrait dans `~/.local/share/wine-runners/wine-staging-9.21-standalone` ;
- crée les symlinks `wine`, `wine64`, `wineserver` dans `~/.local/bin` et
  `/usr/local/bin` ;
- initialise `~/.wine` (`wineboot -u`) et installe `corefonts`.

## Dépendances côté audio

`audio_pro` installe `samba` (winbind/`ntlm_auth`) et
`lib32-pipewire-jack` (nécessaire à yabridge pour les VST 32 bits).

## Note

Le runner est volontairement standalone : il ne remplace pas le `wine` du
système et peut cohabiter avec d'autres versions. Si tu n'utilises pas de VST
Windows, ne restaure pas cette partie.
