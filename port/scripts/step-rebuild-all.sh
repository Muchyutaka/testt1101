#!/usr/bin/env bash
# step-rebuild-all.sh — FINAL BUILD: patch (06 v4, idempotent) + rebuild all 4
# donor partitions with the proven flags (--mount-point + combined fc +
# --force-uid/gid, -zlz4hc for size) + verify stamps + fit check vs super.
# Output: $BASE/out/{system,system_ext,product,tr_product}.img (the flash set).
# Takes ~30-45 min unattended. Usage: bash port/scripts/step-rebuild-all.sh
set -euo pipefail
set -E  # errtrace: ERR trap also fires inside functions
. "$(dirname "$0")/lib.sh"
trap 'log "!!! FAILED at line $LINENO: $BASH_COMMAND"' ERR
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
find_super() { # any *super* file, prefer *stock*; no pipelines (errexit-safe)
  local c
  for c in "$BASE"/*super* "$BASE"/work/*super*; do
    [[ -f "$c" ]] || continue
    case "$c" in *stock*) echo "$c"; return 0;; esac
  done
  for c in "$BASE"/*super* "$BASE"/work/*super*; do
    [[ -f "$c" ]] && { echo "$c"; return 0; }
  done
  return 1
}
SUPER="$(find_super || true)"
echo "super candidates:"
ls -l "$BASE"/*super* 2>/dev/null || true
ls -l "$BASE"/work/*super* 2>/dev/null || true
if [[ "${SUPER:-}" == *stock* ]]; then SUPER_KIND="stock"; else SUPER_KIND="non-stock-or-none"; fi
echo "super kind: $SUPER_KIND (fit vs non-stock geometry is informational only)"
echo "super file: ${SUPER:-(none found — fit check falls back to vs-original size)}"
LIST=""
if [[ -n "$SUPER" ]]; then LIST="$(unsuper --list "$SUPER" 2>&1 | head -40 || true)"; echo "$LIST"; fi
log "1. combined file_contexts…"
FCS="$(find "$TREES" -name '*file_contexts*' 2>/dev/null | sort)"
FC2="$OUT/fc-combined.txt"; rm -f "$FC2"; touch "$FC2"
for f in $FCS; do cat "$f" >> "$FC2"; done
wc -l "$FC2"
show_matches() { # $1=pattern $2...=files : up to 10 matches or "(none)" (SIGPIPE-proof)
  local ec=0
  grep -h "$1" ${@:2} 2>/dev/null | head -10 || ec=$?
  (( ec == 1 )) && echo "(none anywhere)"
  (( ec > 1 )) && echo "(grep status $ec)"
  return 0
}
echo "--- tr_product entries:"; show_matches 'tr_product' $FCS
echo "--- system_ext entries:"; show_matches 'system_ext' $FCS
part_size() { # $1=part → bytes from unsuper list ("  name_a: NNN.NMB") or empty
  [[ -z "$LIST" ]] && return 0
  local mb num
  mb="$(echo "$LIST" | awk -v p="$1_a:" '$1==p{print $2}' | head -1 || true)"
  [[ "$mb" =~ ^([0-9]+(\.[0-9]+)?)MB$ ]] || return 0
  num="${BASH_REMATCH[1]}"
  awk -v m="$num" 'BEGIN{printf "%.0f", m*1048576}'
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
build_one() { # PART TREE MOUNT DONOR_ORIG STOCK_ORIG PROPREL
  local part="$1" tree="$2" mp="$3" orig="$4" stock="$5" prop="$6"
  MATCHES=0; DIFFS=0
  log "2. build $part (mount-point=$mp)…"
  if [[ -f "$OUT/$part.img" ]]; then
    log "(reuse existing $OUT/$part.img — delete to force rebuild)"
  else
    mkfs.erofs --workers=1 -zlz4hc --mount-point="$mp" --file-contexts="$FC2" \
      --force-uid=0 --force-gid=0 "$OUT/$part.img" "$tree" 2>&1 | tail -3
  fi
  local osz nsz ssz ps fit
  osz="$(stat -c %s "$orig")"; nsz="$(stat -c %s "$OUT/$part.img")"
  ssz=""; [[ -n "$stock" ]] && ssz="$(stat -c %s "$stock")"
  ps="$(part_size "$part")"
  if [[ -n "$ssz" ]]; then
    if (( nsz <= ssz )); then fit="FIT-vs-stock-orig(spare $(( (ssz-nsz)/1048576 ))MB)";
    else fit="OVERFLOW-vs-stock-orig(+$(( (nsz-ssz)/1048576 ))MB)"; fi
  else fit="STOCK-ORIG-UNKNOWN(donor-orig $(( osz/1048576 ))MB → new $(( nsz/1048576 ))MB)";
  fi
  if [[ -n "$ps" ]]; then fit="$fit super[$SUPER_KIND]:part $(( ps/1048576 ))MB"; fi
  echo "sizes: donor-orig=$osz stock-orig=${ssz:-?} new=$nsz $fit"
  M1="$(mktemp -d)"; M2="$(mktemp -d)"
  sudo mount -o ro,loop "$orig" "$M1"
  sudo mount -o ro,loop "$OUT/$part.img" "$M2"
  echo "--- $part structure diff (sudo, empty = identical):"
  diff <(sudo find "$M1" -printf '%P\n' 2>/dev/null | sort) <(sudo find "$M2" -printf '%P\n' 2>/dev/null | sort) | head -10 || true
  echo "(end $part structure diff)"
  cmp_one "$prop"
  S1="$(cd "$M1" && { find app priv-app -name '*.apk' 2>/dev/null | head -2 || true; find framework -name '*.jar' 2>/dev/null | head -1 || true; find etc -name '*.xml' 2>/dev/null | head -1 || true; })"
  echo "samples: ${S1:-<none>}"
  for s in $S1; do cmp_one "$s"; done
  sudo umount "$M1" "$M2" 2>/dev/null || sudo umount -l "$M1" "$M2" 2>/dev/null || true
  rmdir "$M1" "$M2" 2>/dev/null || true
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
resolve_stock() { # part → stock orig path or nothing (graceful)
  local c
  for c in "${1}_t1101.img" "stock_${1}.img" "${1}_stock.img" "${1}.img"; do
    [[ -f "$WORK/$c" ]] && { echo "$WORK/$c"; return 0; }
  done
  return 1
}
ORIG_SYSTEM="$(resolve system_t1103.img 'system.img')"
ORIG_EXT="$(resolve system_ext_t1103.img 'system_ext.img')"
ORIG_PROD="$(resolve product_t1103.img 'product.img')"
ORIG_TRP="$(resolve tr_product_t1103.img 'tr_product.img')"
log "donor originals: $ORIG_SYSTEM $ORIG_EXT $ORIG_PROD $ORIG_TRP"
STOCK_SYSTEM="$(resolve_stock system || true)"
STOCK_EXT="$(resolve_stock system_ext || true)"
STOCK_PROD="$(resolve_stock product || true)"
STOCK_TRP="$(resolve_stock tr_product || true)"
log "stock originals: ${STOCK_SYSTEM:-?} ${STOCK_EXT:-?} ${STOCK_PROD:-?} ${STOCK_TRP:-?}"
ls -l "$WORK" | head -20 || true
trap 'sudo umount "${M1:-/nonexistent}" "${M2:-/nonexistent}" 2>/dev/null || true' EXIT
build_one system     "$TREES/donor-system"     /           "$ORIG_SYSTEM" "${STOCK_SYSTEM:-}" system/build.prop
build_one system_ext "$TREES/donor-system_ext" /system_ext "$ORIG_EXT"    "${STOCK_EXT:-}"    etc/build.prop
build_one product    "$TREES/donor-product"    /product    "$ORIG_PROD"   "${STOCK_PROD:-}"   etc/build.prop
build_one tr_product "$TREES/donor-tr_product" /tr_product "$ORIG_TRP"    "${STOCK_TRP:-}"    etc/build.prop
trap - EXIT
log "4. slimming recon (biggest dirs/files in donor system_ext + tr_product)…"
echo "--- system_ext top-15 dirs:"; du -x -d2 "$TREES/donor-system_ext" 2>/dev/null | sort -rh | head -15 || true
echo "--- tr_product top-15 dirs:"; du -x -d2 "$TREES/donor-tr_product" 2>/dev/null | sort -rh | head -15 || true
echo "--- system_ext biggest-12 files:"; find "$TREES/donor-system_ext" -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -12 | awk '{printf "%.1fMB %s\n", $1/1048576, $2}' || true
echo "--- tr_product biggest-12 files:"; find "$TREES/donor-tr_product" -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -12 | awk '{printf "%.1fMB %s\n", $1/1048576, $2}' || true
echo "--- system_ext app dirs:"; ls "$TREES/donor-system_ext/app" "$TREES/donor-system_ext/priv-app" 2>/dev/null || echo "(no app/priv-app)"
log "5. manifest…"
ls -l "$OUT"/*.img
echo "=========== SUMMARY ==========="; echo "$SUMMARY"
log "rebuild-all done. Next: flash plan (fastbootd per-partition)."
