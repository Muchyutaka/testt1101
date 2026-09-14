#!/usr/bin/env bash
# step-rebuild-all.sh — FINAL BUILD: patch (06 v4, idempotent) + rebuild all 4
# donor partitions with the proven flags (--mount-point + combined fc +
# --force-uid/gid, -zlz4hc for size) + verify stamps + fit check vs super.
# Output: $BASE/out/{system,system_ext,product,tr_product}.img (the flash set).
# Takes ~30-45 min unattended. Usage: bash port/scripts/step-rebuild-all.sh
set -euo pipefail
. "$(dirname "$0")/lib.sh"
BASE="${BASE:-$HOME/hios-port}"
WORK="$BASE/work"; TREES="$BASE/trees"; OUT="$BASE/out"
mkdir -p "$OUT"
S="$PORT_ROOT/scripts"
log "0a. delete stray in-tree *.orig backups…"
find "$TREES" -name '*.orig' -delete -print || true
log "0b. 06 v4 re-run (idempotent) + verify…"
for t in donor-system donor-system_ext donor-product donor-tr_product; do
  bash "$S/06-patch-props.sh" "$TREES/$t" "$t" | tail -3
done
grep -rn -E 'ro\.sf\.lcd_density|ro\.build\.characteristics|ro\.product\.type|ro\.build\.display\.id' \
  $(find "$TREES" -name build.prop | grep donor) || true
log "0c. property_source_order confirm…"
grep -h 'property_source_order' "$TREES/donor-system/system/build.prop" "$TREES/stock-system/system/build.prop" || true
log "0d. stock super geometry (partition sizes)…"
SUPER="$(ls "$BASE"/*super*.img "$BASE"/work/*super*.img 2>/dev/null | grep -i stock | head -1)"
[[ -z "$SUPER" ]] && SUPER="$(ls "$BASE"/*super*.img "$BASE"/work/*super*.img 2>/dev/null | head -1)"
echo "super file: ${SUPER:-(none found — fit check falls back to vs-original size)}"
LIST=""
if [[ -n "$SUPER" ]]; then LIST="$(unsuper --list "$SUPER" 2>&1 | head -40)"; echo "$LIST"; fi
log "1. combined file_contexts…"
FCS="$(find "$TREES" -name '*file_contexts*' 2>/dev/null | sort)"
FC2="$OUT/fc-combined.txt"; rm -f "$FC2"; touch "$FC2"
for f in $FCS; do cat "$f" >> "$FC2"; done
wc -l "$FC2"
echo "--- tr_product entries:"; grep -h 'tr_product' $FCS 2>/dev/null | head -10 || echo "(none anywhere)"
echo "--- system_ext entries:"; grep -h 'system_ext' $FCS 2>/dev/null | head -5 || echo "(none anywhere)"
part_size() { # best-effort numeric size from unsuper --list, else empty
  [[ -z "$LIST" ]] && return 0
  echo "$LIST" | awk -v p="$1" '$1==p{print $2}' | head -1 | grep -E '^[0-9]+$' || true
}
lab() { getfattr -n security.selinux --only-values "$1" 2>/dev/null || echo "(none)"; }
MATCHES=0; DIFFS=0
cmp_one() {
  if [[ ! -e "$M1/$1" || ! -e "$M2/$1" ]]; then echo "SKIP $1 (absent on a side)"; return 0; fi
  local a b sa sb
  a="$(lab "$M1/$1")"; b="$(lab "$M2/$1")"
  sa="$(stat -c '%a %u %g' "$M1/$1")"; sb="$(stat -c '%a %u %g' "$M2/$1")"
  if [[ "$a" == "$b" && "$sa" == "$sb" ]]; then echo "MATCH $1 [$a] [$sa]"; MATCHES=$((MATCHES+1));
  else echo "DIFF  $1 | orig: [$a] [$sa] | new: [$b] [$sb]"; DIFFS=$((DIFFS+1)); fi
}
SUMMARY=""
build_one() { # PART TREE MOUNT ORIG_IMG PROPREL
  local part="$1" tree="$2" mp="$3" orig="$4" prop="$5"
  MATCHES=0; DIFFS=0
  log "2. build $part (mount-point=$mp)…"
  mkfs.erofs --workers=1 -zlz4hc --mount-point="$mp" --file-contexts="$FC2" \
    --force-uid=0 --force-gid=0 "$OUT/$part.img" "$tree" 2>&1 | tail -3
  local osz nsz ps fit
  osz="$(stat -c %s "$orig")"; nsz="$(stat -c %s "$OUT/$part.img")"
  ps="$(part_size "$part")"
  if [[ -n "$ps" ]]; then
    if (( nsz <= ps )); then fit="FIT(partition $ps)"; else fit="OVERFLOW(partition $ps)"; fi
  else fit="PARTSIZE-UNKNOWN(orig $osz → new $nsz)";
  fi
  echo "sizes: orig=$osz new=$nsz $fit"
  M1="$(mktemp -d)"; M2="$(mktemp -d)"
  sudo mount -o ro,loop "$orig" "$M1"
  sudo mount -o ro,loop "$OUT/$part.img" "$M2"
  echo "--- $part structure diff:"; diff <(cd "$M1" && find . | sort) <(cd "$M2" && find . | sort) | head -10 || true; echo "(end $part structure diff)"
  cmp_one "$prop"
  S1="$(cd "$M1" && { find app priv-app -name '*.apk' 2>/dev/null | head -2; find framework -name '*.jar' 2>/dev/null | head -1; find etc -name '*.xml' 2>/dev/null | head -1; })"
  for s in $S1; do cmp_one "$s"; done
  sudo umount "$M1" "$M2"; rmdir "$M1" "$M2"
  SUMMARY="$SUMMARY
$part: MATCH=$MATCHES DIFF=$DIFFS $fit"
}
resolve() { # exactname fallback-glob → path or die with listing
  local f
  f="$(ls "$WORK/$1" 2>/dev/null)" && { echo "$f"; return 0; }
  f="$(ls "$WORK"/$2 2>/dev/null | head -1)"
  [[ -n "$f" ]] && { echo "$f"; return 0; }
  die "original image for $1 not found in $WORK: $(ls "$WORK" | tr '\n' ' ')"
}
ORIG_SYSTEM="$(resolve system_t1103.img 'system.img')"
ORIG_EXT="$(resolve system_ext_t1103.img 'system_ext.img')"
ORIG_PROD="$(resolve product_t1103.img 'product.img')"
ORIG_TRP="$(resolve tr_product_t1103.img 'tr_product.img')"
log "originals: $ORIG_SYSTEM $ORIG_EXT $ORIG_PROD $ORIG_TRP"
trap 'sudo umount "${M1:-/nonexistent}" "${M2:-/nonexistent}" 2>/dev/null || true' EXIT
build_one system     "$TREES/donor-system"     /           "$ORIG_SYSTEM" system/build.prop
build_one system_ext "$TREES/donor-system_ext" /system_ext "$ORIG_EXT"    etc/build.prop
build_one product    "$TREES/donor-product"    /product    "$ORIG_PROD"   etc/build.prop
build_one tr_product "$TREES/donor-tr_product" /tr_product "$ORIG_TRP"    etc/build.prop
trap - EXIT
log "3. manifest…"
ls -l "$OUT"/*.img
echo "=========== SUMMARY ==========="; echo "$SUMMARY"
log "rebuild-all done. Next: flash plan (fastbootd per-partition)."
