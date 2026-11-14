#!/bin/bash
# =============================================================================
# bootstrap-machine.sh — the /m entry point (CachyOS / Arch only)
#
#   curl -fsSL https://ismailbahloul.com/m | bash
#
# Clone or update the machine repository, then run install.sh.
# Default: install.sh --all (packages + safe /etc files + home/).
# Services, Limine/VFIO and snapper remain manual: see README.md.
#
# Arguments are forwarded to install.sh:
#   --system   /etc only (plus packages)
#   --home     home/ only (plus packages)
#   --all      packages + /etc + home
#   --dry-run  preview
#
# Deliberately self-contained: this file is piped before anything is cloned,
# so it cannot source lib/ and duplicates the one check it needs.
# =============================================================================
set -euo pipefail

REPO="${MACHINE_REPO:-${DOTFILES_REPO:-https://github.com/ismail-bahloul/dotfiles-machine.git}}"
DIR="${MACHINE_DIR:-${DOTFILES_DIR:-$HOME/dotfiles-machine}}"

if [ ! -f /etc/arch-release ] && [ ! -f /etc/cachyos-release ]; then
  cat >&2 <<'EOF'
bootstrap-machine: this entry point is the machine layer (CachyOS / Arch only).
  For the portable userspace layer on any distro:

      curl -fsSL https://ismailbahloul.com/d | bash
EOF
  exit 1
fi

if [ "$(id -u)" = 0 ]; then
  echo "bootstrap-machine: run as a normal user with sudo access." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "bootstrap-machine: git is not installed — installing it..." >&2
  sudo pacman -S --needed --noconfirm git
fi

if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only
else
  git clone "$REPO" "$DIR"
fi

# Default to the full file restore; a bare --dry-run previews that same plan.
if [ "$#" -eq 0 ]; then
  set -- --all
elif [ "$#" -eq 1 ] && [ "$1" = "--dry-run" ]; then
  set -- --all --dry-run
fi

exec "$DIR/install.sh" "$@"
