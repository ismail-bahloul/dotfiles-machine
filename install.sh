#!/bin/bash
# =============================================================================
# install.sh — restaure la couche machine (paquets + fichiers /etc).
#
# Ce n'est PAS un installeur complet : la mise en place du socle (btrfs/ESP,
# Limine, KDE/NVIDIA), les entrées de boot, les services et les éléments
# optionnels sont documentés dans README.md et appliqués à la main.
#
# Usage :
#   ./install.sh             # paquets pacman + AUR
#   ./install.sh --system    # + copie de system/etc/ vers /etc
#   ./install.sh --home      # + application de home/ avec chezmoi
#   ./install.sh --all       # paquets + system + home
#   ./install.sh --dry-run   # affiche, ne change rien
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")"

DRY_RUN=false
DO_SYSTEM=false
DO_HOME=false

usage() {
  cat <<'USAGE'
usage: ./install.sh [--system] [--home] [--all] [--dry-run]

  (défaut)    installe packages/repo.txt puis packages/aur.txt
  --system    copie system/etc/ vers /etc, recharge systemd/udev
  --home      applique home/ avec chezmoi (--source)
  --all       --system + --home
  --dry-run   affiche les commandes sans les exécuter

Le socle (kernel, Limine, KDE, NVIDIA), les services, l'entrée VFIO et
snapper restent manuels : voir README.md.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --system)  DO_SYSTEM=true ;;
    --home)    DO_HOME=true ;;
    --all)     DO_SYSTEM=true; DO_HOME=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install: argument inconnu: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

run() {
  if $DRY_RUN; then
    printf '  + %s\n' "$*"
  else
    "$@"
  fi
}

if [ ! -f /etc/arch-release ] && [ ! -f /etc/cachyos-release ]; then
  echo "install: Arch/CachyOS uniquement." >&2
  exit 1
fi
if [ "$(id -u)" = 0 ]; then
  echo "install: lance ce script en utilisateur normal (sudo demandé au besoin)." >&2
  exit 1
fi

if ! $DRY_RUN; then
  sudo -v
fi

echo
echo "== Paquets (dépôts) =="
if [ -s packages/repo.txt ]; then
  run sudo pacman -S --needed - < packages/repo.txt
else
  echo "  packages/repo.txt absent ou vide — rien à faire"
fi

echo
echo "== Paquets (AUR) =="
if [ -s packages/aur.txt ]; then
  if ! command -v paru >/dev/null 2>&1; then
    echo "  paru est requis pour packages/aur.txt (installe-le d'abord)." >&2
    exit 1
  fi
  run xargs -a packages/aur.txt paru -S --needed --noconfirm
else
  echo "  packages/aur.txt absent ou vide — rien à faire"
fi

if $DO_SYSTEM; then
  echo
  echo "== Fichiers système (system/etc → /etc) =="
  if ! command -v rsync >/dev/null 2>&1; then
    echo "  rsync manquant." >&2
    exit 1
  fi
  run sudo rsync -a --chown=root:root system/etc/ /etc/
  run sudo systemctl daemon-reload
  if [ -d system/etc/tmpfiles.d ]; then
    run sudo systemd-tmpfiles --create
  fi
  run sudo udevadm control --reload-rules
  run sudo udevadm trigger
  echo
  echo "  Les fichiers de system/etc-reference/ ne sont PAS copiés :"
  echo "  relis-les et applique-les à la main (fstab, pacman.conf, ...)."
fi

if $DO_HOME; then
  echo
  echo "== Configs \$HOME (home/ → chezmoi) =="
  if ! command -v chezmoi >/dev/null 2>&1; then
    echo "  chezmoi manquant." >&2
    exit 1
  fi
  run chezmoi --source "$PWD/home" apply
fi

cat <<'EOF'

Terminer à la main (voir README.md) :
  - activer les services utiles (systemctl enable --now ...)
  - ajouter l'entrée VFIO et lancer mkinitcpio -P (boot/README.md)
  - configurer snapper / limine-snapper-sync
  - optionnel : material-you, plasmoids, wine, looking-glass (optional/README.md)
EOF
