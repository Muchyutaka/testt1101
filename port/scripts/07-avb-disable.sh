#!/usr/bin/env bash
# 07-avb-disable.sh — patch vbmeta* to disable verity+verification (Debian path).
# DNA-Android path: open vbmeta.img → Patch vbmeta → Disable AVB/verification (same result).
# Usage: bash 07-avb-disable.sh <vbmeta.img> <vbmeta_system.img> <vbmeta_vendor.img> <outdir>
set -euo pipefail
. "$(dirname "$0")/lib.sh"
need avbtool
VBMETA="${1:?usage…}"; VBMETA_SYS="${2:?usage…}"; VBMETA_VND="${3:?usage…}"; OUT="${4:?usage…}"
mkdir -p "$OUT"
for f in "$VBMETA" "$VBMETA_SYS" "$VBMETA_VND"; do need_file "$f"; done
avbtool info_image --image "$VBMETA" | head -20 || true
# --flags 3 = disable verity + verification; keep rollback indexes, zero hash would brick OTA (fine for port)
avbtool make_vbmeta_image --flags 3 --padding_size 4096 --output "$OUT/vbmeta_patched.img" 2>&1 | tail -2
for src in "$VBMETA_SYS" "$VBMETA_VND"; do
  base="$(basename "$src" .img)"
  avbtool make_vbmeta_image --flags 3 --padding_size 4096 --output "$OUT/${base}_patched.img" 2>&1 | tail -2
done
ls -l "$OUT"
echo; log "flash:"
echo "  fastboot --disable-verity --disable-verification flash vbmeta $OUT/vbmeta_patched.img"
echo "  fastboot --disable-verity --disable-verification flash vbmeta_system $OUT/vbmeta_system_patched.img"
echo "  fastboot --disable-verity --disable-verification flash vbmeta_vendor $OUT/vbmeta_vendor_patched.img"
log "If avbtool version mismatches Transsion vbmeta, use DNA-Android's vbmeta patch instead — then re-verify with: avbtool info_image --image <patched>"
