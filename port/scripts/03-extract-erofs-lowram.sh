#!/usr/bin/env bash
# 03-extract-erofs-lowram.sh — extract ONE erofs/ext4 partition image to a dir.
# Usage: bash 03-extract-erofs-lowram.sh <partition.img> <outdir>
# Handles sparse automatically (streaming convert, deletes temp). One partition at a time.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
IMG="${1:?usage: 03-extract-erofs-lowram.sh <partition.img> <outdir>}"; need_file "$IMG"
OUT="${2:?usage: 03-extract-erofs-lowram.sh <partition.img> <outdir>}"
ram_check 1500; disk_check "$(dirname "$OUT")" 15
RAW="$IMG"
if head -c 4 "$IMG" | od -A n -t x1 | grep -q '3a ff 26 ed'; then
  need simg2img; RAW="$(mktemp --suffix=.raw)"; log "sparse detected → $RAW"
  simg2img "$IMG" "$RAW"
fi
FSTYPE="$(blkid -o value -s TYPE "$RAW" 2>/dev/null || file -b "$RAW")"
log "fstype: $FSTYPE"
mkdir -p "$OUT"
case "$FSTYPE" in
  *erofs*|*EROFS*)
    # fsck.erofs --extract is the documented path; dump.erofs -x is the fallback.
    # (pipefail from lib.sh makes sure a failed first attempt reaches the fallback.)
    if command -v fsck.erofs >/dev/null 2>&1; then
      fsck.erofs --extract="$OUT" "$RAW" 2>&1 | tail -3 || \
      dump.erofs -x -i "$RAW" -o "$OUT" 2>&1 | tail -3 || true
    else
      need dump.erofs
      dump.erofs -x -i "$RAW" -o "$OUT" 2>&1 | tail -3 || true
    fi
    [[ -n "$(ls -A "$OUT" 2>/dev/null)" ]] || die "extraction produced EMPTY dir — check tool output above"
    ;;
  *ext4*|*ext2*)
    log "ext4: debugfs/mount extract"
    if command -v debugfs >/dev/null 2>&1; then
      debugfs -R "rdump / $OUT" "$RAW" 2>&1 | tail -3 || true
    else
      MNT="$(mktemp -d)"; sudo mount -o ro,loop "$RAW" "$MNT" && cp -a "$MNT/." "$OUT/" && sudo umount "$MNT"; rmdir "$MNT"
    fi
    ;;
  *) die "unknown fstype ($FSTYPE). Try: fsck.erofs $RAW ; blkid $RAW ; or extract in DNA-Android." ;;
esac
[[ "$RAW" != "$IMG" ]] && rm -f "$RAW"
log "extracted → $OUT ($(du -sh "$OUT" | cut -f1)). Record: (cd $OUT && find . -printf '%M %s %p\n'|sort) > filelists/<part>.txt"
