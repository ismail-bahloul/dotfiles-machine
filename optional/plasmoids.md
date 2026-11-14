# Plasmoids

Deux widgets Plasma, épinglés par commit (un tag peut bouger, un commit non).

| ID | Upstream | Ref | SHA |
|---|---|---|---|
| `com.github.mazen.salatprayertime` | `mazenmohamed203/salaatprayertime` | v2.5.6 | `90ddf71939e3d5fc203d0d262cb734bdebf2e899` |
| `org.kde.olib.thermalmonitor` | `olib/thermalmonitor` | v0.2.7 | `d07702013d3748cb7412151a04115d18611aa0f3` |

URLs utilisées par l'ancien script :

```
https://codeload.github.com/mazenmohamed203/salaatprayertime/tar.gz/90ddf71939e3d5fc203d0d262cb734bdebf2e899
https://invent.kde.org/olib/thermalmonitor/-/archive/d07702013d3748cb7412151a04115d18611aa0f3/thermalmonitor-d07702013d3748cb7412151a04115d18611aa0f3.tar.gz
```

## Installer

```bash
tmp=$(mktemp -d)
curl -fsSL "URL" -o "$tmp/src.tgz"
tar -xzf "$tmp/src.tgz" -C "$tmp"
root=$(find "$tmp" -name metadata.json -printf '%h\n' | head -1)
mkdir -p "$HOME/.local/share/plasma/plasmoids/<id>"
cp -r "$root/metadata.json" "$root/contents" \
  "$HOME/.local/share/plasma/plasmoids/<id>/"
```

Puis redémarre Plasma (ou retire/rajoute le widget). L'ancien script remplaçait
le dossier entier pour éviter les restes d'une ancienne version ; fais pareil
si tu mets à jour.

Le plasmoid de prière embarque un enregistrement d'adhan de 2,7 Mo ; c'est
pour ça qu'il n'est pas vendorisé dans le dépôt.
