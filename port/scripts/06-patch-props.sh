#!/usr/bin/env bash
# 06-patch-props.sh TREE TAG — v3: density 280 in place (all donor trees);
# donor product also gets ro.build.characteristics=tablet IN PLACE
# (the exact key init reads; v2 added a useless ro.product.* key instead).
# Usage: bash port/scripts/06-patch-props.sh <tree> <tag>
set -euo pipefail
. "$(dirname "$0")/lib.sh"
T="${1:?usage: 06-patch-props.sh TREE TAG}"; TAG="${2:?usage: 06-patch-props.sh TREE TAG}"
P="$(find "$T" -maxdepth 4 -name build.prop 2>/dev/null | head -1)"
[[ -n "$P" ]] || die "no build.prop under $T"
cp -n "$P" "$P.orig" 2>/dev/null || true
log "--- $P"
sed -i -E 's/^(ro\.sf\.lcd_density=).*/\1280/' "$P"
grep -q '^ro\.sf\.lcd_density=' "$P" || echo 'ro.sf.lcd_density=280' >> "$P"
echo "  ro.sf.lcd_density=280"
if [[ "$TAG" == "donor-product" ]]; then
  if grep -q '^ro\.build\.characteristics=' "$P"; then
    sed -i -E 's/^(ro\.build\.characteristics=).*/\1tablet/' "$P"
  else
    echo 'ro.build.characteristics=tablet' >> "$P"
  fi
  echo "  ro.build.characteristics=tablet"
fi
log "done ($TAG)."
