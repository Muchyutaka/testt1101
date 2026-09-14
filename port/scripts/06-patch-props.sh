#!/usr/bin/env bash
# 06-patch-props.sh v2 — donor system-side is GENERIC MSSI (zero T1103 strings
# outside odm, which we skip), and stock system is generic too. So: no identity
# replacement; we ADD T1101 specifics: density 280 everywhere + tablet flags.
# Fingerprints/identity left generic-on-purpose (boot doesn't care; GMS
# certification tuning is post-boot). Idempotent.
# Usage: bash 06-patch-props.sh <extracted-tree> [tree-name]
set -euo pipefail
. "$(dirname "$0")/lib.sh"
ROOT="${1:?usage: 06-patch-props.sh <extracted-tree> [tree-name]}"
NAME="${2:-$(basename "$ROOT")}"
DENSITY=280
set_prop() { # file key value
  if grep -q "^$2=" "$1"; then sed -i "s|^$2=.*|$2=$3|" "$1"; else printf '%s=%s\n' "$2" "$3" >> "$1"; fi
}
while IFS= read -r -d '' BP; do
  log "--- $BP"
  if grep -qi 't1103' "$BP"; then
    sed -i -e 's/T1103/T1101/g' -e 's/t1103/t1101/g' "$BP"
    log "  T1103→T1101 replaced (unexpected on generic donor — verify!)"
  fi
  set_prop "$BP" ro.sf.lcd_density "$DENSITY"
  log "  ro.sf.lcd_density=$DENSITY"
  if [[ "$BP" == */product/etc/build.prop ]]; then
    set_prop "$BP" ro.build.characteristics tablet
    set_prop "$BP" ro.product.type tablet
    log "  characteristics=tablet, type=tablet"
  fi
done < <(find "$ROOT" -maxdepth 4 -name build.prop -print0)
log "done ($NAME)."
