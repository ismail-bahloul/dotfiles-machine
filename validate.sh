#!/bin/bash
# validate.sh — check that all dotfiles components are correctly deployed
set -e

# ─── Locate repo + load logging library from the local clone ─────────────────
REPO_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# Same contract as install.sh: validate.sh runs from the clone, so the library
# is always there and no fallback copy is needed.
if [ ! -f "$REPO_SCRIPT_DIR/lib/logging.sh" ]; then
  echo "validate: lib/logging.sh is missing — run this from the repository clone." >&2
  exit 1
fi
# shellcheck source=lib/logging.sh
source "$REPO_SCRIPT_DIR/lib/logging.sh"

log_init
SCRIPT_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"

# ─── Scripts in PATH ────────────────────────────────────────────────────────
log_section "Scripts"

for s in limine-boot-win limine-boot-vfio limine-boot-linux backup-data omenctl omenctl-tui; do
  if command -v "$s" &>/dev/null || [ -f "$HOME/.local/bin/$s" ]; then
    log_pass "$s"
  else
    log_fail "$s not found"
  fi
done

# ─── Packages ───────────────────────────────────────────────────────────────
# The expected set is base + the enabled components, read from the same chezmoi
# data run_once_01 renders. "chezmoi data" exposes the user data at the top
# level of its JSON (the under-key form is the template's "."-context), so the
# paths here are `.components` / `.wine`, not `.data.components`. Fall back to
# every component in packages.d/ when chezmoi is unavailable (bare clone,
# partial machine).
log_section "Packages"

components=()
data_json=$(chezmoi data --format json 2>/dev/null || true)
if [ -n "$data_json" ] && printf '%s' "$data_json" | jq -e 'has("components")' >/dev/null 2>&1; then
  mapfile -t components < <(
    printf '%s' "$data_json" | jq -r '.components[]?' | awk '$0 != "base" && !seen[$0]++'
  )
  components=(base "${components[@]}")
else
  # No `components` key: same fallback as run_once_01, i.e. every known
  # component except wine (opt-in only).
  components=(base)
  for f in "$SCRIPT_DIR"/packages.d/*.pacman; do
    comp=$(basename "$f" .pacman)
    if [ "$comp" != "base" ] && [ "$comp" != "wine" ]; then components+=("$comp"); fi
  done
fi
# The legacy switch applies to both paths.
if [ -n "$data_json" ] && printf '%s' "$data_json" | jq -e '.wine == true' >/dev/null 2>&1; then
  components+=(wine)
fi

component_enabled() {
  local want="$1" c
  for c in "${components[@]}"; do
    [ "$c" = "$want" ] && return 0
  done
  return 1
}

# Which component owns an etc/ file? Read it from the script whose etc-hash
# lists the path, so the mapping lives in exactly one place (the script).
etc_owner() {
  local rel="$1" f
  for f in "$SCRIPT_DIR"/.chezmoiscripts/run_*; do
    grep -qF "\"$rel\"" "$f" 2>/dev/null || continue
    sed -n 's/.*component-guard" (dict "name" "\([^"]*\)".*/\1/p' "$f" | head -1
    return 0
  done
}

for comp in "${components[@]}"; do
  missing=()
  for ext in pacman aur; do
    f="$SCRIPT_DIR/packages.d/$comp.$ext"
    [ -f "$f" ] || continue
    while IFS= read -r pkg; do
      [ -z "$pkg" ] && continue
      if ! pacman -Q "$pkg" &>/dev/null; then missing+=("$pkg ($ext)"); fi
    done < <(grep -v '^\s*#' "$f" | awk 'NF {print $1}')
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    log_pass "$comp"
  else
    log_fail "$comp: missing ${missing[*]}"
  fi
done

# ─── Services ───────────────────────────────────────────────────────────────
log_section "Services"

# omenctl owns the fans; the profile units are a oneshot, its timer and the
# drift watcher. Check the daemon is running and the profile stack is enabled.
if systemctl is-active omenctl.service &>/dev/null; then
  log_pass "omenctl.service active (fan governor)"
else
  log_fail "omenctl.service not active"
fi
if systemctl is-enabled omenctl.service &>/dev/null; then
  log_pass "omenctl.service enabled"
else
  log_fail "omenctl.service not enabled"
fi
if systemctl is-enabled omenctl-profile.service &>/dev/null; then
  log_pass "omenctl-profile.service enabled"
else
  log_fail "omenctl-profile.service not enabled"
fi
if systemctl is-active omenctl-profile.timer &>/dev/null; then
  log_pass "omenctl-profile.timer active"
else
  log_fail "omenctl-profile.timer not active"
fi
if systemctl is-active omenctl-watch.service &>/dev/null; then
  log_pass "omenctl-watch.service active"
else
  log_fail "omenctl-watch.service not active"
fi
# A stale legacy unit would fight omenctl for the CPU limits.
if [ ! -e /etc/systemd/system/power-profile.service ] && [ ! -e /usr/local/bin/power-profile ]; then
  log_pass "legacy power-profile removed"
else
  log_warn "legacy power-profile still present"
fi
for svc in nvidia-powerd.service nvidia-suspend.service nvidia-resume.service; do
  if systemctl is-enabled "$svc" &>/dev/null; then
    log_pass "$svc enabled"
  else
    log_pass "$svc skipped (no NVIDIA)"
  fi
done
if component_enabled virtualization; then
  for svc in virtqemud.socket virtnetworkd.socket; do
    if systemctl is-active "$svc" &>/dev/null; then
      log_pass "$svc active"
    else
      log_fail "$svc not active"
    fi
  done
else
  log_skip "libvirt sockets (virtualization disabled)"
fi

# ─── System files (etc/) ────────────────────────────────────────────────────
# Every file versioned under etc/ must be installed at the same path, unchanged.
log_section "System files"

while IFS= read -r rel; do
  owner=$(etc_owner "$rel")
  if [ -n "$owner" ] && ! component_enabled "$owner"; then
    # The script that installs this file is gated on a disabled component, so
    # the file is expected to be absent (teardown) - not a failure either way,
    # but a leftover means the teardown did not run.
    if [ -f "/$rel" ]; then
      log_warn "/$rel still present although '$owner' is disabled (teardown not run?)"
    else
      log_skip "/$rel torn down ('$owner' disabled)"
    fi
    continue
  fi
  if [ ! -f "/$rel" ]; then
    log_fail "/$rel missing (run_once script not applied?)"
  elif cmp -s "$SCRIPT_DIR/$rel" "/$rel"; then
    log_pass "/$rel"
  else
    log_fail "/$rel differs from the repo copy"
  fi
done < <(cd "$SCRIPT_DIR" && find etc -type f | sort)

# ─── VFIO ───────────────────────────────────────────────────────────────────
log_section "VFIO"

if component_enabled virtualization; then
  if grep -q "vfio" /etc/mkinitcpio.conf 2>/dev/null; then
    log_pass "VFIO modules in mkinitcpio"
  else
    log_fail "VFIO modules missing"
  fi
  if [ ! -f /etc/cmdline.d/vfio.conf ]; then
    log_pass "VFIO cmdline via Limine entry (no /etc/cmdline.d)"
  else
    log_fail "Stale /etc/cmdline.d/vfio.conf present - ids should live in the Limine VFIO entry only"
  fi
else
  log_skip "VFIO (virtualization disabled)"
fi

# ─── Power profile ──────────────────────────────────────────────────────────
log_section "Power profile"

if command -v omenctl &>/dev/null; then
  log_pass "omenctl installed"
  GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
  if [ -n "$GOV" ]; then
    log_pass "CPU governor: $GOV"
  else
    log_fail "CPU governor unknown"
  fi
  DRV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null)
  if [ "$DRV" = "amd-pstate-epp" ]; then
    log_pass "cpufreq driver: $DRV"
  else
    log_warn "cpufreq driver: ${DRV:-unknown} (expected amd-pstate-epp; the EPP writes in omenctl need it)"
  fi
else
  log_fail "omenctl not installed"
fi

# ─── Boot tuning ────────────────────────────────────────────────────────────
log_section "Boot tuning"

if [ -f /etc/initcpio/install/no-nouveau ]; then
  log_pass "no-nouveau hook installed"
else
  log_fail "no-nouveau hook missing"
fi
if [ -f /etc/mkinitcpio.conf.d/20-no-nouveau.conf ]; then
  log_pass "no-nouveau hook registered"
else
  log_fail "no-nouveau hook not registered"
fi
if grep -qE '^[[:space:]]*MODULES\+=\(.*nvidia' /etc/mkinitcpio.conf.d/10-chwd.conf 2>/dev/null; then
  log_fail "NVIDIA modules are back in the initramfs (chwd regenerated its config)"
else
  log_pass "NVIDIA modules excluded from the initramfs"
fi
if grep -qE '^[[:space:]]*MODULES\+=.*amdgpu' /etc/mkinitcpio.conf.d/30-amdgpu-early.conf 2>/dev/null; then
  log_pass "amdgpu early KMS configured"
else
  log_fail "amdgpu early KMS drop-in missing (/etc/mkinitcpio.conf.d/30-amdgpu-early.conf)"
fi
if [ "$(systemctl is-enabled systemd-binfmt.service 2>/dev/null)" = "masked" ]; then
  log_pass "systemd-binfmt masked (on-demand automount)"
else
  log_warn "systemd-binfmt not masked"
fi
SNAP_MAX=$(grep -E '^MAX_SNAPSHOT_ENTRIES=' /etc/limine-snapper-sync.conf 2>/dev/null | cut -d= -f2)
if [ "$SNAP_MAX" = "8" ]; then
  log_pass "MAX_SNAPSHOT_ENTRIES=8"
else
  log_warn "MAX_SNAPSHOT_ENTRIES=${SNAP_MAX:-unset} (expected 8)"
fi

# The systemd-user-sessions override is a full copy of the vendor unit, because
# an empty After= in a drop-in does not reset the list (systemd 262). Its only
# intended delta is dropping network.target, so anything else that differs means
# the copy went stale behind a systemd update: report it instead of keeping a
# silently outdated unit.
VENDOR_UNIT=/usr/lib/systemd/system/systemd-user-sessions.service
OVERRIDE_UNIT="$SCRIPT_DIR/etc/systemd/system/systemd-user-sessions.service"
if [ ! -f "$VENDOR_UNIT" ]; then
  log_skip "vendor systemd-user-sessions.service not found"
elif [ ! -f "$OVERRIDE_UNIT" ]; then
  log_fail "systemd-user-sessions override missing"
else
  sort_words() { tr ' ' '\n' | sed '/^[[:space:]]*$/d' | sort; }
  unit_body() {
    grep -v '^[[:space:]]*#' "$1" |
      sed '/^[[:space:]]*$/d; s/[[:space:]]*$//; s/^After=.*/After=<checked below>/'
  }
  vendor_after=$(sed -n 's/^After=//p' "$VENDOR_UNIT" | sort_words)
  expected_after=$(printf '%s\n' "$vendor_after" | grep -vx 'network.target' || true)
  ours_after=$(sed -n 's/^After=//p' "$OVERRIDE_UNIT" | sort_words)
  if [ "$ours_after" != "$expected_after" ]; then
    log_fail "systemd-user-sessions After= is not 'vendor minus network.target'"
    log_detail "got:      $(printf '%s' "$ours_after" | tr '\n' ' ')"
    log_detail "expected: $(printf '%s' "$expected_after" | tr '\n' ' ')"
  elif diff -q <(unit_body "$VENDOR_UNIT") <(unit_body "$OVERRIDE_UNIT") >/dev/null; then
    log_pass "systemd-user-sessions override matches the vendor unit (minus network.target)"
  else
    log_fail "systemd-user-sessions override drifted from the vendor unit outside After=:"
    diff -u <(unit_body "$VENDOR_UNIT") <(unit_body "$OVERRIDE_UNIT") | sed -n '3,20p' | sed 's/^/    /' || true
  fi
fi

# ─── Sysctl ─────────────────────────────────────────────────────────────────
log_section "Sysctl"

# Nothing here sets swappiness: sysctl.d says 100, bpftune raises it at runtime
# when zram is present. Report the live value rather than assert one.
if lsblk | grep -q zram; then
  log_pass "Zram active, swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null) (bpftune-managed)"
else
  log_warn "No zram swap active"
fi

# ─── Looking Glass ──────────────────────────────────────────────────────────
log_section "Looking Glass"

if component_enabled looking_glass; then
  LG=/dev/shm/looking-glass
  if [ -f "$LG" ]; then
    SIZE=$(du -h "$LG" | awk '{print $1}')
    log_pass "Shared memory ($SIZE)"
  else
    log_fail "Shared memory not found"
  fi
  HP=$(cat /proc/sys/vm/nr_hugepages 2>/dev/null)
  if [ "$HP" -ge 64 ] 2>/dev/null; then
    log_pass "Hugepages: $HP"
  else
    log_fail "Hugepages: $HP (expected 64+)"
  fi
else
  log_skip "Looking Glass (looking_glass disabled)"
fi

# ─── KDE config ─────────────────────────────────────────────────────────────
log_section "KDE config"

for f in kglobalshortcutsrc kwinrc kwinrulesrc konsolerc dolphinrc; do
  if [ -f "$HOME/.config/$f" ]; then
    log_pass "$f"
  else
    log_fail "$f missing"
  fi
done

# ─── KDE widgets ────────────────────────────────────────────────────────────
# The widgets are fetched at a pinned commit by run_onchange_13-plasmoids.sh, so
# presence alone is not enough: the installed ref must be the pinned one. A
# missing stamp means the copy predates the pinned fetch (a warning, not a
# failure: re-applying fixes it).
log_section "KDE widgets"

PLASMOID_SCRIPT="$SCRIPT_DIR/.chezmoiscripts/run_onchange_13-plasmoids.sh"
plasmoid_check() { # id expected-ref
  local id="$1" want="$2" stamp="$HOME/.cache/plasmoids/$1.ref"
  if [ ! -d "$HOME/.local/share/plasma/plasmoids/$id" ]; then
    log_fail "$id missing"
  elif [ ! -f "$stamp" ]; then
    log_warn "$id predates the pinned fetch — re-apply to update it"
  elif [ "$(cat "$stamp")" = "$want" ]; then
    log_pass "$id at $want"
  else
    log_fail "$id at $(cat "$stamp"), expected $want"
  fi
}

if [ -f "$PLASMOID_SCRIPT" ]; then
  plasmoid_check com.github.mazen.salatprayertime "$(sed -n 's/^SALAT_REF=//p' "$PLASMOID_SCRIPT")"
  plasmoid_check org.kde.olib.thermalmonitor "$(sed -n 's/^THERMAL_REF=//p' "$PLASMOID_SCRIPT")"
else
  log_warn "run_onchange_13-plasmoids.sh not found — widget refs unchecked"
fi

# ─── omenctl fans ───────────────────────────────────────────────────────────
log_section "omenctl fans"

if [ -f /var/lib/omenctl/mode ]; then
  log_pass "stored mode: $(cat /var/lib/omenctl/mode)"
else
  log_warn "no stored omenctl mode (/var/lib/omenctl/mode)"
fi

# ─── ZSH ────────────────────────────────────────────────────────────────────
log_section "ZSH"

if grep -q "local/bin" "$HOME/.zshrc" 2>/dev/null; then
  log_pass "local/bin in PATH"
else
  log_fail "local/bin not in PATH"
fi

# ─── Secrets ────────────────────────────────────────────────────────────────
log_section "Secrets"

if [ -f "$HOME/.config/zsh/secrets" ]; then
  log_pass "Secrets file exists"
  PERMS=$(stat -c %a "$HOME/.config/zsh/secrets")
  if [ "$PERMS" = "600" ]; then
    log_pass "Secrets permissions 600"
  else
    log_fail "Secrets permissions $PERMS (should be 600)"
  fi
else
  log_pass "No secrets file (add one if needed)"
fi

# ─── Git ────────────────────────────────────────────────────────────────────
log_section "Git"

if cd "$SCRIPT_DIR" 2>/dev/null && git remote -v 2>/dev/null | grep -q "ismail-bahloul/dotfiles"; then
  log_pass "Dotfiles remote OK"
else
  log_fail "Dotfiles remote not found"
fi

# ─── Summary ────────────────────────────────────────────────────────────────
# Warn-only runs still count as success: warnings are "look at this", not "this
# is broken". Failures must reach the caller through the exit status.
log_summary
[ "$LOG_ERR" -eq 0 ] || exit 1
