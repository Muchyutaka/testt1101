#!/usr/bin/env bash
# 02-unpack-one.sh — extract ONE partition from super.img (4GB-RAM safe).
# Usage: bash 02-unpack-one.sh <super.img> <partition> <outdir> [slot]
# Example: bash 02-unpack-one.sh super_t1103.img system work/ a
# Refuses whole-super unpacks on purpose.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
IMG="${1:?usage: 02-unpack-one.sh <super.img> <partition> <outdir> [slot]}"
PART="${2:?usage: 02-unpack-one.sh <super.img> <partition> <outdir> [slot]}"
OUT="${3:?usage: 02-unpack-one.sh <super.img> <partition> <outdir> [slot]}"
SLOT="${4:-a}"
need lpunpack; need_file "$IMG"; mkdir -p "$OUT"; ram_check 1500; disk_check "$OUT" 12
BASE="$(basename "$IMG")"; TAG="t1101"
[[ "$BASE" == *1103* || "$BASE" == *donor* ]] && TAG="t1103"
DST="$OUT/${PART}_${TAG}.img"
log "lpunpack --partition=${PART}_${SLOT} $IMG -> $DST"
lpunpack --partition="${PART}_${SLOT}" "$IMG" "$DST"
ls -l "$DST"; file "$DST"
log "done. Next: file says 'sparse'? convert: simg2img $DST ${DST%.img}.raw && mv ... ; then 03-extract-erofs-lowram.sh"
