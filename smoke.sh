#!/bin/bash
# Offline smoke test of the entry points' control flow: install.sh, bootstrap.sh
# and bootstrap-machine.sh.
# No network, no sudo, no package manager: chezmoi/paru/sudo/pacman/git/curl are
# fakes on PATH, HOME is a throwaway, and the repo scripts are copied to a temp
# dir. The two modes mirror install.sh's own auto-detection:
#   update — paru + chezmoi already present, the source is initialised
#   fresh  — neither present, no source: it must install them, then init --apply
set -u

SRC=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

ok=0
ko=0

setup() {
  local d=$1 vrc=$2 mode=${3:-update}
  mkdir -p "$d/bin" "$d/repo/lib"
  cp "$SRC/install.sh" "$d/repo/"
  cp "$SRC/lib/logging.sh" "$d/repo/lib/"
  # install.sh applies the portable layer as its last step; without a copy it
  # would log a warning and change the expected summaries below.
  cp -r "$SRC/portable" "$d/repo/"
  printf '#!/bin/bash\necho "  v stub validate"\nexit %s\n' "$vrc" >"$d/repo/validate.sh"

  cat >"$d/chezmoi.stub" <<'EOF'
#!/bin/sh
case "$1" in
  update) exit "${FAKE_UPDATE_RC:-0}" ;;
  init)   exit "${FAKE_INIT_RC:-0}" ;;
  status) [ -n "${FAKE_STATUS:-}" ] && printf '%s\n' "$FAKE_STATUS"; exit 0 ;;
  *)      exit 0 ;;
esac
EOF
  chmod +x "$d/chezmoi.stub"

  # sudo must run its command (pacman, usermod…); only -v is a no-op.
  printf '#!/bin/sh\ncase "${1:-}" in -v) exit 0 ;; esac\nexec "$@"\n' >"$d/bin/sudo"
  printf '#!/bin/sh\nexit 0\n' >"$d/bin/curl"

  if [ "$mode" = update ]; then
    mkdir -p "$d/home/.local/share/chezmoi/.git"
    cp "$d/chezmoi.stub" "$d/bin/chezmoi"
    printf '#!/bin/sh\nexit 0\n' >"$d/bin/paru"
  else
    mkdir -p "$d/home" "$d/shadow"
    # The real paru and chezmoi are installed on the build machine, and the fresh
    # branch is detected with `command -v`: hide those two names, but keep the
    # rest of the system binaries reachable (id, seq, sed, mktemp…).
    for f in /usr/bin/* /usr/local/bin/*; do
      case "${f##*/}" in paru | chezmoi) continue ;; esac
      [ -e "$d/shadow/${f##*/}" ] || ln -s "$f" "$d/shadow/${f##*/}" 2>/dev/null || true
    done
    # "pacman -S chezmoi" makes chezmoi appear on PATH, as the real one would.
    printf '#!/bin/sh\ncp "%s/chezmoi.stub" "%s/bin/chezmoi" && chmod +x "%s/bin/chezmoi"\nexit 0\n' \
      "$d" "$d" "$d" >"$d/bin/pacman"
    printf '#!/bin/sh\nif [ "${1:-}" = clone ]; then mkdir -p "${3:-/nonexistent}"; fi\nexit 0\n' >"$d/bin/git"
    printf '#!/bin/sh\nexit 0\n' >"$d/bin/makepkg"
  fi

  chmod +x "$d/bin/"*
}

run_case() {
  local name=$1 want_rc=$2 want_pat=$3 vrc=$4 extra=$5 mode=${6:-update}
  local d="$WORK/$name" log rc clean path
  setup "$d" "$vrc" "$mode"
  log="$d/out.log"
  # `env` (not a PATH=… prefix) so that `bash` itself is resolved with the
  # caller's PATH before the restricted one takes over.
  if [ "$mode" = fresh ]; then path="$d/bin:$d/shadow"; else path="$d/bin:$PATH"; fi
  # Run from the sandbox, never from the repo: a command that takes a URL as a
  # path (mkdir, cp…) must not leave anything behind in the checkout.
  (cd "$d" && env HOME="$d/home" PATH="$path" bash "$d/repo/install.sh" $extra) >"$log" 2>&1
  rc=$?
  # Strip the colour spans first: a verdict is drawn in two spans ("✔ APPLIED"
  # then "— nothing validated"), so a literal match would never see it whole.
  clean=$(sed -e 's/\x1b\[[0-9;]*m//g' "$log")
  if [ "$rc" = "$want_rc" ] && printf '%s\n' "$clean" | grep -qF "$want_pat"; then
    ok=$((ok + 1))
    printf '  ok    %-22s exit=%s  %s\n' "$name" "$rc" "$want_pat"
  else
    ko=$((ko + 1))
    printf '  FAIL  %-22s exit=%s (want %s) — pattern: %s\n' "$name" "$rc" "$want_rc" "$want_pat"
    grep -aE "✘|!|✔|→|⋯" "$log" | sed 's/^/          /'
  fi
}

echo "install.sh — control flow (offline)"
FAKE_UPDATE_RC=0 FAKE_STATUS='' run_case update-ok 0 "✔ APPLIED — nothing validated" 0 ""
FAKE_UPDATE_RC=1 FAKE_INIT_RC=0 FAKE_STATUS='' run_case update-fail-fallback 0 "! PASSED WITH 1 WARNING(S)" 0 ""
FAKE_UPDATE_RC=0 FAKE_STATUS=" M .zshrc" run_case not-converged 1 "✘ 1 CHECK(S) FAILED" 0 ""
FAKE_UPDATE_RC=0 FAKE_STATUS='' run_case validate-fails 1 "✘ 1 CHECK(S) FAILED" 1 --validate
FAKE_UPDATE_RC=0 FAKE_STATUS='' run_case validate-passes 0 "✔ ALL CHECKS PASSED" 0 --validate
FAKE_UPDATE_RC=1 FAKE_INIT_RC=1 FAKE_STATUS='' run_case update-apply-fails 1 "✘ 1 CHECK(S) FAILED" 0 ""
FAKE_INIT_RC=0 run_case fresh-install 0 "✔ ALL CHECKS PASSED" 0 "" fresh
FAKE_INIT_RC=1 run_case fresh-apply-fails 1 "✘ 1 CHECK(S) FAILED" 0 "" fresh

# ─────────────────────────────────────────────────────────────────────────────
# bootstrap.sh / bootstrap-machine.sh — control flow (offline)
#
# Same contract as above: no network, no sudo, no package manager. Two absolute
# paths cannot be hidden from a test, so the cases that need them absent run from
# a patched copy: only those paths are rewritten, the HOME marker, the flags and
# the stubs stay real.
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "bootstraps — control flow (offline)"

bs_ok=0
bs_ko=0
BS_PATH=""

bs_stubs() { # $1 = bin dir
  mkdir -p "$1"
  cat >"$1/git" <<'STUB'
#!/bin/sh
[ "$1" = "clone" ] && mkdir -p "$3"
exit 0
STUB
  cat >"$1/sudo" <<'STUB'
#!/bin/sh
case "${1:-}" in -v) exit 0 ;; esac
exec "$@"
STUB
  cat >"$1/chezmoi-clean" <<'STUB'
#!/bin/sh
[ "$1" = "--source" ] && shift 2
case "$1" in
  apply) echo "FAKE: chezmoi apply" ;;
esac
exit 0
STUB
  cat >"$1/chezmoi-dirty" <<'STUB'
#!/bin/sh
[ "$1" = "--source" ] && shift 2
case "$1" in
  apply)  echo "FAKE: chezmoi apply" ;;
  status) echo " M .zshrc" ;;
esac
exit 0
STUB
  chmod +x "$1"/*
}

bs_pkgmgr() { # $1 = bin dir, $2 = manager name: "installs" chezmoi
  cat >"$1/$2" <<STUB
#!/bin/sh
cp "$1/chezmoi-clean" "$1/chezmoi"
chmod +x "$1/chezmoi"
exit 0
STUB
  chmod +x "$1/$2"
}

# A PATH whose /usr/bin holds neither the real package managers nor chezmoi: a
# stub must be the one the script finds, never the host's.
bs_shadow() { # $1 = shadow dir
  mkdir -p "$1"
  for f in /usr/bin/* /usr/local/bin/*; do
    case "${f##*/}" in pacman | apt-get | dnf | zypper | apk | chezmoi | git | sudo) continue ;; esac
    [ -e "$1/${f##*/}" ] || ln -s "$f" "$1/${f##*/}" 2>/dev/null || true
  done
}

bs_exec() { # dir name want_rc want_pat script [args...]
  local d="$WORK/bs-$1" name=$2 want_rc=$3 want_pat=$4; shift 4
  local log="$WORK/$name.log" rc
  (cd "$d" && env HOME="$d/home" PATH="$BS_PATH" DOTFILES_DIR="$d/repo" \
    bash "$@") >"$log" 2>&1
  rc=$?
  if [ "$rc" = "$want_rc" ] && grep -qF "$want_pat" "$log"; then
    bs_ok=$((bs_ok + 1))
    printf '  ok    %-26s exit=%s  %s\n' "$name" "$rc" "$want_pat"
  else
    bs_ko=$((bs_ko + 1))
    printf '  FAIL  %-26s exit=%s (want %s) — pattern: %s\n' "$name" "$rc" "$want_rc" "$want_pat"
    sed -n '1,10p' "$log" | sed 's/^/          /'
  fi
}

# Patched copies: neutralise only the absolute paths a test cannot hide.
sed 's|99-omenctl.rules|no-such-rule.rules|' "$SRC/bootstrap.sh" >"$WORK/bootstrap-noguard.sh"
sed 's|/etc/arch-release|/etc/no-arch-release|; s|/etc/cachyos-release|/etc/no-cachyos-release|' \
  "$SRC/bootstrap-machine.sh" >"$WORK/bootstrap-noarch.sh"
chmod +x "$WORK"/bootstrap-*.sh

# 1. a host the machine layer already provisioned is refused (HOME marker).
mkdir -p "$WORK/bs-guard/home/.local/share/chezmoi/packages.d" "$WORK/bs-guard/repo/.git"
touch "$WORK/bs-guard/home/.local/share/chezmoi/packages.d/base.pacman"
bs_stubs "$WORK/bs-guard/bin"
cp "$WORK/bs-guard/bin/chezmoi-clean" "$WORK/bs-guard/bin/chezmoi"
BS_PATH="$WORK/bs-guard/bin:/usr/bin:/bin"
bs_exec guard guard 1 "provisioned by the machine layer" "$WORK/bootstrap-noguard.sh"

# 2. --dry-run is read-only and does not trip the guard.
mkdir -p "$WORK/bs-dryrun/home" "$WORK/bs-dryrun/repo/.git"
bs_stubs "$WORK/bs-dryrun/bin"
cp "$WORK/bs-dryrun/bin/chezmoi-clean" "$WORK/bs-dryrun/bin/chezmoi"
BS_PATH="$WORK/bs-dryrun/bin:/usr/bin:/bin"
bs_exec dryrun dryrun 0 "dry run — nothing will be changed" "$WORK/bootstrap-noguard.sh" --dry-run

# 3. chezmoi missing: installed through pacman, then the layer is applied.
mkdir -p "$WORK/bs-pacman/home" "$WORK/bs-pacman/repo/.git"
bs_stubs "$WORK/bs-pacman/bin"
bs_pkgmgr "$WORK/bs-pacman/bin" pacman
bs_shadow "$WORK/bs-pacman/shadow"
BS_PATH="$WORK/bs-pacman/bin:$WORK/bs-pacman/shadow"
bs_exec pacman pacman-install 0 "portable dotfiles applied" "$WORK/bootstrap-noguard.sh"

# 4. same through apt-get, with no pacman on the PATH.
mkdir -p "$WORK/bs-apt/home" "$WORK/bs-apt/repo/.git"
bs_stubs "$WORK/bs-apt/bin"
bs_pkgmgr "$WORK/bs-apt/bin" apt-get
bs_shadow "$WORK/bs-apt/shadow"
BS_PATH="$WORK/bs-apt/bin:$WORK/bs-apt/shadow"
bs_exec apt apt-install 0 "portable dotfiles applied" "$WORK/bootstrap-noguard.sh"

# 5. an existing config is never overwritten without --force.
mkdir -p "$WORK/bs-clobber/home" "$WORK/bs-clobber/repo/.git"
bs_stubs "$WORK/bs-clobber/bin"
cp "$WORK/bs-clobber/bin/chezmoi-dirty" "$WORK/bs-clobber/bin/chezmoi"
BS_PATH="$WORK/bs-clobber/bin:/usr/bin:/bin"
bs_exec clobber clobber 1 "would be overwritten" "$WORK/bootstrap-noguard.sh"

# 6. the machine entry point refuses a non-Arch host before cloning.
mkdir -p "$WORK/bs-noarch/home" "$WORK/bs-noarch/repo/.git"
bs_stubs "$WORK/bs-noarch/bin"
BS_PATH="$WORK/bs-noarch/bin:/usr/bin:/bin"
bs_exec noarch non-arch 1 "machine layer (CachyOS / Arch only)" "$WORK/bootstrap-noarch.sh"

# 7. ... and forwards its arguments to install.sh on Arch.
mkdir -p "$WORK/bs-machine/home" "$WORK/bs-machine/repo/.git"
bs_stubs "$WORK/bs-machine/bin"
printf '#!/bin/sh\necho "FAKE install.sh:" "$@"\n' >"$WORK/bs-machine/repo/install.sh"
chmod +x "$WORK/bs-machine/repo/install.sh"
BS_PATH="$WORK/bs-machine/bin:/usr/bin:/bin"
bs_exec machine machine-args 0 "FAKE install.sh: --dry-run" "$SRC/bootstrap-machine.sh" --dry-run

echo ""
echo "result: $ok install, $bs_ok bootstrap — $((ko + bs_ko)) failed"
[ "$ko" -eq 0 ] && [ "$bs_ko" -eq 0 ]
