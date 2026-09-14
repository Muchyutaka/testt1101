#!/usr/bin/env bash
# 01-inspect-super.sh — read-only metadata dump of a super.img.
# Prefers `unsuper --list` (reads sparse directly, no lpdump needed).
# For SPARSE images unsuper may stage a full raw temp copy → we refuse to run
# unless free disk covers raw-size + 2GB margin (never fill a 94% disk).
# Usage: bash 01-inspect-super.sh <super.img>
set -euo pipefail
. "$(dirname "$0")/lib.sh"
IMG="${1:?usage: 01-inspect-super.sh <super.img>}"; need_file "$IMG"
EXPECTED_SIZE=9126805504
echo "== file =="; file "$IMG"; ls -l "$IMG"
SPARSE=0
if head -c 4 "$IMG" | od -A n -t x1 | grep -q '3a ff 26 ed'; then SPARSE=1; fi
# raw size if sparse (from libmagic "Total of N 4096-byte output blocks")
RAW_BYTES=0
if (( SPARSE )); then
  BLOCKS="$(file -b "$IMG" | grep -oP 'Total of \K[0-9]+' || echo 0)"
  RAW_BYTES=$(( BLOCKS * 4096 ))
  echo; echo "sparse: yes — raw would be ~$(( RAW_BYTES / 1024 / 1024 )) MiB"
else
  echo; echo "sparse: no (raw) — safe to inspect, near-zero disk use"
fi
if command -v unsuper >/dev/null 2>&1; then
  if (( SPARSE )); then
    FREE_KB="$(df -k . | awk 'NR==2{print $4}')"
    NEED_KB=$(( RAW_BYTES / 1024 + 2 * 1024 * 1024 ))
    if (( FREE_KB < NEED_KB )); then
      echo; echo "== partitions: SKIPPED (disk guard) =="
      echo "unsuper may stage a ~$(( RAW_BYTES/1024/1024 )) MiB temp copy; free here: $(( FREE_KB/1024 )) MiB."
      echo "Free space (need ~$(( NEED_KB/1024 )) MiB) and re-run — or list partitions with DNA-Android on the phone."
      echo "(Tiny-file fallback: check partition_info.json + *.map in the firmware folder.)"
      exit 0
    fi
  fi
  echo; echo "== partitions (unsuper --list) =="
  T="$(mktemp -d -p . unsuper-tmp.XXXXXX)"; export TMPDIR="$T"
  unsuper "$IMG" --list --temp-dir "$T" 2>&1 | head -60 || true
  rm -rf "$T"
elif command -v lpdump >/dev/null 2>&1 && (( ! SPARSE )); then
  echo; echo "== lpdump =="; lpdump "$IMG" | head -60 || true
else
  echo; echo "no unsuper/lpdump, or sparse without unsuper."
  echo "Install: pip3 install unsuper (done by 00-deps-debian.sh)."
fi
if command -v avbtool >/dev/null 2>&1; then
  echo; echo "== avbtool =="; avbtool info_image --image "$IMG" 2>&1 | head -10 || true
fi
echo; echo "== T1101 expected =="
echo "super size: $EXPECTED_SIZE group: main partitions: system system_ext product vendor vendor_dlkm odm_dlkm + tr_mi tr_theme tr_region tr_company tr_carrier tr_product tr_preload"
