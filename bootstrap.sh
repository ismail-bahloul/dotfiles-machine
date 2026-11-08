#!/bin/bash
# =============================================================================
# bootstrap.sh — the userspace entry point (any Linux distribution)
#
#   curl -fsSL https://ismailbahloul.com/d | bash
#
# Clones or updates this repository, installs chezmoi if needed, and applies
# ONLY the portable layer (portable/): ~/.zshrc, ~/.config/{kitty,btop,gh} and
# ~/.gitconfig. No root beyond the chezmoi package, no system file, no package
# list, no hardware.
#
# The machine layer — drivers, KDE, VFIO, audio, initramfs, udev — is the other
# entry point: https://ismailbahloul.com/m
#
# Deliberately self-contained: this file is piped before anything is cloned, so
# it cannot source lib/ and duplicates the two variables it needs.
# =============================================================================
set -euo pipefail

REPO="${DOTFILES_REPO:-https://github.com/ismail-bahloul/dotfiles.git}"
DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
SRC="$DIR/portable"

DRY_RUN=false
FORCE=false

usage() {
  cat <<'EOF'
usage: bootstrap.sh [--dry-run] [--force]

  --dry-run  show the plan, change nothing
  --force    overwrite configs that already exist; also allowed on a host
             provisioned by the machine layer
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --force)   FORCE=true ;;
    -h | --help) usage; exit 0 ;;
    *)
      echo "bootstrap: unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

say() { printf '%s\n' "$*"; }

# Run a command as root, unless already root (containers, CI).
as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

# --- Detect the machine layer ------------------------------------------------
# A provisioned host already gets these files, applied by install.sh from
# ~/.local/share/chezmoi/portable. Running this entry point there would apply a
# second, possibly older copy from ~/dotfiles.
provisioned=false
if [ -f "$HOME/.local/share/chezmoi/packages.d/base.pacman" ] ||
   [ -f /etc/udev/rules.d/99-omenctl.rules ]; then
  provisioned=true
fi

# --- Dependencies ------------------------------------------------------------
missing=()
command -v git >/dev/null 2>&1 || missing+=("git")
command -v chezmoi >/dev/null 2>&1 || missing+=("chezmoi")

if [ "$DRY_RUN" = true ]; then
  say "bootstrap: dry run — nothing will be changed"
  say "  repo:    $REPO"
  say "  clone:   $DIR"
  say "  source:  $SRC"
  say "  missing: ${missing[*]:-none}"
  if [ "$provisioned" = true ] && [ "$FORCE" = false ]; then
    say "  guard:   host provisioned by the machine layer — a real run would refuse (--force overrides)"
  fi
  exit 0
fi

if [ "$provisioned" = true ] && [ "$FORCE" = false ]; then
  cat >&2 <<'EOF'
bootstrap: this host is provisioned by the machine layer, which applies the
  userspace files too (from ~/.local/share/chezmoi/portable). Update through it:

      ~/dotfiles/install.sh

  To apply portable/ from this clone anyway: re-run with --force.
EOF
  exit 1
fi

install_pkg() {
  if command -v pacman >/dev/null 2>&1; then
    as_root pacman -S --needed --noconfirm "$1"
  elif command -v apt-get >/dev/null 2>&1; then
    as_root apt-get update -qq && as_root apt-get install -y "$1"
  elif command -v dnf >/dev/null 2>&1; then
    as_root dnf install -y "$1"
  elif command -v zypper >/dev/null 2>&1; then
    as_root zypper --non-interactive install "$1"
  elif command -v apk >/dev/null 2>&1; then
    as_root apk add "$1"
  else
    return 1
  fi
}

if [ "${#missing[@]}" -gt 0 ]; then
  say "bootstrap: installing ${missing[*]}..."
  for pkg in "${missing[@]}"; do
    install_pkg "$pkg" || {
      echo "bootstrap: cannot install '$pkg' automatically — install it, then re-run." >&2
      exit 1
    }
  done
fi
command -v chezmoi >/dev/null 2>&1 ||
  { echo "bootstrap: chezmoi is still missing after install." >&2; exit 1; }

# --- Clone or update ---------------------------------------------------------
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only
else
  git clone "$REPO" "$DIR"
fi

# --- Pre-flight: do not silently overwrite somebody's configs ----------------
# `chezmoi status` marks an existing, differing target with " M". Only those
# entries mean a file already on this machine would be replaced; on a fresh
# account there are none, so the canonical `curl | bash` still applies without
# asking — and it has to, since stdin is the script itself, not a TTY.
drift=$(chezmoi --source "$SRC" status 2>/dev/null || true)
clobber=$(printf '%s\n' "$drift" | grep -E '^ M' || true)
if [ -n "$clobber" ] && [ "$FORCE" = false ]; then
  cat >&2 <<'EOF'
bootstrap: these files already exist and would be overwritten:

EOF
  printf '%s\n' "$clobber" | sed 's/^ M /      /' >&2
  cat >&2 <<'EOF'

  Nothing has been changed. Re-run with --force to replace them, or preview
  the difference first:

      chezmoi --source ~/dotfiles/portable diff
EOF
  exit 1
fi

# --- Apply -------------------------------------------------------------------
chezmoi --source "$SRC" apply

pending=$(chezmoi --source "$SRC" status 2>/dev/null || true)
if [ -n "$pending" ]; then
  echo "bootstrap: the apply did not converge, still pending:" >&2
  printf '%s\n' "$pending" | sed 's/^/  /' >&2
  exit 1
fi
say "bootstrap: portable dotfiles applied (open a new shell to pick up .zshrc)"

# Only where the machine layer can actually be installed.
if command -v pacman >/dev/null 2>&1; then
  cat <<'EOF'

This is the userspace layer only. For the full machine (drivers, KDE, VFIO,
audio, initramfs, udev) on CachyOS/Arch:

    curl -fsSL https://ismailbahloul.com/m | bash
EOF
fi
