#!/bin/bash
# Offline smoke test of install.sh's control flow.
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

echo ""
echo "result: $ok ok, $ko failed"
[ "$ko" -eq 0 ]
