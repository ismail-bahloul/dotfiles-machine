#!/bin/bash
# =============================================================================
# run_onchange_13-plasmoids.sh
# Run by chezmoi when this file changes. The pinned commits below are part of
# the content, so bumping one re-runs the install.
#
# The two KDE plasmoids are fetched from upstream instead of vendored here: the
# prayer-time widget ships a 2.7 MB adhan recording, and a copy in this repo is
# a fork that drifts silently (it already had: the vendored one predated the
# Turkish translations and the mosque icon).
#
# The two upstreams use different layouts (root vs package/), so the KPackage
# root is located by looking for metadata.json instead of assuming a path.
# A failed download is a warning, never a broken apply: the installed copy
# stays.
# =============================================================================
set -e

source "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/lib/logging.sh"

# Pinned releases. Commit SHAs, not tags: a tag can be moved, a commit cannot.
#   mazenmohamed203/salaatprayertime — GPL-3.0+ — v2.5.6 (2026-10-10)
#   olib/thermalmonitor             — MIT      — v0.2.7
SALAT_REF=v2.5.6
SALAT_SHA=90ddf71939e3d5fc203d0d262cb734bdebf2e899
THERMAL_REF=v0.2.7
THERMAL_SHA=d07702013d3748cb7412151a04115d18611aa0f3

PLASMOIDS="$HOME/.local/share/plasma/plasmoids"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/plasmoids"

WORKDIR=$(mktemp -d)
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# Nothing to do outside Plasma. The files are inert anyway, but creating them
# on a non-KDE host would only be noise.
if ! command -v plasmashell >/dev/null 2>&1 && ! command -v kpackagetool6 >/dev/null 2>&1; then
  log_skip "Plasma not installed — plasmoids skipped"
  exit 0
fi

install_plasmoid() {
  local id="$1" url="$2" ref="$3"
  local target="$PLASMOIDS/$id"
  local stamp="$CACHE/$id.ref"
  local wd="$WORKDIR/$id"

  if [ -d "$target" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$ref" ]; then
    log_skip "$id already at $ref"
    return 0
  fi

  log_info "Fetching $id at $ref..."
  mkdir -p "$wd/src" "$wd/pkg" "$CACHE"
  if ! curl -fsSL --retry 3 -o "$wd/src.tgz" "$url"; then
    log_warn "could not download $id at $ref — keeping the installed copy"
    return 0
  fi
  tar -xzf "$wd/src.tgz" -C "$wd/src"

  local root
  root=$(find "$wd/src" -name metadata.json -printf '%h\n' | head -1)
  if [ -z "$root" ] || [ ! -d "$root/contents" ]; then
    log_warn "$id: unexpected archive layout (no metadata.json/contents) — skipped"
    return 0
  fi

  cp -r "$root/metadata.json" "$root/contents" "$wd/pkg/"
  mkdir -p "$PLASMOIDS"
  # Replace rather than merge: a leftover file from an older version would
  # otherwise survive and be loaded by Plasma.
  rm -rf "$target"
  mv "$wd/pkg" "$target"
  printf '%s\n' "$ref" >"$stamp"
  log_pass "$id $ref installed"
}

install_plasmoid com.github.mazen.salatprayertime \
  "https://codeload.github.com/mazenmohamed203/salaatprayertime/tar.gz/$SALAT_SHA" "$SALAT_REF"
install_plasmoid org.kde.olib.thermalmonitor \
  "https://invent.kde.org/olib/thermalmonitor/-/archive/$THERMAL_SHA/thermalmonitor-$THERMAL_SHA.tar.gz" "$THERMAL_REF"

log_detail "restart Plasma (or re-add the widget) to load a new version"
