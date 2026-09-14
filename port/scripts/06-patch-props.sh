#!/usr/bin/env bash
# 06-patch-props.sh TREE TAG — v4 (final patch list from prop recon 2026-09-14):
#  - all donor trees: ro.sf.lcd_density=280 (in place)
#  - donor product: ro.build.characteristics=tablet (in place),
#    ro.product.type=tablet + ro.build.display.id=T1101-...V1133 (appended,
#    Transsion keys present in stock product, absent in donor)
# Backups live OUTSIDE trees ($BASE/work/prop-orig) so they never get packaged.
# Usage: bash port/scripts/06-patch-props.sh <tree> <tag>
set -euo pipefail
. "$(dirname "$0")/lib.sh"
T="${1:?usage: 06-patch-props.sh TREE TAG}"; TAG="${2:?usage: 06-patch-props.sh TREE TAG}"
BASE="${BASE:-$HOME/hios-port}"
ORIG_DIR="$BASE/work/prop-orig"; mkdir -p "$ORIG_DIR"
P="$(find "$T" -maxdepth 4 -name build.prop 2>/dev/null | head -1)"
[[ -n "$P" ]] || die "no build.prop under $T"
if [[ ! -e "$ORIG_DIR/$TAG-build.prop.orig" ]]; then
  if [[ -e "$P.orig" ]]; then mv "$P.orig" "$ORIG_DIR/$TAG-build.prop.orig"
  else cp "$P" "$ORIG_DIR/$TAG-build.prop.orig"; fi
fi
log "--- $P (backup: $ORIG_DIR/$TAG-build.prop.orig)"
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
  grep -q '^ro\.product\.type=' "$P" || echo 'ro.product.type=tablet' >> "$P"
  echo "  ro.product.type=tablet"
  grep -q '^ro\.build\.display\.id=' "$P" || \
    echo 'ro.build.display.id=T1101-M1101ABCD-U-BASE-260410V1133' >> "$P"
  echo "  ro.build.display.id=T1101-...V1133"
fi
log "done ($TAG)."
