# boot — Limine + VFIO

## Fichiers

Les chemins `../...` ci-dessous supposent que tu lances les commandes depuis
`machine/boot/`. Depuis la racine du dépôt, retire le `../`.

| Fichier | Contenu |
|---|---|
| `limine.conf.reference` | les 35 premières lignes de `/boot/limine.conf` au moment de la sauvegarde : réglages + entrées `linux-cachyos` et `linux-cachyos-vfio` (sans les snapshots). |
| `limine-vfio-entry.conf` | le **modèle** d'entrée VFIO (chemins à récupérer sur la nouvelle install). |
| `cmdline-vfio.txt` | les paramètres à ajouter et le cmdline complet de référence. |

## Ce qu'il faut comprendre

Sur cette machine, `/boot/limine.conf` est généré par `limine-entry-tool`.
L'entrée normale est dans le menu `/+CachyOS`, sous `linux-cachyos` (chemin
`default_entry` : `CachyOS/linux-cachyos`) ; son cmdline vient de
`KERNEL_CMDLINE[default]` dans `/etc/default/limine`. L'entrée VFIO est une
**copie manuelle** de l'entrée normale avec deux paramètres en plus :

```
iommu=pt vfio-pci.ids=10de:249d,10de:228b
```

Au moment de la sauvegarde, `default_entry` pointait sur
`CachyOS/linux-cachyos-vfio`. Pour démarrer normalement, utilise
`~/.local/bin/limine-boot-linux` (déployé par `home/`) ou change
`default_entry` en `CachyOS/linux-cachyos`.

## Procédure

1. **Initramfs** : copier le drop-in, ou ajouter les modules à la main.

   ```bash
   sudo install -Dm644 ../system/etc/mkinitcpio.conf.d/50-vfio.conf \
     /etc/mkinitcpio.conf.d/50-vfio.conf
   # équivalent manuel : MODULES+=(vfio_pci vfio vfio_iommu_type1)
   ```

2. **Entrée Limine** : le plus sûr est de copier l'entrée normale générée et
   d'ajouter `vfio-pci.ids=10de:249d,10de:228b` à son `cmdline` (et `iommu=pt`
   s'il n'y est pas déjà — c'est le cas ici via `/etc/default/limine`). C'est ce
   que fait `../optional/bin/.add-vfio-entry` :

   ```bash
   sudo python3 ../optional/bin/.add-vfio-entry /boot/limine.conf
   ```

   Ou à la main : dupliquer `//linux-cachyos` en `//linux-cachyos-vfio`,
   garder `protocol`, `path`, `module_path`, et modifier `cmdline`.

3. **Régénérer l'initramfs** :

   ```bash
   sudo mkinitcpio -P
   ```

4. **Rebooter sur l'entrée VFIO** et vérifier :

   ```bash
   lspci -nnk | grep -A3 -i nvidia   # vfio-pci pour 10de:249d et 10de:228b
   ls /dev/vfio/
   journalctl -b | grep -i vfio
   ```

5. **Rebooter sur l'entrée normale** : `nvidia` doit reprendre le dGPU et
   l'écran externe doit s'allumer.

## Snapshots

`limine-snapper-sync` recopie les entrées pour chaque snapshot. La config de
référence (`../system/etc-reference/limine-snapper-sync.conf`) limite à 8
entrées et exclut les entrées Windows :

```
MAX_SNAPSHOT_ENTRIES=8
EXCLUDE_SNAPSHOT_ENTRIES="Windows*, windows*"
```

Sans ce cap, l'ESP de 4 GiB se remplit et les mises à jour de kernel échouent.
