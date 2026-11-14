# system

Trois niveaux, du plus sûr au plus manuel.

## `etc/` — à recopier

Miroir de `/etc` pour les fichiers que l'ancien dépôt installait et qui ne
dépendent pas (ou peu) de l'installation :

- `initcpio/install/{no-nouveau,amdgpu-trim}`
- `mkinitcpio.conf.d/{20-no-nouveau,30-amdgpu-early,40-amdgpu-trim,50-vfio}.conf`
- `systemd/system/omenctl.service`, `omenctl-profile.service`,
  `omenctl-profile.timer`, `omenctl-watch.service`
- `systemd/system/systemd-user-sessions.service` (override complet : voir plus bas)
- `systemd/system/nvidia-persistenced.service.d/10-vfio-skip.conf`
- `udev/rules.d/{99-omenctl,99-powercap,99-rme-babyface}.rules`
- `modprobe.d/{babyface-pro,kvm-quickemu,nvidia,nvidia-pm}.conf`
- `security/limits.d/{20-audio,99-realtime,99-realtime-privileges}.conf`
- `tmpfiles.d/looking-glass.conf`
- `logid.cfg`

Commande (depuis la racine du dépôt) :

```bash
sudo rsync -a --chown=root:root system/etc/ /etc/
sudo systemctl daemon-reload
sudo systemd-tmpfiles --create
sudo udevadm control --reload-rules && sudo udevadm trigger
```

Notes :

- **`systemd-user-sessions.service`** est une copie complète du vendor unit,
  avec `network.target` retiré de `After=`. C'est fragile : après une mise à
  jour de systemd, compare-le à `/usr/lib/systemd/system/systemd-user-sessions.service`
  et régénère-le si besoin.
- **`nvidia.conf`** a été généré par EnvyControl. Si tu réinstalles NVIDIA
  autrement, laisse EnvyControl le régénérer ou adapte les options.
- **`50-vfio.conf`** remplace l'édition de `MODULES=()` dans
  `/etc/mkinitcpio.conf`. Si tu copies aussi le `mkinitcpio.conf` de
  `etc-reference/`, ne garde pas les deux.

## `etc-reference/` — à relire avant de copier

Ces fichiers sont spécifiques à l'installation (UUID, dépôts, matériel).
Ils sont là pour la référence, pas pour un `rsync` aveugle :

| Fichier | Pourquoi |
|---|---|
| `fstab` | UUID/subvolumes ; la première ligne (`New Partition …`) semble être un résidu, vérifie-la. |
| `pacman.conf` | dépôts CachyOS + multilib ; adapte les miroirs. |
| `mkinitcpio.conf` | `MODULES=(vfio_pci …)` et `HOOKS=(… plymouth …)` ; redondant avec `50-vfio.conf`. |
| `limine-snapper-sync.conf` | `MAX_SNAPSHOT_ENTRIES=8`, `EXCLUDE_SNAPSHOT_ENTRIES="Windows*, windows*"`. |
| `conf.d/snapper` | `SNAPPER_CONFIGS="root home"`. |
| `default/limine` | `KERNEL_CMDLINE[default]` + `BOOT_ORDER` ; remplace l'UUID racine. |
| `limine-entry-tool.conf` | défauts de l'outil ; `/etc/default/limine` suffit en général. |
| `locale.gen`, `locale.conf`, `vconsole.conf`, `hostname`, `hosts` | identité de la machine. |
| `plymouth/plymouthd.conf` | thème Plymouth. |
| `ufw/user.rules`, `ufw/user6.rules` | règles firewall, réseau-specific. |
| `libvirt/network.conf` | généré par libvirt. |
| `sudoers.d/99-wheel-nopasswd` | `%wheel ALL=(ALL) NOPASSWD: ALL` : décision de sécurité. À copier en 0440 : `sudo install -Dm0440 system/etc-reference/sudoers.d/99-wheel-nopasswd /etc/sudoers.d/99-wheel-nopasswd`. |

## `optional/` — units de recherche/optionnelles

Non copiées par `install.sh --system` :

- `omen-fclk-probe.service`, `omen-rtd3-probe.service`,
  `spi-filter-capture.service` : probes `myomen15`, à activer à la main si tu
  refais ces expériences.
- `ollama.service` : service utilisateur pour `/usr/local/bin/ollama`.
