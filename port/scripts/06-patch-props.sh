#!/usr/bin/env bash
# 06-patch-props.sh — mechanical T1103→T1101 prop fixes on an EXTRACTED donor tree.
# Usage: bash 06-patch-props.sh <extracted-donor-root> [t1101-dumps-dir]
# Edits build.props in place + prints overlay/feature files needing manual review.
# Idempotent-ish: re-running is safe (sed replaces exact donor values only).
set -euo pipefail
. "$(dirname "$0")/lib.sh"
ROOT="${1:?usage: 06-patch-props.sh <extracted-donor-root> [t1101-dumps]}"
DUMPS="${2:-$PORT_ROOT/dumps/t1101}"
T1101_FP="TECNO/TSSI/T1101:14/UP1A.231005.007/260410V1046:user/release-keys"
T1101_DESC="sys_tssi_64_armv82_tecno_dolby-user 14 UP1A.231005.007 987287 release-keys"
# density: prefer measured T1101 value if dumps present
DENSITY=""
[[ -f "$DUMPS/build-props/system-build.prop" ]] && DENSITY="$(grep -m1 'ro.sf.lcd_density' "$DUMPS/build-props/system-build.prop" | cut -d= -f2 || true)"
log "target density: ${DENSITY:-<keep donor, T1101 dumps missing>}"
fix_prop() { # $1=file $2=key $3=value
  [[ -f "$1" ]] || return 0
  if grep -q "^$2=" "$1"; then sed -i "s|^$2=.*|$2=$3|" "$1"; else printf '%s=%s\n' "$2" "$3" >> "$1"; fi
  log "  $2=$3  ($1)"
}
while IFS= read -r -d '' BP; do
  log "patching $BP"
  sed -i -e 's/T1103/T1101/g' -e 's/t1103/t1101/gi' "$BP"
  fix_prop "$BP" ro.product.device T1101
  fix_prop "$BP" ro.build.product T1101
  fix_prop "$BP" ro.product.name T1101
  fix_prop "$BP" ro.product.model "Tecno MegaPad 11"
  fix_prop "$BP" ro.product.brand TECNO
  fix_prop "$BP" ro.product.manufacturer tecno
  for k in ro.build.fingerprint ro.system.build.fingerprint ro.product.build.fingerprint; do
    grep -q "^$k=" "$BP" && fix_prop "$BP" "$k" "$T1101_FP" || true
  done
  grep -q '^ro.build.description=' "$BP" && fix_prop "$BP" ro.build.description "$T1101_DESC" || true
  [[ -n "$DENSITY" ]] && grep -q '^ro.sf.lcd_density=' "$BP" && fix_prop "$BP" ro.sf.lcd_density "$DENSITY" || true
done < <(find "$ROOT" -maxdepth 4 \( -name build.prop -o -name default.prop \) -print0)
echo; log "manual-review list (NOT auto-patched — see port/README.md §4.3):"
find "$ROOT" -path '*overlay*' -name '*.apk' 2>/dev/null | head -20
find "$ROOT" -path '*permissions*/*.xml' -o -path '*sysconfig*/*.xml' 2>/dev/null | head -20
log "done. Rebuild this partition with mkfs.erofs --workers=1 -zlz4 before lpmake."
