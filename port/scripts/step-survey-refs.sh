#!/usr/bin/env bash
# step-survey-refs.sh — small BOUNDED follow-up (~120 lines max): tr_product/etc,
# system_dlkm listing, /odm|/system_dlkm|new-tr references, stamp test, T1101
# odm-in-vendor peek. Full output also in ~/survey-refs.txt (paste remainder
# from there if chat cuts: sed -n '120,240p' ~/survey-refs.txt).
# Usage: bash port/scripts/step-survey-refs.sh
set -euo pipefail
. "$(dirname "$0")/lib.sh"
set +o pipefail  # surveys preview long lists with | head: SIGPIPE must not kill the script
BASE="${BASE:-$HOME/hios-port}"
WORK="$BASE/work"; TREES="$BASE/trees"
[[ -d "$TREES/donor-system" ]] || die "trees missing — run step-extract-and-survey.sh first"
echo "===== 1. donor tr_product: apps + etc ====="
ls "$TREES/donor-tr_product/app" "$TREES/donor-tr_product/priv-app" 2>/dev/null || echo "(missing)"
find "$TREES/donor-tr_product/etc" -maxdepth 2 2>/dev/null | head -30
echo; echo "===== 2. donor system_dlkm ====="
find "$TREES/donor-system_dlkm" 2>/dev/null | head -30; du -sh "$TREES/donor-system_dlkm"
echo; echo "===== 3. refs in donor system-side etc ====="
SS="$TREES/donor-system/system/etc $TREES/donor-system_ext/etc $TREES/donor-product/etc $TREES/donor-tr_product/etc"
echo "--- files mentioning /odm/:"; grep -rl '/odm/' $SS 2>/dev/null | head -15 || echo "(none)"
echo "--- unique /odm/ paths:"; grep -rh -o "/odm/[^\"' :]*" $SS 2>/dev/null | sort -u | head -20 || echo "(none)"
echo "--- files mentioning system_dlkm:"; grep -rl 'system_dlkm' $SS 2>/dev/null | head -15 || echo "(none)"
echo "--- files mentioning tr_misc|tr_manifest|tr_overlayfs:"; grep -rl -E 'tr_misc|tr_manifest|tr_overlayfs' $SS 2>/dev/null | head -15 || echo "(none)"
echo "--- wait/mount lines for those:"; grep -rhn -E '(^| )(wait|mount)[^:]*(:.*)?(/odm|system_dlkm|tr_misc|tr_manifest|tr_overlayfs)' $SS 2>/dev/null | head -15 || echo "(none)"
echo; echo "===== 4. stamp-survival test (SELinux xattr + owner + mode) ====="
command -v getfattr >/dev/null 2>&1 || { log "installing attr…"; sudo apt-get install -y -qq attr 2>&1 | tail -1 || true; }
MNT="$(mktemp -d)"
if sudo mount -o ro,loop "$WORK/system_t1103.img" "$MNT" 2>/dev/null; then
  for rel in system/build.prop init; do
    O="$MNT/$rel"; X="$TREES/donor-system/$rel"
    if [[ -e "$O" && -e "$X" ]]; then
      echo "--- $rel"
      echo "  original : $(getfattr -d -m security.selinux --absolute-names "$O" 2>&1 | tr '\n' ' ') [$(stat -c '%a %u %g' "$O")]"
      echo "  extracted: $(getfattr -d -m security.selinux --absolute-names "$X" 2>&1 | tr '\n' ' ') [$(stat -c '%a %u %g' "$X")]"
    else echo "--- $rel (missing on one side, skip)"; fi
  done
  sudo umount "$MNT"; rmdir "$MNT"
else
  echo "MOUNT-FAILED (no EROFS loop support?)"; rmdir "$MNT"
fi
echo; echo "===== 5. T1101 odm-in-vendor + camera tunings location ====="
echo "--- stock-vendor/odm/etc:"; ls "$TREES/stock-vendor/odm/etc" 2>/dev/null | head -15 || echo "(missing)"
echo "--- stock vendor libCamera_* count:"; find "$TREES/stock-vendor/lib64" "$TREES/stock-vendor/lib" -maxdepth 1 -name 'libCamera_*' 2>/dev/null | wc -l
echo "--- stock vendor vintf:"; ls "$TREES/stock-vendor/etc/vintf" 2>/dev/null | head -8 || echo "(missing)"
log "refs survey done — $(date). If paste cut off: sed -n '120,240p' ~/survey-refs.txt"
