#!/usr/bin/env bash
# step-rebuild-test2.sh — round 2: --mount-point=/product + combined file_contexts
# from ALL trees + --force-uid/gid. Plus prop recon (characteristics/display.id/type
# in every build.prop) and 06 v3 re-patch of donor product.
# Usage: bash port/scripts/step-rebuild-test2.sh
set -euo pipefail
. "$(dirname "$0")/lib.sh"
BASE="${BASE:-$HOME/hios-port}"
WORK="$BASE/work"; TREES="$BASE/trees"; OUT="$BASE/out-test"
mkdir -p "$OUT"
S="$PORT_ROOT/scripts"
log "0. clean leaked mounts from test1…"
mount | grep -E "$BASE/(work|out-test)" | awk '{print $3}' | \
  while read -r m; do sudo umount "$m" && echo "cleaned $m"; done || true
log "1. prop recon (characteristics / display.id / type in every build.prop)…"
for p in $(find "$TREES" -name build.prop 2>/dev/null | sort); do
  echo "--- $p"
  grep -nE 'ro\.build\.characteristics|ro\.build\.display\.id|ro\.product\.type|ro\.build\.type|ro\.product\.characteristics' "$p" || echo "(none)"
done
log "2. re-patch donor product with 06 v3 (characteristics in place)…"
bash "$S/06-patch-props.sh" "$TREES/donor-product" donor-product
grep -nE 'ro\.sf\.lcd_density|ro\.build\.characteristics' "$TREES/donor-product/etc/build.prop"
log "3. all file_contexts + which file labels /product…"
FCS="$(find "$TREES" -name '*file_contexts*' 2>/dev/null | sort)"
for f in $FCS; do printf '%s lines %s\n' "$(wc -l < "$f")" "$f"; done
echo "--- /product entries across all fcs:"
grep -h '/product' $FCS 2>/dev/null | head -20 || echo "(no /product entries anywhere!)"
log "4. rebuild with --mount-point=/product + combined fc + forced root ids…"
FC2="$OUT/fc-combined.txt"; rm -f "$FC2"; touch "$FC2"
for f in $FCS; do cat "$f" >> "$FC2"; done
wc -l "$FC2"
mkfs.erofs --workers=1 -zlz4 --mount-point=/product --file-contexts="$FC2" \
  --force-uid=0 --force-gid=0 "$OUT/product_test2.img" "$TREES/donor-product" 2>&1 | tail -4
ls -l "$WORK/product_t1103.img" "$OUT/product_test2.img"
log "5. mount both, compare structure + stamps…"
M1="$(mktemp -d)"; M2="$(mktemp -d)"
trap 'sudo umount "$M1" "$M2" 2>/dev/null || true; rmdir "$M1" "$M2" 2>/dev/null || true' EXIT
sudo mount -o ro,loop "$WORK/product_t1103.img" "$M1"
sudo mount -o ro,loop "$OUT/product_test2.img" "$M2"
echo "--- structure diff (empty = identical layout):"
diff <(cd "$M1" && find . | sort) <(cd "$M2" && find . | sort) | head -10 || true; echo "(end structure diff)"
lab() { getfattr -n security.selinux --only-values "$1" 2>/dev/null || echo "(none)"; }
cmp_one() {
  if [[ ! -e "$M1/$1" || ! -e "$M2/$1" ]]; then echo "SKIP $1 (absent on a side)"; return 0; fi
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
PERM1="$(cd "$M1" && find etc/permissions -name '*.xml' | head -1)"
cmp_one "etc/build.prop"
[[ -n "$APK1" ]] && cmp_one "$APK1"
[[ -n "$APK2" ]] && cmp_one "$APK2"
[[ -n "$JAR1" ]] && cmp_one "$JAR1"
[[ -n "$OVL1" ]] && cmp_one "$OVL1"
[[ -n "$PERM1" ]] && cmp_one "$PERM1"
log "rebuild test2 done. All MATCH = method proven, next: rebuild all + assemble."
