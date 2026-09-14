#!/usr/bin/env bash
# 05-minimal-port.sh — rebuild T1101 super: stock vendor*+tr_* + donor system/system_ext/product.
# Usage: bash 05-minimal-port.sh <workdir-with-partition-imgs> <out-super.img> [slot]
# Expects in <workdir>: system_t1103.img system_ext_t1103.img product_t1103.img (patched+rebuilt EROFS)
#   + vendor_t1101.img vendor_dlkm_t1101.img odm_dlkm_t1101.img tr_*.img (stock, untouched)
# Uses T1101 size/group ONLY. Refuses to run if donor super size leaked in.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
WORK="${1:?usage: 05-minimal-port.sh <workdir> <out-super.img> [slot]}"
OUT="${2:?usage: 05-minimal-port.sh <workdir> <out-super.img> [slot]}"
SLOT="${3:-a}"
need lpmake
SUPER_SIZE=9126805504; GROUP=main
STOCK=(vendor vendor_dlkm odm_dlkm tr_mi tr_theme tr_region tr_company tr_carrier tr_product tr_preload)
DONOR=(system system_ext product)
have() { [[ -f "$WORK/$1.img" ]] && echo "$WORK/$1.img" || die "missing $WORK/$1.img (need ${STOCK[*]} from t1101 + ${DONOR[*]} from t1103)"; }
ARGS=(--metadata-size 65536 --super-name super --metadata-slots 3
  --device "super:${SUPER_SIZE}" --group "${GROUP}:${SUPER_SIZE}"
  --sparses --output "$OUT")
for p in "${DONOR[@]}"; do
  F="$(have "${p}_t1103")"
  SZ="$(stat -c%s "$F")"
  ARGS+=(--partition "${p}_${SLOT}:readonly:${SZ}:${GROUP}" --image "${p}_${SLOT}:=$F")
  log "donor: $p <- $F ($SZ)"
done
for p in "${STOCK[@]}"; do
  F="$WORK/${p}_t1101.img"
  [[ -f "$F" ]] || { log "SKIP stock $p (no $F) — only OK if your lpdump proves it isn't in super"; continue; }
  SZ="$(stat -c%s "$F")"
  ARGS+=(--partition "${p}_${SLOT}:readonly:${SZ}:${GROUP}" --image "${p}_${SLOT}:=$F")
  log "stock: $p <- $F ($SZ)"
done
ram_check 2000; disk_check "$(dirname "$OUT")" 12
log "lpmake ${ARGS[*]}"
lpmake "${ARGS[@]}"
ls -l "$OUT"; file "$OUT"
command -v lpdump >/dev/null 2>&1 && lpdump "$OUT" | head -40 || true
log "OK → $OUT. Verify: 01-inspect-super.sh $OUT ; mount-test in OrangeFox before first boot."
