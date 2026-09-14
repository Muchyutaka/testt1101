#!/usr/bin/env bash
# 06-patch-props.sh TREE TAG — v5: density in place (all); donor product gets
# tablet characteristics/type/display.id; donor tr_product gets T1101 identity
# + ro.tran.tr_product flags (stock parity; donor is generic mssi).
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
if [[ "$TAG" == "donor-tr_product" ]]; then
  sed -i -E 's/^(ro\.product\.tr_product\.brand=).*/\1TECNO/' "$P"
  sed -i -E 's/^(ro\.product\.tr_product\.device=).*/\1TECNO-T1101/' "$P"
  sed -i -E 's/^(ro\.product\.tr_product\.manufacturer=).*/\1TECNO/' "$P"
  sed -i -E 's/^(ro\.product\.tr_product\.model=).*/\1TECNO T1101/' "$P"
  sed -i -E 's/^(ro\.product\.tr_product\.name=).*/\1T1101-OP/' "$P"
  echo "  tr_product identity → T1101"
  grep -q '^ro\.product\.name=' "$P" || echo 'ro.product.name=T1101-OP' >> "$P"
  grep -q '^ro\.tran\.tr_product\.support=' "$P" || echo 'ro.tran.tr_product.support=1' >> "$P"
  grep -q '^ro\.tran\.tr_product\.version=' "$P" || echo 'ro.tran.tr_product.version=OP-220417V1' >> "$P"
  echo "  ro.product.name + ro.tran.tr_product.support/version set"
fi
log "done ($TAG)."
