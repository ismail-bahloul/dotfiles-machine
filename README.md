# machine — HP OMEN 15-en1xxx (CachyOS)

Sauvegarde de la configuration **machine** de ce laptop et runbook de
restauration. Ce n'est **pas** un installeur : il ne remplace pas la mise en
place du socle (partitionnement btrfs, ESP, installation Limine, binding
NVIDIA, configuration KDE). Il sauvegarde ce qui a été ajouté/configuré
au-dessus, et il documente les gestes qui ne sont pas des fichiers.

Le layer userspace portable (`~/.zshrc`, `~/.p10k.zsh`, kitty, git, gh) reste
dans le dépôt `dotfiles`. Ce dépôt-ci contient le layer machine :

```
.
├── README.md
├── bootstrap-machine.sh     # entrée /m : clone + install.sh --all
├── install.sh               # paquets + (option) /etc + (option) home
├── packages/
│   ├── repo.txt             # pacman -Qqen (snapshot)
│   ├── aur.txt              # pacman -Qqem (snapshot)
│   ├── modified-etc.txt     # chemins des /etc modifiés (référence)
│   └── enabled-services.txt # systemctl list-unit-files --state=enabled
├── home/                    # source chezmoi pour les configs $HOME machine
├── system/
│   ├── etc/                 # fichiers /etc sûrs à recopier
│   ├── etc-reference/       # fichiers à relire avant de copier
│   └── optional/            # units de recherche/optionnelles
├── boot/                    # snippet VFIO + référence limine.conf
└── optional/                # material-you, plasmoids, wine, looking-glass…
```

La source chezmoi est `home/`, jamais la racine. Un `.chezmoiignore` racine
contient `*` : si `~/.local/share/chezmoi` pointe encore ici, `chezmoi apply`
ne déploie rien. Pointe-le plutôt vers le dossier `home/` du dépôt (par ex.
`~/.local/share/chezmoi -> ~/machine/home`).

## One-liner

```bash
curl -fsSL https://ismailbahloul.com/m | bash
```

Clone/update `~/machine` puis `./install.sh --all` (paquets +
`system/etc` + `home/`). Les services, Limine/VFIO et snapper restent manuels
(voir la suite). Aperçu : `... | bash -s -- --dry-run`. Paquets seuls : clone
puis `./install.sh`.

## Matériel / constantes

| Élément | Valeur au moment de la sauvegarde |
|---|---|
| Laptop | HP OMEN 15-en1037nf (4J8B4EA) |
| CPU | AMD Ryzen 7 5800H (Zen 3) |
| dGPU | NVIDIA RTX 3070 Mobile (`10de:249d`, audio `10de:228b`) |
| iGPU | AMD Radeon Vega (Renoir/Cezanne) |
| Audio | RME Babyface Pro FS (CC + TuxMix), carte interne Ryzen |
| OS | CachyOS/Arch, kernel `linux-cachyos` 7.3.4-1 |
| Root | btrfs, subvolumes `@`, `@home`, `@root`, `@srv`, `@cache`, `@tmp`, `@log` |
| ESP | vfat sur `/boot`, UUID `6C6A-97E6` |
| Root UUID | `57178726-50eb-4fb0-80e6-3129e74425f4` |
| SHARED | NTFS UUID `5CAC12755C11BA05`, monté sur `~/SHARED` |
| Boot | Limine + `limine-entry-tool` + `limine-snapper-sync` |

Les UUID changent à chaque réinstallation : adapte `fstab`, `default/limine`
et le snippet VFIO. Les IDs PCI et l'UUID NTFS ne changent que si tu changes
le GPU ou reformates la partition Windows.

Les commandes ci-dessous se lancent depuis la racine du dépôt (sauf
indication contraire).

## Ordre de restauration

### 0. Socle

Il faut un Arch/CachyOS **bootable** pour lancer ce dépôt. Le snapshot
`packages/repo.txt` contient déjà la pile logicielle de cette machine :
`linux-cachyos`, `linux-cachyos-headers`, `linux-cachyos-nvidia-open`,
`nvidia-utils`, `chwd`, `limine`, `limine-mkinitcpio-hook`,
`limine-snapper-sync`, `plasma-desktop`, `paru`, `chezmoi`, `efibootmgr`,
`btrfs-progs`… `./install.sh` les installe.

Ce qui n'est **pas** dans les fichiers et reste à faire à la main :

- le partitionnement btrfs et les subvolumes (`@`, `@home`, `@root`, `@srv`,
  `@cache`, `@tmp`, `@log`) ;
- l'ESP vfat montée sur `/boot` (2–4 GiB) ;
- l'installation du bootloader Limine sur l'ESP et son entrée UEFI ;
- le binding/chargement du driver NVIDIA (`chwd`, `nvidia_drm.modeset=1`) ;
- la configuration de KDE/plasmalogin, le réseau, les services.

Si tu pars d'une ISO vierge, installe d'abord un minimum bootable (base,
réseau, `base-devel`, `git`), active les dépôts CachyOS (`cachyos-keyring`,
`cachyos-mirrorlist`, `[cachyos]`, `[cachyos-v3]`, `[cachyos-core-v3]`,
`[cachyos-extra-v3]` avant `core`/`extra`, puis `pacman -Syu` complet),
installe `paru` et `chezmoi`, puis lance `./install.sh`.

### 1. Paquets

```bash
sudo pacman -Syu
./install.sh              # dépôts + AUR
# ./install.sh --all      # + /etc + home/ (services et boot restent manuels)
```

`packages/repo.txt` et `packages/aur.txt` sont des **snapshots**, pas une
curation : ils contiennent tout ce qui était explicitement installé, y compris
des apps que tu ne veux peut-être plus (DaVinci, ollama, outils de recherche,
jeux…). Enlève-les avant de restaurer. `packages/modified-etc.txt` et
`packages/enabled-services.txt` sont des références.

### 2. Configs `$HOME`

```bash
# layer portable
curl -fsSL https://ismailbahloul.com/d | bash

# layer machine (ce dépôt)
chezmoi --source "$PWD/home" diff   # voir ce qui serait écrasé
chezmoi --source "$PWD/home" apply
```

`home/` déploie `~/.config/zsh/machine.zsh` (sourcé par le `.zshrc` portable),
`~/.config/kitty/local.conf` (globé par le `kitty.conf` portable), btop,
PipeWire/WirePlumber, les `.rc` KDE stables, les outils `~/.local/bin` et les
générateurs Material You. Les secrets (`~/.ssh/id_*`, `~/.config/gh/hosts.yml`,
`~/.config/zsh/secrets`) ne sont pas ici.

`machine.zsh` contient des alias propres à la machine : `ww`/`vv`/`ll`
(Limine Windows/VFIO/Linux), `power`/`auto`/`eco`/`perf` (omenctl) et `uu`
(`~/DATA/05_Code/Projects/arch-auto-update/arch-auto-update`). Adapte `uu`
ou ignore-le si ce checkout n'existe pas.

### 3. Fichiers `/etc`

```bash
sudo rsync -a --chown=root:root system/etc/ /etc/
sudo systemctl daemon-reload
sudo systemd-tmpfiles --create
sudo udevadm control --reload-rules && sudo udevadm trigger
```

Puis relis et copie **à la main** ce dont tu as besoin depuis
`system/etc-reference/` :

| Fichier | Note |
|---|---|
| `fstab` | UUID/subvolumes à adapter. La première ligne (`New Partition …`) semble être un résidu : vérifie-la. |
| `pacman.conf` | dépôts CachyOS + multilib ; adapte si tes miroirs changent. |
| `mkinitcpio.conf` | contient déjà `MODULES=(vfio_pci …)` ; si tu utilises le drop-in `50-vfio.conf`, ne garde pas les deux. |
| `limine-snapper-sync.conf` | `MAX_SNAPSHOT_ENTRIES=8`, `EXCLUDE_SNAPSHOT_ENTRIES="Windows*, windows*"`. |
| `conf.d/snapper` | `SNAPPER_CONFIGS="root home"` ; crée les configs (voir §6). |
| `default/limine` | `KERNEL_CMDLINE[default]` + `BOOT_ORDER` ; remplace l'UUID racine. |
| `limine-entry-tool.conf` | défauts de l'outil ; `/etc/default/limine` suffit en général. |
| `locale.gen`, `locale.conf`, `vconsole.conf`, `hostname`, `hosts` | identité de la machine ; à adapter. |
| `plymouth/plymouthd.conf` | thème Plymouth (`details`). |
| `ufw/user*.rules` | règles firewall ; réseau-specific. |
| `libvirt/network.conf` | généré par libvirt ; souvent inutile à copier. |
| `sudoers.d/99-wheel-nopasswd` | décision de sécurité (`%wheel NOPASSWD`) ; à assumer. |

Ne copie pas `fstab`/`pacman.conf` aveuglément si les UUID ou les dépôts ont
changé. Les fichiers de `system/etc/` (units, udev, drop-ins mkinitcpio,
modprobe, limites audio, logid) sont eux prévus pour être recopiés.

### 4. Services

Liste curatée (le snapshot complet est dans `packages/enabled-services.txt`).
omenctl doit être installé avant d'activer ses units : voir
[`optional/omenctl.md`](optional/omenctl.md).

```bash
sudo systemctl enable --now plasmalogin.service
sudo systemctl enable --now NetworkManager.service systemd-resolved.service \
  systemd-timesyncd.service
sudo systemctl enable --now nvidia-persistenced.service \
  nvidia-suspend.service nvidia-resume.service
sudo systemctl enable --now ufw.service logid.service
sudo systemctl enable --now omenctl.service omenctl-profile.service \
  omenctl-profile.timer omenctl-watch.service
sudo systemctl enable --now limine-snapper-sync.service \
  snapper-timeline.timer snapper-cleanup.timer snapper-boot.timer
```

Libvirt (sockets, adapte à ce que tu utilises) :

```bash
for drv in qemu interface network nodedev nwfilter secret storage; do
  sudo systemctl enable --now "virt${drv}d.socket"
done
sudo systemctl enable --now virtlogd.socket virtlockd.socket
```

Optionnels/CachyOS : `ananicy-cpp.service`, `dmemcg-booster-system.service`,
`cachyos-iw-set-regdomain.path`, `cachyos-rate-mirrors.timer`,
`paccache.timer`, `fstrim.timer`, `proton.VPN.service`,
`windscribe-helper.service`, `ollama.service`.

`power-profiles-daemon` est masqué par l'ancien repo. Si tu n'utilises pas
omenctl, démarre-le à la place :

```bash
sudo systemctl unmask power-profiles-daemon.service
sudo systemctl enable --now power-profiles-daemon.service
```

### 5. Boot / VFIO

Voir [`boot/README.md`](boot/README.md). En résumé :

```bash
# 1) modules VFIO dans l'initramfs (drop-in fourni)
sudo install -Dm644 system/etc/mkinitcpio.conf.d/50-vfio.conf \
  /etc/mkinitcpio.conf.d/50-vfio.conf

# 2) ajouter l'entrée VFIO à /boot/limine.conf :
#    copier l'entrée normale, puis ajouter au cmdline :
#    vfio-pci.ids=10de:249d,10de:228b
#    (et iommu=pt s'il n'y est pas déjà)

# 3) régénérer l'initramfs
sudo mkinitcpio -P

# 4) rebooter sur l'entrée VFIO et vérifier
lspci -nnk | grep -A3 -i nvidia   # vfio-pci attendu
ls /dev/vfio/
```

### 6. Snapper / snapshots

```bash
sudo snapper -c root create-config /
# si tu veux aussi les snapshots de /home (SNAPPER_CONFIGS="root home") :
sudo snapper -c home create-config /home

# vérifier MAX_SNAPSHOT_ENTRIES=8 dans /etc/limine-snapper-sync.conf
sudo systemctl enable --now limine-snapper-sync.service \
  snapper-timeline.timer snapper-cleanup.timer snapper-boot.timer

# snapshots automatiques avant/après pacman :
sudo pacman -S --needed snap-pac
```

### 7. Optionnel

Voir [`optional/README.md`](optional/README.md) : Material You, plasmoids,
KDE settings, wine, Looking Glass, omenctl, units de recherche.

### 8. Vérifications

```bash
systemctl --failed
journalctl -b -p err
lspci -nnk | grep -A3 -i nvidia     # normal : nvidia ; VFIO : vfio-pci
ls /dev/vfio/
snapper list
ufw status
virsh list --all
omenctl status
pw-top                              # audio, pas de xruns
```

Checklist manuelle :

- écran externe 2560×1440 @ 144 Hz (DP sur le dGPU) ;
- RME Babyface (CC ou TuxMix) + quantum 64/256 ;
- fans/omenctl (courbe, pas de surchauffe) ;
- boot VFIO : dGPU sur `vfio-pci`, VM Windows OK ;
- snapshots visibles dans Limine ;
- Wi-Fi/Bluetooth, veille/reprise, clavier rétroéclairé.

## Ce qui n'est **pas** automatisé

- la mise en place du socle (btrfs/ESP, installation Limine, binding NVIDIA,
  configuration KDE) ;
- l'entrée VFIO et `limine.conf` (fragile, dépend du layout Limine) ;
- `fstab`, `pacman.conf`, `mkinitcpio.conf` (à relire, UUID/dépôts) ;
- les services (à activer à la main) ;
- les réglages KDE runtime (`kwinrc`, `kdeglobals`, `kglobalshortcutsrc`) ;
- omenctl (outil séparé, repo privé) ;
- Material You/plasmoids/wine/Looking Glass (optionnels).

## Secrets et sauvegarde

Ne commite **jamais** : `~/.ssh/id_*`, `~/.config/gh/hosts.yml`,
`~/.config/zsh/secrets`, clés Wi-Fi/VPN, tokens, `/etc/shadow`,
`/etc/NetworkManager/system-connections/*`.

- Identité git : `~/.config/git/local` (nom/email), non versionné.
- Ce dépôt sauvegarde la **config**, pas les données. Pour les données :
  `restic`/`borg`/`kopia` + snapshots btrfs. Un snapshot local n'est pas un
  backup hors disque.
- Pousse ce dépôt sur un remote privé.

## Ancien dépôt (`v2-full`)

Ce dépôt s'appelait `dotfiles-machine` (renommé `machine`) et contenait
l'automatisation complète
(scripts `run_once_`, `validate.sh`, `smoke.sh`, `test.sh` et l'ancien
`bootstrap-machine.sh` complet). Elle est conservée dans le tag `v2-full` :

```bash
git show v2-full:validate.sh
git worktree add /tmp/machine-v2-full v2-full
```

Les mesures et le « pourquoi » sont dans `myomen15`.

Le `bootstrap-machine.sh` actuel est un lanceur minimal : clone/update puis
`install.sh --all`.
