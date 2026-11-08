#!/bin/bash
# =============================================================================
# install.sh — bootstrap dotfiles
# Usage: git clone git@github.com:ismail-bahloul/dotfiles.git ~/dotfiles
#        ~/dotfiles/install.sh         # fresh install (or update if already installed)
#        ./install.sh --dry-run        # check prerequisites only, no install
#        ./install.sh --validate       # force validation even on update
# =============================================================================
set -e

# ─── Repo + script location ─────────────────────────────────────────────────
# HTTPS so that no SSH key has to be registered before bootstrapping. Swap in the
# SSH URL (git@github.com:ismail-bahloul/dotfiles.git) if you prefer.
REPO_URL="https://github.com/ismail-bahloul/dotfiles.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# ─── Cleanup on exit ────────────────────────────────────────────────────────
# The sudo keepalive (further down) runs in the background: we kill it on exit
# no matter what happens (error, set -e, Ctrl-C), otherwise it leaks and keeps
# the sudo timestamp alive.
KEEPER=""
cleanup() {
  if [ -n "$KEEPER" ]; then kill "$KEEPER" 2>/dev/null || true; fi
}
trap cleanup EXIT

# ─── Load logging library (local clone, else fall back) ─────────────────────
if [ -f "$SCRIPT_DIR/lib/logging.sh" ]; then
  # shellcheck source=lib/logging.sh
  source "$SCRIPT_DIR/lib/logging.sh"
else
  # Fallback: minimal logging (e.g. when piped from a URL)
  LOG_ERR=0 LOG_WARN=0 LOG_UNVALIDATED=0
  log_init() { :; }
  log_section() { echo ""; echo "─── $1 ───"; }
  log_pass() { echo "  ✔ $1"; }
  log_fail() { LOG_ERR=$((LOG_ERR + 1)); echo "  ✘ $1"; }
  log_fatal() { echo "  ✘ $1"; exit 1; }
  log_warn() { LOG_WARN=$((LOG_WARN + 1)); echo "  ! $1"; }
  log_info() { echo "  → $1"; }
  log_skip() { echo "  ⋯ $1"; }
  log_detail() { echo "    • $1"; }
  log_cmd() { echo "  $ $1"; }
  log_summary() { :; }
fi

# ─── Parse arguments ───────────────────────────────────────────────────────
DRY_RUN=false
FORCE_VALIDATE=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --validate) FORCE_VALIDATE=true ;;
  esac
done

log_init 8

# ─── Prerequisites ─────────────────────────────────────────────────────────
log_section "Prerequisites"

if $DRY_RUN; then
  log_info "DRY RUN — checking prerequisites only"
fi

if [ ! -f /etc/arch-release ] && [ ! -f /etc/cachyos-release ]; then
  log_fatal "This is the machine layer (Arch Linux / CachyOS only) — for the portable dotfiles on any distro, use https://ismailbahloul.com/d"
fi
log_pass "Arch / CachyOS detected"

if [ "$(id -u)" = "0" ]; then
  log_fatal "Do not run as root. Run as a normal user with sudo access."
fi
log_pass "Not root"

if command -v curl >/dev/null 2>&1; then
  # curl (already required below): HTTP HEAD, no ICMP -> no false negative
  # if ICMP is filtered while the network/DNS works.
  if ! curl -fsI --max-time 10 https://archlinux.org >/dev/null 2>&1; then
    log_fatal "No internet connection"
  fi
elif command -v ping >/dev/null 2>&1; then
  if ! ping -c1 archlinux.org >/dev/null 2>&1; then
    log_fatal "No internet connection"
  fi
else
  log_warn "neither curl nor ping available — network check skipped"
fi
log_pass "Internet OK"

# Auto-detect: fresh install or update?
PARU_MISSING=false
CHEZMOI_MISSING=false
! command -v paru &>/dev/null && PARU_MISSING=true
! command -v chezmoi &>/dev/null && CHEZMOI_MISSING=true

if $PARU_MISSING || $CHEZMOI_MISSING; then
  INSTALL_TYPE="fresh"
  log_info "Fresh install detected"
else
  INSTALL_TYPE="update"
  log_info "Update mode (paru + chezmoi already installed)"
fi

if $DRY_RUN; then
  log_pass "All prerequisites OK. Run without --dry-run to install."
  exit 0
fi

# ─── Sudo keepalive ─────────────────────────────────────────────────────────
log_section "Sudo"

if [ "$INSTALL_TYPE" = "fresh" ]; then
  log_info "Sudo access required (enter password once)..."
  sudo -v
  (sudo -v && while true; do sleep 60; sudo -v; done) &>/dev/null &
  KEEPER=$!
  log_pass "Sudo OK"
else
  log_skip "Not needed (update mode)"
fi

# ─── paru ───────────────────────────────────────────────────────────────────
log_section "Package manager"

if $PARU_MISSING; then
  log_info "Installing paru..."
  sudo pacman -S --needed --noconfirm base-devel git
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
  (cd "$tmpdir/paru" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
  log_pass "paru installed"
else
  log_skip "paru already installed"
fi

# ─── chezmoi ────────────────────────────────────────────────────────────────
log_section "chezmoi"

if $CHEZMOI_MISSING; then
  log_info "Installing chezmoi..."
  sudo pacman -S --needed --noconfirm chezmoi
  log_pass "chezmoi installed"
else
  log_skip "chezmoi already installed"
fi

# Clear any stale lock
rm -f "$HOME/.local/share/chezmoi/.chezmoi.lock"

# ─── Apply dotfiles ─────────────────────────────────────────────────────────
log_section "Apply dotfiles"

log_info "Applying dotfiles from GitHub..."
APPLY_OK=true
if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
  if ! chezmoi update --apply; then
    log_warn "chezmoi update failed — fallback: chezmoi init --apply"
    chezmoi init --apply "$REPO_URL" || APPLY_OK=false
  fi
else
  chezmoi init --apply "$REPO_URL" || APPLY_OK=false
fi

# A failed apply used to kill the script right here (set -e), with no summary and
# nothing pointing at the cause — which is how a bootstrap ends up looking like it
# "just stopped". Report it instead, and let the summary carry the verdict.
if ! $APPLY_OK; then
  log_fail "applying the dotfiles failed — see the output above"
else
  # The apply has to converge: anything still differing means a target could not
  # be written (permissions, a failing run_onchange_ script, a broken template).
  # This is the one post-apply check that is meaningful in update mode — it tests
  # the transition, not the machine state — and it costs nothing.
  pending=$(chezmoi status)
  if [ -z "$pending" ]; then
    log_pass "Dotfiles applied"
  else
    log_fail "chezmoi apply did not converge, still pending:"
    printf '%s\n' "$pending" | sed 's/^/      /'
  fi
fi

# ─── Portable layer ────────────────────────────────────────
# The machine source owns no shared userspace file: ~/.zshrc, kitty.conf,
# ~/.gitconfig and the gh config come from portable/, a chezmoi source of its
# own. Applying it here keeps /m a single entry point, and keeps `chezmoi
# update` from silently skipping the userspace half.
log_section "Portable dotfiles"

PORTABLE_SOURCE="$HOME/.local/share/chezmoi/portable"
[ -d "$PORTABLE_SOURCE" ] || PORTABLE_SOURCE="$SCRIPT_DIR/portable"
if [ -d "$PORTABLE_SOURCE" ]; then
  # Expected here: portable/ has no .chezmoi.toml.tmpl, so chezmoi compares it
  # against the machine config, which differs by construction. Nothing to fix —
  # the convergence check below is what proves the apply.
  log_detail "chezmoi may warn that the config template changed — this source has none by design"
  if chezmoi --source "$PORTABLE_SOURCE" apply; then
    log_pass "Portable dotfiles applied"
  else
    log_fail "applying the portable layer failed"
  fi
else
  log_warn "portable/ not found in the source or the clone — userspace dotfiles skipped"
fi

# The sudo keepalive is killed by the EXIT trap (see top of the script).

# ─── Validation ─────────────────────────────────────────────────────────────
log_section "Validation"

if [ "$INSTALL_TYPE" = "fresh" ] || $FORCE_VALIDATE; then
  log_info "Running post-install validation..."
  if [ -f "$SCRIPT_DIR/validate.sh" ]; then
    # A failing validation must not abort the script (set -e): validate.sh has
    # already printed its ✘ lines, and the summary below still has to run.
    if ! bash "$SCRIPT_DIR/validate.sh"; then
      log_fail "validation reported failures (see above)"
    fi
  else
    log_warn "validate.sh not found next to install.sh — validation skipped"
  fi
else
  log_skip "Validation skipped (run with --validate to force)"
  log_info "Restart your session to apply all changes"
  # The apply itself was checked (chezmoi status) but the machine state was not:
  # the summary must say so instead of claiming that all checks passed.
  LOG_UNVALIDATED=1
fi

# ─── Summary ────────────────────────────────────────────────────────────────
log_summary

# The summary is not an exit status: a ✘ verdict has to reach the caller (CI,
# `install.sh && …`), otherwise a failed run looks successful.
[ "$LOG_ERR" -eq 0 ] || exit 1
