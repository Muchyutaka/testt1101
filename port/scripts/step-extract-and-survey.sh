#!/usr/bin/env bash
# step-extract-and-survey.sh — ONE-SHOT, shell-proof (runs under `bash script.sh`
# from fish/zsh/bash alike): extract donor extras + stock trio, dump donor
# fstab, extract all trees, run survey.
# Usage: bash port/scripts/step-extract-and-survey.sh
# Paths default to the ~/hios-port layout; override via env:
#   STOCK_RAW=... DONOR_RAW=... DONOR_FW=... WORK=... TREES=... VB=... TMPDIR=...
set -euo pipefail
. "$(dirname "$0")/lib.sh"
REPO_ROOT="$(cd "$PORT_ROOT/.." && pwd)"
BASE="${BASE:-$HOME/hios-port}"
STOCK_RAW="${STOCK_RAW:-$BASE/stock/Tecno-MegaPad-11-T1101-27/super_raw.img}"
DONOR_RAW="${DONOR_RAW:-$BASE/donor-super.raw}"
DONOR_FW="${DONOR_FW:-$BASE/donor/R2-Tecno-Megapad-2-T1103}"
WORK="${WORK:-$BASE/work}"
TREES="${TREES:-$BASE/trees}"
VB="${VB:-$BASE/vb_t1103}"
export TMPDIR="${TMPDIR:-$BASE/tmp}"
mkdir -p "$WORK" "$TREES" "$VB" "$TMPDIR"
S="$PORT_ROOT/scripts"
need_file "$STOCK_RAW"; need_file "$DONOR_RAW"; need_file "$DONOR_FW/vendor_boot.img"
log "donor extras + stock trio…"
for p in odm tr_product system_dlkm; do bash "$S/02-unpack-one.sh" "$DONOR_RAW" "$p" "$WORK/" a; done
for p in system system_ext product; do bash "$S/02-unpack-one.sh" "$STOCK_RAW" "$p" "$WORK/" a; done
log "donor vendor_boot fstab…"
python3 "$REPO_ROOT/tools/unpack_vendor_boot.py" "$DONOR_FW/vendor_boot.img" "$VB"
find "$VB" -name 'fstab*' -exec echo "--- {}" \; -exec cat {} \;
log "extract trees (long step)…"
rm -rf "$TREES"/donor-* "$TREES"/stock-*
for p in system system_ext product odm tr_product system_dlkm; do
  bash "$S/03-extract-erofs-lowram.sh" "$WORK/${p}_t1103.img" "$TREES/donor-$p"
done
for p in system system_ext product; do
  bash "$S/03-extract-erofs-lowram.sh" "$WORK/${p}_t1101.img" "$TREES/stock-$p"
done
bash "$S/03b-survey-trees.sh" "$TREES" 2>&1 | tee "$HOME/survey.txt"
log "ALL DONE. Send back the fstab section + ~/survey.txt contents."
