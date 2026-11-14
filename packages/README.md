# packages

Snapshots de ce qui était installé, pas une curation.

`repo.txt` couvre aussi le socle de cette machine (kernel `linux-cachyos`,
`linux-cachyos-nvidia-open`, `chwd`, `limine`, `plasma-desktop`, `paru`,
`chezmoi`…). `install.sh` l'installe ; la configuration (btrfs/ESP/Limine/
services) reste dans le runbook.

| Fichier | Commande | Usage |
|---|---|---|
| `repo.txt` | `pacman -Qqen` | paquets explicites des dépôts |
| `aur.txt` | `pacman -Qqem` | paquets explicites AUR/foreign |
| `modified-etc.txt` | `pacman -Qii` (backup files `[modified]`) | chemins des `/etc` modifiés, **sans contenu** |
| `enabled-services.txt` | `systemctl list-unit-files --state=enabled` | référence, à curater |

## Restaurer

Depuis la racine du dépôt :

```bash
sudo pacman -S --needed - < packages/repo.txt
xargs -a packages/aur.txt paru -S --needed --noconfirm
```

Prérequis : `base-devel`, `git`, `paru` (et `chezmoi` pour `home/`). Le
`--needed` évite de réinstaller ce qui est déjà là. Si `pacman` ou `paru`
échoue sur un paquet (renommé, cassé, retiré du dépôt), enlève-le de la liste
et relance : le reste s'installe.

## À faire avant de restaurer

- **Élague** `repo.txt` et `aur.txt` : les snapshots contiennent des apps
  lourdes ou ponctuelles (DaVinci Resolve, ollama, outils de recherche,
  jeux, anciens tests) que tu ne veux peut-être pas sur une install neuve.
- Les paquets AUR peuvent avoir changé de nom ou cassé ; `paru` te le dira.
- `modified-etc.txt` est une liste de **chemins**, pas de fichiers. Sers-toi
  en comme checklist pour retrouver les configs à sauvegarder.
- `enabled-services.txt` contient des units activées par les paquets
  (`getty@`, `systemd-resolved`, `remote-fs.target`…) : ne réactive pas tout
  aveuglément. La liste curatée est dans le `README.md` principal.

## Vérifier après

```bash
sudo pacman -Qkk | grep -v ' 0 altered files'
```
