# Looking Glass

Client sur l'hôte pour afficher la VM Windows via mémoire partagée.

## Paquets

```bash
paru -S looking-glass
# Le module KVMFR n'est pas utilisé ici : le client lit /dev/shm.
# paru -S looking-glass-module-dkms   # seulement si tu passes au mode KVMFR
```

## Mémoire partagée

`../system/etc/tmpfiles.d/looking-glass.conf` crée :

```
f /dev/shm/looking-glass 0660 root kvm - 64M
```

Après `install.sh --system` :

```bash
sudo systemd-tmpfiles --create /etc/tmpfiles.d/looking-glass.conf
sudo usermod -aG kvm "$USER"     # si pas déjà fait par libvirt
```

## Client

`../home/dot_config/looking-glass/client.ini` est déployé par chezmoi :

```ini
[app]
shmFile=/dev/shm/looking-glass

[spice]
input=no

[input]
escapeKey=97
```

## Côté VM (hors de ce dépôt)

La VM doit être démarrée **sur l'entrée VFIO** (dGPU sur `vfio-pci`) et QEMU
doit exposer le buffer :

```
-object memory-backend-file,id=shmem,size=64M,mem-path=/dev/shm/looking-glass,share=on
-device ivshmem-plain,memdev=shmem
```

Les détails (XML libvirt, pilote invité, résolution) sont dans `myomen15` et
dans l'ancien `run_onchange_07-looking-glass.sh` (tag `v2-full`).

## À sauvegarder à part

Les définitions de VM ne sont **pas** dans ce dépôt :

```bash
virsh dumpxml <nom> > vm-<nom>.xml
# ou : sudo cp -a /etc/libvirt/qemu/*.xml ...
```
