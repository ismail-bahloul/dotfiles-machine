#!/bin/bash
# test.sh — repo-side lint, run by hand before pushing.
#
# Complements validate.sh: this one checks *the repo* (the source tree has the
# expected files, shell syntax is valid, JSON parses, no untracked leftovers);
# validate.sh checks *the machine* (is everything actually deployed and running).
# Nothing calls this automatically.
set -e

# ─── Load logging library ──────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# The lib ships with the repo, so it is always present here.
source "$SCRIPT_DIR/lib/logging.sh"

cd "$SCRIPT_DIR"
log_init

# ─── Repo ───────────────────────────────────────────────────────────────────
log_section "Repo"

if git rev-parse --git-dir &>/dev/null; then
  log_pass "Git repo"
  if git diff --quiet HEAD 2>/dev/null; then
    log_pass "No uncommitted changes"
  else
    log_warn "Uncommitted changes"
  fi
else
  log_fail "Not a git repo"
fi

# ─── Files ──────────────────────────────────────────────────────────────────
log_section "Files"

for f in install.sh validate.sh .chezmoiscripts/run_once_*.sh* .chezmoiscripts/run_onchange_*.sh* dot_local/bin/*; do
  if [ -f "$f" ]; then
    log_pass "$f"
  else
    log_fail "$f missing"
  fi
done

# ─── Cleanliness ────────────────────────────────────────────────────────────
log_section "Cleanliness"

git ls-files --others --exclude-standard 2>/dev/null | while IFS= read -r f; do
  log_warn "Untracked file: $f"
done

# ─── Contract: every etc/ file is covered by an etc-hash ─────────────────────
# chezmoi re-runs a script only when the script itself changes. The etc-hash
# line in a .tmpl stands in for the installed files, so a file under etc/ that
# is not listed there is never redeployed after an edit.
log_section "etc/ coverage"

while IFS= read -r -d '' f; do
  if grep -qhF "\"$f\"" .chezmoiscripts/run_* 2>/dev/null; then
    log_pass "$f"
  else
    log_fail "$f is not listed in any etc-hash (never redeployed)"
  fi
done < <(find etc -type f -print0 | sort -z)

for f in .chezmoiscripts/run_*.tmpl; do
  [ -f "$f" ] || continue
  if grep -q "install_system_file" "$f" && ! grep -q "^# etc-hash:" "$f"; then
    log_fail "$f installs etc/ files but carries no etc-hash line"
  else
    log_pass "$f"
  fi
done

# ─── Contract: scripts ↔ README ──────────────────────────────────────────────
# The README is the map of the repo. A script missing from it, or a script it
# mentions that no longer exists, is documentation drift.
log_section "Scripts documented"

for f in .chezmoiscripts/run_*.sh*; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  if grep -qF "$base" README.md; then
    log_pass "$base documented"
  else
    log_fail "$base is not mentioned in README.md"
  fi
done

while IFS= read -r r; do
  if [ -f ".chezmoiscripts/$r" ]; then
    log_pass "README mentions $r"
  else
    log_fail "README mentions $r, but .chezmoiscripts/$r does not exist"
  fi
done < <(grep -oE 'run_(once|onchange)_[0-9]+-[A-Za-z0-9._-]+\.sh(\.tmpl)?' README.md | sort -u)

# ─── Package registry ────────────────────────────────────────────────────────
# One <component>.pacman per component is the rule (it may hold no package when
# the component's packages are installed by its own script); .aur is optional.
log_section "Package registry"

for f in packages.d/*.pacman; do
  dups=$(grep -v '^[[:space:]]*#' "$f" | awk 'NF {print $1}' | sort | uniq -d)
  if [ -z "$dups" ]; then
    log_pass "$f: no duplicate entry"
  else
    log_fail "$f: duplicate entry: $(printf '%s ' $dups)"
  fi
done
for f in packages.d/*.aur; do
  dups=$(grep -v '^[[:space:]]*#' "$f" | awk 'NF {print $1}' | sort | uniq -d)
  if [ -z "$dups" ]; then
    log_pass "$f: no duplicate entry"
  else
    log_fail "$f: duplicate entry: $(printf '%s ' $dups)"
  fi
done

# ─── Contract: package lists re-trigger run_once_01 ──────────────────────────
# chezmoi re-runs a run_once_ script only when its rendered content changes, and
# run_once_01 reads packages.d/ at runtime. Its pkg-hash line stands in for those
# files: without it, editing a package list never re-runs the script, so a newly
# added package would silently never reach an existing machine.
log_section "Package hash coverage"

pkg_script=.chezmoiscripts/run_once_01-packages.sh.tmpl
if ! grep -q "^# pkg-hash:" "$pkg_script"; then
  log_fail "$pkg_script has no pkg-hash line (packages.d edits never re-run it)"
else
  log_pass "$pkg_script carries a pkg-hash line"
  expected=$(find packages.d -maxdepth 1 -type f | wc -l)
  # The hashes are concatenated without separators: 8 hex chars per list.
  got=$(chezmoi -S "$PWD" execute-template < "$pkg_script" \
    | sed -n 's/^# pkg-hash: //p' | awk '{ print length($0) / 8 }' || true)
  if [ "$got" = "$expected" ]; then
    log_pass "pkg-hash covers all $expected packages.d lists"
  else
    log_fail "pkg-hash covers $got/$expected packages.d lists (a list is unhashed)"
  fi
fi

# A component nobody can discover is a component that does not exist.
log_section "Components documented"

for f in packages.d/*.pacman; do
  comp=$(basename "$f" .pacman)
  if grep -qF "\`$comp\`" README.md; then
    log_pass "$comp documented"
  else
    log_fail "$comp is not documented in README.md"
  fi
done

# ─── Bricks: opt-in bundles, outside the component registry ─────────────────
# A brick is a pair of <name>.pacman/.aur lists installed on demand by
# bricks/install. It must stay discoverable (documented) and clean (no dupes).
log_section "Bricks"

for f in bricks/*.pacman bricks/*.aur; do
  [ -f "$f" ] || continue
  dups=$(grep -v '^[[:space:]]*#' "$f" | awk 'NF {print $1}' | sort | uniq -d)
  if [ -z "$dups" ]; then
    log_pass "$f: no duplicate entry"
  else
    log_fail "$f: duplicate entry: $(printf '%s ' $dups)"
  fi
done

for f in bricks/*.pacman; do
  brick=$(basename "$f" .pacman)
  if grep -qF "\`$brick\`" bricks/README.md; then
    log_pass "$brick documented"
  else
    log_fail "$brick is not documented in bricks/README.md"
  fi
done

if [ -x bricks/install ] && bash -n bricks/install; then
  log_pass "bricks/install"
else
  log_fail "bricks/install is missing, not executable, or invalid"
fi

# ─── Contract: optional scripts are gated on their component ────────────────
# The components switch must gate *behaviour*, not only packages. Each script
# below belongs to a component and must call the shared component-guard
# template with that component's name, so disabling the component turns the
# script into a no-op instead of silently configuring the machine.
log_section "Component gating"

while read -r script comp; do
  [ -n "$script" ] || continue
  f=".chezmoiscripts/$script"
  if [ ! -f "$f" ]; then
    log_fail "$script missing (declared as gated on '$comp')"
  elif ! grep -q '"component-guard"' "$f"; then
    log_fail "$script does not use component-guard (runs even when '$comp' is off)"
  elif ! grep -q "component-guard\" (dict \"name\" \"$comp\"" "$f"; then
    log_fail "$script guards a component other than '$comp'"
  elif [ ! -f "packages.d/$comp.pacman" ] && [ ! -f "packages.d/$comp.aur" ]; then
    log_fail "$script guards on '$comp', which is not in packages.d/"
  else
    log_pass "$script gated on '$comp'"
    # Render both states. The disabled branch never runs on this machine, so a
    # template error there (missingkey=error turns any bad key access into a
    # failure) would otherwise surface only when a component is turned off.
    cfg_off=$(mktemp --suffix=.toml)
    cfg_on=$(mktemp --suffix=.toml)
    printf '[data]\n    components = []\n' > "$cfg_off"
    printf '[data]\n    components = ["%s"]\n' "$comp" > "$cfg_on"
    if ( set -o pipefail; chezmoi --config "$cfg_off" -S "$PWD" execute-template < "$f" | bash -n ); then
      log_pass "$script renders with '$comp' disabled"
    else
      log_fail "$script fails to render with '$comp' disabled"
    fi
    if ( set -o pipefail; chezmoi --config "$cfg_on" -S "$PWD" execute-template < "$f" | bash -n ); then
      log_pass "$script renders with '$comp' enabled"
    else
      log_fail "$script fails to render with '$comp' enabled"
    fi
    rm -f "$cfg_off" "$cfg_on"
  fi
done <<'EOF'
run_once_02-wine-staging.sh.tmpl     wine
run_once_05-vfio-setup.sh.tmpl       virtualization
run_once_06-libvirt-setup.sh.tmpl    virtualization
run_onchange_07-looking-glass.sh.tmpl looking_glass
run_onchange_12-peripherals.sh.tmpl  peripherals
EOF

# ─── Contract: top-level entries are deployed or explicitly ignored ──────────
log_section "chezmoi scope"

for entry in * .[!.]*; do
  case "$entry" in
    dot_*|.git|.gitattributes|.gitignore|.chezmoi*) continue ;;
  esac
  [ -e "$entry" ] || continue
  if grep -qxF "$entry" .chezmoiignore; then
    log_pass "$entry ignored"
  else
    log_fail "$entry is neither a dot_ target nor listed in .chezmoiignore"
  fi
done

# ─── Shell syntax ───────────────────────────────────────────────────────────
log_section "Shell syntax"

for f in install.sh validate.sh smoke.sh bootstrap-machine.sh .chezmoiscripts/run_once_*.sh* .chezmoiscripts/run_onchange_*.sh*; do
  # .tmpl scripts carry a chezmoi hash line: render them before the syntax check
  case "$f" in
    *.tmpl) check() { ( set -o pipefail; chezmoi -S "$PWD" execute-template < "$f" | bash -n ); } ;;
    *)      check() { bash -n "$f"; } ;;
  esac
  if check; then
    log_pass "$f"
  else
    log_fail "$f syntax error"
  fi
done

for f in dot_local/bin/executable_limine-boot-* dot_local/bin/executable_omenctl-tui dot_local/bin/executable_backup-data; do
  base=$(basename "$f")
  if head -1 "$f" | grep -qE 'bash|sh'; then
    if bash -n "$f"; then
      log_pass "$base"
    else
      log_fail "$base syntax error"
    fi
  fi
done

# ─── JSON ───────────────────────────────────────────────────────────────────
log_section "JSON"

while IFS= read -r -d '' f; do
  if jq empty "$f" &>/dev/null; then
    log_pass "$f"
  else
    log_fail "$f invalid JSON"
  fi
done < <(find . -name "*.json" -not -path "./.git/*" -print0)

# ─── KDE config ─────────────────────────────────────────────────────────────
log_section "KDE config"

for f in dot_config/kwinrulesrc dot_config/kxkbrc; do
  base=$(basename "$f")
  if [ -f "$f" ]; then
    log_pass "$base"
  else
    log_fail "$base missing"
  fi
done

# ─── Summary ────────────────────────────────────────────────────────────────
log_summary
[ "$LOG_ERR" -eq 0 ] || exit 1
