# optional — non appliqué par défaut

Ces éléments ne sont pas nécessaires à une machine qui démarre et qui sert au
quotidien. Ils sont ici pour ne pas les perdre. Les scripts d'origine
(`run_once_02`, `run_once_08`, `run_once_09`, `run_onchange_07`,
`run_onchange_13`, `run_onchange_03`) restent dans l'ancien `dotfiles-machine`
(tag `v2-full`) ;
l'intention est de taguer cet état `v2-full` avant de l'archiver.

| Élément | Fichier | À faire |
|---|---|---|
| Material You | `material-you.md` | `kde-material-you-colors` + config du hook |
| Plasmoids | `plasmoids.md` | salatprayertime + thermalmonitor |
| KDE settings | `kde-settings.md` | ancien `run_once_08` (kwriteconfig6) |
| Wine | `wine.md` | ancien `run_once_02` (wine-staging 9.21) |
| Looking Glass | `looking-glass.md` | paquets + tmpfile + client.ini |
| omenctl | `omenctl.md` | repo séparé + units/udev |
| Probes / ollama | `../system/optional/etc/systemd/system/` | units à activer à la main |
| `.add-vfio-entry` | `bin/.add-vfio-entry` | helper pour ajouter l'entrée VFIO |

Le helper `.add-vfio-entry` est l'ancien parseur de `limine.conf`. La
procédure supportée est dans `../boot/README.md` ; le helper reste utile si tu
veux automatiser l'ajout.
