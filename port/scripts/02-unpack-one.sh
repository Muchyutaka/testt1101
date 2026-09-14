#!/usr/bin/env bash
# 02-unpack-one.sh — extract ONE partition from super.img (4GB-RAM safe).
# Prefers `unsuper -p` (handles sparse directly). Falls back to lpunpack (raw only).
# Usage: bash 02-unpack-one.sh <super.img> <partition> <outdir> [slot]
# Example: bash 02-unpack-one.sh super_t1103.img system work/ a
# Refuses whole-super unpacks on purpose. Refuses if disk can't fit the job.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
IMG="${1:?usage: 02-unpack-one.sh <super.img> <partition> <outdir> [slot]}"
PART="${2:?usage: 02-unpack-one.sh <super.img> <partition> <outdir> [slot]}"
OUT="${3:?usage: 02-unpack-one.sh <super.img> <partition> <outdir> [slot]}"
SLOT="${4:-a}"
need_file "$IMG"; mkdir -p "$OUT"; ram_check 1500
BASE="$(basename "$IMG")"; TAG="t1101"
[[ "$BASE" == *1103* || "$BASE" == *donor* ]] && TAG="t1103"
SPARSE=0
head -c 4 "$IMG" | od -A n -t x1 | grep -q '3a ff 26 ed' && SPARSE=1 || true
if command -v unsuper >/dev/null 2>&1; then
  # unsuper may stage full raw temp for sparse input: require raw+8GB free
  if (( SPARSE )); then
    BLOCKS="$(file -b "$IMG" | grep -oP 'Total of \K[0-9]+' || echo 0)"
    NEED_GB=$(( BLOCKS * 4096 / 1024 / 1024 / 1024 + 8 ))
    disk_check "$OUT" "$NEED_GB"
  else
    disk_check "$OUT" 8
  fi
  T="$OUT/.tmp-unsuper"; mkdir -p "$T"; export TMPDIR="$T"
  log "unsuper $IMG -p ${PART}_${SLOT} (jobs=2 for 4GB RAM, temp on big disk)"
  (cd "$OUT" && unsuper "$IMG" . -p "${PART}_${SLOT}" -j2 -q --temp-dir "$T")
  rm -rf "$T"
  mv "$OUT/${PART}_${SLOT}.img" "$OUT/${PART}_${TAG}.img" 2>/dev/null || {
    ls "$OUT"; die "expected ${PART}_${SLOT}.img not produced — check 'unsuper $IMG --list' for exact names"; }
  ls -l "$OUT/${PART}_${TAG}.img"; file "$OUT/${PART}_${TAG}.img"
elif command -v lpunpack >/dev/null 2>&1; then
  (( SPARSE )) && die "lpunpack needs raw input — unsuper (pip) handles sparse, or simg2img first."
  disk_check "$OUT" 8
  DST="$OUT/${PART}_${TAG}.img"
  log "lpunpack --partition=${PART}_${SLOT} $IMG -> $DST"
  lpunpack --partition="${PART}_${SLOT}" "$IMG" "$DST"
  ls -l "$DST"; file "$DST"
else
  die "need unsuper (pip3 install unsuper) or lpunpack. Run 00-deps-debian.sh."
fi
log "done → $OUT/${PART}_${TAG}.img"
