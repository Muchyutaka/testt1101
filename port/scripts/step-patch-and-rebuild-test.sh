#!/usr/bin/env bash
# step-patch-and-rebuild-test.sh — patch 4 donor trees (density+tablet), then
# rebuild ONE (product, smallest) with mkfs.erofs --file-contexts and verify
# labels+owners against the original. Proves the rebuild method before we do all.
# Usage: bash port/scripts/step-patch-and-rebuild-test.sh
set -euo pipefail
. "$(dirname "$0")/lib.sh"
set +o pipefail
BASE="${BASE:-$HOME/hios-port}"
WORK="$BASE/work"; TREES="$BASE/trees"; OUT="$BASE/out-test"
mkdir -p "$OUT"
S="$PORT_ROOT/scripts"
[[ -d "$TREES/donor-system" ]] || die "trees missing — run step-extract-and-survey.sh first"
log "1. patch 4 donor trees (density 280 + tablet)…"
for t in donor-system donor-system_ext donor-product donor-tr_product; do
  bash "$S/06-patch-props.sh" "$TREES/$t" "$t"
done
echo "=== verify ==="
grep -rn -E 'ro\.sf\.lcd_density|ro\.build\.characteristics|ro\.product\.type' \
  $(find "$TREES" -maxdepth 3 -name build.prop | grep donor) || true
log "2. mkfs.erofs capabilities…"
mkfs.erofs --version 2>&1 || true
mkfs.erofs --help 2>&1 | grep -iE 'context|mount-point|fs-config|xattr|uid|gid' || mkfs.erofs --help 2>&1 | head -40
log "3. discover file_contexts in donor trees…"
find "$TREES/donor-product" "$TREES/donor-system" -name '*file_contexts*' 2>/dev/null
PFC="$(find "$TREES/donor-product" -name '*file_contexts*' 2>/dev/null | head -5)"
PLATFC="$(find "$TREES/donor-system" -name 'plat_file_contexts' 2>/dev/null | head -1)"
echo "--- sample product fc:"; head -8 $PFC 2>/dev/null || echo "(no product fc found)"
log "4. assemble FC1 (originals + /product/-stripped for image-relative match)…"
FC1="$OUT/fc-product-test.txt"; rm -f "$FC1"; touch "$FC1"
for f in $PFC $PLATFC; do [[ -n "$f" ]] && cat "$f" >> "$FC1"; done
for f in $PFC; do [[ -n "$f" ]] && sed 's|^/product/|/|' "$f" >> "$FC1"; done
wc -l "$FC1"
log "5. root-own the tree for packaging (restored to user afterwards)…"
sudo chown -R 0:0 "$TREES/donor-product"
FC_FLAG=""
mkfs.erofs --help 2>&1 | grep -q 'file-contexts' && FC_FLAG="--file-contexts=$FC1" || \
  log "WARNING: this mkfs.erofs lacks --file-contexts; building unlabeled (expect DIFFs, will pivot)"
log "6. mkfs.erofs product test image…"
mkfs.erofs --workers=1 -zlz4 $FC_FLAG "$OUT/product_test.img" "$TREES/donor-product" 2>&1 | tail -5
sudo chown -R "$(id -u):$(id -g)" "$TREES/donor-product"
ls -l "$WORK/product_t1103.img" "$OUT/product_test.img"
log "7. mount both, compare structure + stamps…"
M1="$(mktemp -d)"; M2="$(mktemp -d)"
sudo mount -o ro,loop "$WORK/product_t1103.img" "$M1"
sudo mount -o ro,loop "$OUT/product_test.img" "$M2"
echo "--- structure diff (empty = identical layout):"
diff <(cd "$M1" && find . | sort) <(cd "$M2" && find . | sort) | head -10; echo "(end structure diff)"
lab() { getfattr -n security.selinux --only-values "$1" 2>/dev/null || echo "(none)"; }
cmp_one() {
  local a b sa sb
  a="$(lab "$M1/$1")"; b="$(lab "$M2/$1")"
  sa="$(stat -c '%a %u %g' "$M1/$1")"; sb="$(stat -c '%a %u %g' "$M2/$1")"
  if [[ "$a" == "$b" && "$sa" == "$sb" ]]; then echo "MATCH $1 [$a] [$sa]";
  else echo "DIFF  $1 | orig: [$a] [$sa] | new: [$b] [$sb]"; fi
}
APK1="$(cd "$M1" && find app -name '*.apk' | head -1)"
APK2="$(cd "$M1" && find priv-app -name '*.apk' | head -1)"
JAR1="$(cd "$M1" && find framework -name '*.jar' | head -1)"
OVL1="$(cd "$M1" && find overlay -name '*.apk' | head -1)"
cmp_one "etc/build.prop"
[[ -n "$APK1" ]] && cmp_one "$APK1"
[[ -n "$APK2" ]] && cmp_one "$APK2"
[[ -n "$JAR1" ]] && cmp_one "$JAR1"
[[ -n "$OVL1" ]] && cmp_one "$OVL1"
cmp_one "etc/permissions/privapp-permissions-google-system.xml"
sudo umount "$M1" "$M2"; rmdir "$M1" "$M2"
log "rebuild test done. All MATCH = method proven, next: rebuild all + assemble."
