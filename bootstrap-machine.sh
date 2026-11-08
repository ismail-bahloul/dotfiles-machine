#!/bin/bash
# =============================================================================
# bootstrap-machine.sh — the machine entry point (CachyOS / Arch only)
#
#   curl -fsSL https://ismailbahloul.com/m | bash
#
# Clones or updates the repository, then hands over to install.sh: paru +
# chezmoi, the component packages, the system files under etc/, and the
# post-install audit.
#
# Userspace dotfiles for any distro are the other entry point:
#   https://ismailbahloul.com/d
#
# Deliberately self-contained: this file is piped before anything is cloned, so
# it cannot source lib/ and duplicates the two variables it needs. Extra
# arguments are forwarded to install.sh (--dry-run, --validate).
# =============================================================================
set -euo pipefail

REPO="${DOTFILES_REPO:-https://github.com/ismail-bahloul/dotfiles.git}"
DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

# Fail before the clone: this layer writes /etc, systemd units and an initramfs,
# and install.sh would refuse on a non-Arch host anyway.
if [ ! -f /etc/arch-release ] && [ ! -f /etc/cachyos-release ]; then
  cat >&2 <<'EOF'
bootstrap-machine: this entry point is the machine layer (CachyOS / Arch only).
  It installs drivers, KDE, VFIO, the audio stack, initramfs hooks and udev
  rules. For the userspace dotfiles (zsh, kitty, btop, git, gh) on any distro:

      curl -fsSL https://ismailbahloul.com/d | bash
EOF
  exit 1
fi

# git is the one thing this file needs and cannot install itself through
# install.sh: on a bare Arch minimal install it is simply absent.
if ! command -v git >/dev/null 2>&1; then
  echo "bootstrap-machine: git is not installed — installing it..." >&2
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm git
  else
    echo "bootstrap-machine: install git first, then re-run." >&2
    exit 1
  fi
fi

# Re-runnable: update the clone if it is already there (a dirty tree makes
# --ff-only fail loudly instead of silently rewriting something).
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only
else
  git clone "$REPO" "$DIR"
fi

exec "$DIR/install.sh" "$@"
