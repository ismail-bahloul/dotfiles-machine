# omenctl

Outil séparé (ventilateurs EC + profils de puissance). D'après la doc il est
**privé** ; garde un clone local ou une archive, sinon une fresh install ne
pourra pas l'installer.

- repo : `https://github.com/ismail-bahloul/omenctl.git`
- ref utilisée par l'ancien script : `v0.5.0`

## Installer

Depuis un checkout contenant `omenctl.py`, `omenctl-run.sh` et
`omenctl.service` :

```bash
sudo install -Dm755 omenctl.py /usr/local/bin/omenctl
sudo install -Dm755 omenctl-run.sh /usr/local/bin/omenctl-run.sh
sudo install -Dm644 omenctl.service /etc/systemd/system/omenctl.service
sudo systemctl daemon-reload
sudo systemctl enable --now omenctl.service
```

Les units `omenctl-profile.service`, `omenctl-profile.timer`,
`omenctl-watch.service` et les règles udev sont déjà dans `../system/etc/`
(`install.sh --system` les copie).

Vérifier :

```bash
omenctl status
systemctl status omenctl.service
```

## Si tu n'utilises pas omenctl

L'ancien repo masquait `power-profiles-daemon`. Sans omenctl, remets-le :

```bash
sudo systemctl unmask power-profiles-daemon.service
sudo systemctl enable --now power-profiles-daemon.service
```

Sans l'un ou l'autre, les ventilateurs restent sur la courbe EC par défaut
(plus bruyante à haute température), ce qui est sûr mais moins agréable.
