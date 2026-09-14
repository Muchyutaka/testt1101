#!/usr/bin/env bash
# step-finalize-apps.sh — FINAL CONTENT BATCH: 06 v5 (tr_product identity+flags),
# transplant stock Phonesky→product/priv-app (oat stripped) + PlayAutoInstallStub
# →tr_product/app + TrProductOobeOverlayRes→product/overlay, DELETE EngineerCamera
# (245MB factory test app), rebuild product + tr_product, verify.
# ~15 min. Usage: bash port/scripts/step-finalize-apps.sh
set -euo pipefail
set -E
. "$(dirname "$0")/lib.sh"
trap 'log "!!! FAILED at line $LINENO: $BASH_COMMAND"' ERR
BASE="${BASE:-$HOME/hios-port}"
WORK="$BASE/work"; TREES="$BASE/trees"; OUT="$BASE/out"
S="$PORT_ROOT/scripts"
STOCK_TR_IMG="${STOCK_TR_IMG:-$HOME/tr_product_stock_a.img}"
[[ -f "$STOCK_TR_IMG" ]] || die "missing $STOCK_TR_IMG (pull stock tr_product_a first)"
[[ -d "$TREES/stock-product/priv-app/Phonesky" ]] || die "missing stock Phonesky tree"
FC2="$OUT/fc-combined.txt"
if [[ ! -f "$FC2" ]]; then
  log "(rebuild combined fc)"
  FCS="$(find "$TREES" -name '*file_contexts*' 2>/dev/null | sort)"
  rm -f "$FC2"; touch "$FC2"
  for f in $FCS; do cat "$f" >> "$FC2"; done
fi
log "0. 06 v5 on tr_product (identity + flags)…"
bash "$S/06-patch-props.sh" "$TREES/donor-tr_product" donor-tr_product | tail -4
grep -nE 'ro\.product\.tr_product|ro\.product\.name|ro\.tran\.tr_product' "$TREES/donor-tr_product/etc/build.prop"
log "1. transplant Phonesky → product/priv-app (strip stale A14 oat)…"
rm -rf "$TREES/donor-product/priv-app/Phonesky"
cp -a "$TREES/stock-product/priv-app/Phonesky" "$TREES/donor-product/priv-app/Phonesky"
rm -rf "$TREES/donor-product/priv-app/Phonesky/oat"
du -sh "$TREES/donor-product/priv-app/Phonesky"; ls "$TREES/donor-product/priv-app/Phonesky"
log "2. stock tr_product img → Stub + overlay…"
M0="$(mktemp -d)"
trap 'sudo umount "$M0" "${M1:-/nonexistent}" "${M2:-/nonexistent}" 2>/dev/null || true' EXIT
sudo mount -o ro,loop "$STOCK_TR_IMG" "$M0"
if [[ -d "$M0/app/PlayAutoInstallStub" ]]; then
  rm -rf "$TREES/donor-tr_product/app/PlayAutoInstallStub"
  cp -a "$M0/app/PlayAutoInstallStub" "$TREES/donor-tr_product/app/PlayAutoInstallStub"
  du -sh "$TREES/donor-tr_product/app/PlayAutoInstallStub"
else echo "WARN: PlayAutoInstallStub absent in stock img (continuing without it)"; fi
if [[ -f "$M0/overlay/TrProductOobeOverlayRes.apk" ]]; then
  cp -a "$M0/overlay/TrProductOobeOverlayRes.apk" "$TREES/donor-product/overlay/TrProductOobeOverlayRes.apk"
  ls -l "$TREES/donor-product/overlay/TrProductOobeOverlayRes.apk"
else echo "WARN: OOBE overlay absent in stock img (continuing without it)"; fi
sudo umount "$M0"; rmdir "$M0"
log "3. delete EngineerCamera (factory test app, 245MB)…"
rm -rf "$TREES/donor-tr_product/app/EngineerCamera"
ls "$TREES/donor-tr_product/app"
lab() { getfattr -n security.selinux --only-values "$1" 2>/dev/null || echo "(none)"; }
MATCHES=0; DIFFS=0; NEWLABS=""
cmp_one() {
  if [[ ! -e "$M1/$1" || ! -e "$M2/$1" ]]; then echo "SKIP $1 (absent on a side)"; return 0; fi
  local a b sa sb
  a="$(lab "$M1/$1")"; b="$(lab "$M2/$1")"
  sa="$(stat -c '%a %u %g' "$M1/$1")"; sb="$(stat -c '%a %u %g' "$M2/$1")"
  if [[ "$a" == "$b" && "$sa" == "$sb" ]]; then echo "MATCH $1 [$a] [$sa]"; MATCHES=$((MATCHES+1));
  else echo "DIFF  $1 | orig: [$a] [$sa] | new: [$b] [$sb]"; DIFFS=$((DIFFS+1)); fi
}
new_lab() { # $1=relpath : report label of a NEW file (no orig to compare)
  if [[ -e "$M2/$1" ]]; then
    local l="NEW $1 [$(lab "$M2/$1")] [$(stat -c '%a %u %g' "$M2/$1")]"
    echo "$l"; NEWLABS="$NEWLABS
$l"
  else echo "MISSING $1 (expected new file!)"; NEWLABS="$NEWLABS
MISSING $1"; fi
}
SUMMARY=""
build_one() { # PART TREE MOUNT DONOR_ORIG STOCKREF PROPREL
  local part="$1" tree="$2" mp="$3" orig="$4" stockref="$5" prop="$6"
  MATCHES=0; DIFFS=0
  log "4. rebuild $part…"
  mkfs.erofs --workers=1 -zlz4hc --mount-point="$mp" --file-contexts="$FC2" \
    --force-uid=0 --force-gid=0 "$OUT/$part.img" "$tree" 2>&1 | tail -3
  local osz nsz ssz fit
  osz="$(stat -c %s "$orig")"; nsz="$(stat -c %s "$OUT/$part.img")"; ssz="$(stat -c %s "$stockref")"
  if (( nsz <= ssz )); then fit="FIT-vs-stock-orig(spare $(( (ssz-nsz)/1048576 ))MB)";
  else fit="OVERFLOW-vs-stock-orig(+$(( (nsz-ssz)/1048576 ))MB)"; fi
  echo "sizes: donor-orig=$osz stock-ref=$ssz new=$nsz $fit"
  M1="$(mktemp -d)"; M2="$(mktemp -d)"
  sudo mount -o ro,loop "$orig" "$M1"
  sudo mount -o ro,loop "$OUT/$part.img" "$M2"
  echo "--- $part structure diff (expect ONLY transplant deltas):"
  diff <(sudo find "$M1" -printf '%P\n' 2>/dev/null | sort) <(sudo find "$M2" -printf '%P\n' 2>/dev/null | sort) | head -15 || true
  echo "(end $part structure diff)"
  cmp_one "$prop"
  S1="$(cd "$M1" && { find app priv-app -name '*.apk' 2>/dev/null | head -2 || true; find framework -name '*.jar' 2>/dev/null | head -1 || true; find etc -name '*.xml' 2>/dev/null | head -1 || true; })"
  for s in $S1; do cmp_one "$s"; done
  if [[ "$part" == "product" ]]; then
    new_lab "priv-app/Phonesky/Phonesky.apk"
    new_lab "overlay/TrProductOobeOverlayRes.apk"
  else
    SA="$(cd "$M2" && find app/PlayAutoInstallStub -name '*.apk' 2>/dev/null | head -1 || true)"
    [[ -n "$SA" ]] && new_lab "$SA" || echo "(no Stub transplanted)"
  fi
  sudo umount "$M1" "$M2" 2>/dev/null || sudo umount -l "$M1" "$M2" 2>/dev/null || true
  rmdir "$M1" "$M2" 2>/dev/null || true
  SUMMARY="$SUMMARY
$part: MATCH=$MATCHES DIFF=$DIFFS $fit"
}
STOCK_PROD="$(ls "$WORK"/product_t1101.img 2>/dev/null || ls "$WORK"/stock_product.img 2>/dev/null || true)"
[[ -n "$STOCK_PROD" ]] || die "stock product img not found in $WORK"
build_one product    "$TREES/donor-product"    /product    "$WORK/product_t1103.img"    "$STOCK_PROD"  etc/build.prop
build_one tr_product "$TREES/donor-tr_product" /tr_product "$WORK/tr_product_t1103.img" "$STOCK_TR_IMG" etc/build.prop
trap - EXIT
log "5. manifest…"
ls -l "$OUT"/*.img
echo "=========== SUMMARY ==========="; echo "$SUMMARY"
echo "=========== NEW FILES ==========="; echo "${NEWLABS:-<none>}"
log "finalize done. Images in $OUT are the flash set."
