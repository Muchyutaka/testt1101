#!/usr/bin/env bash
# 01-inspect-super.sh — read-only metadata dump of a super.img. Tiny RAM (~50MB).
# Usage: bash 01-inspect-super.sh <super.img> [slot-suffix]
# Compares against T1101 known-good values from BoardConfig.mk.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
IMG="${1:?usage: 01-inspect-super.sh <super.img>}"; need_file "$IMG"
SLOT="${2:-a}"
EXPECTED_SIZE=9126805504
echo "== file =="; file "$IMG"; ls -l "$IMG"
echo; echo "== sparse? =="
head -c 4 "$IMG" | od -A n -t x1 | grep -q '3a ff 26 ed' && echo "ANDROID SPARSE — convert with simg2img before lpdump" || echo "raw (or other) — OK for lpdump"
if command -v lpdump >/dev/null 2>&1; then
  echo; echo "== lpdump =="
  # lpdump needs raw; if sparse, dump to temp (needs ~9G disk, low RAM, streaming)
  T="$IMG"
  if head -c 4 "$IMG" | od -A n -t x1 | grep -q '3a ff 26 ed'; then
    command -v simg2img >/dev/null 2>&1 || die "sparse image but no simg2img. Convert in DNA-Android first."
    disk_check . 12
    T="$(mktemp --suffix=.raw)"; log "converting sparse→raw: $T (one pass, then deleted)"
    simg2img "$IMG" "$T"
  fi
  lpdump "$T" || lpdump --slot="$SLOT" "$T" || true
  [[ "$T" != "$IMG" ]] && rm -f "$T"
else
  echo; echo "lpdump not installed — install it (00-deps) or use DNA-Android 'extract dynamic partitions' to list partitions."
fi
if command -v avbtool >/dev/null 2>&1; then
  echo; echo "== avbtool (vbmeta footer, if any) =="
  avbtool info_image --image "$IMG" 2>&1 | head -30 || true
fi
echo; echo "== T1101 expected =="
echo "super size: $EXPECTED_SIZE group: main partitions: system system_ext product vendor vendor_dlkm odm_dlkm + tr_mi tr_theme tr_region tr_company tr_carrier tr_product tr_preload"
echo "== hint =="
echo "Save: bash 01-inspect-super.sh super.img > inspect.txt ; then diff -u inspect-t1101.txt inspect-t1103.txt"
