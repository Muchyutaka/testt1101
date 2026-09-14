#!/usr/bin/env bash
# step-survey-deep.sh — follow-up survey on EXISTING trees (no re-extraction
# except stock vendor for reference). Answers: device props, density, odm
# contents, /odm|/system_dlkm|new-tr references, xattr/permission survival.
# Usage: bash port/scripts/step-survey-deep.sh
set -euo pipefail
. "$(dirname "$0")/lib.sh"
BASE="${BASE:-$HOME/hios-port}"
WORK="$BASE/work"; TREES="$BASE/trees"
[[ -d "$TREES/donor-system" ]] || die "trees missing — run step-extract-and-survey.sh first"
S="$PORT_ROOT/scripts"
log "stock vendor tree (reference: build.prop + vintf)…"
rm -rf "$TREES/stock-vendor"
bash "$S/03-extract-erofs-lowram.sh" "$WORK/vendor_t1101.img" "$TREES/stock-vendor"
echo; echo "===== A. build.prop FULL (all trees) ====="
for f in $(find "$TREES" -maxdepth 3 -name build.prop | sort); do
  echo "----- $f"; cat "$f"
done
echo; echo "===== B. density + device props (filtered) ====="
grep -rn 'ro\.sf\.lcd_density' "$TREES" --include=build.prop || echo "(no density found)"
grep -rn -E 'ro\.product\.[A-Za-z_.]+\.(device|model|brand|manufacturer|name)=' "$TREES" --include=build.prop | head -40 || echo "(none)"
echo; echo "===== C. donor odm inventory ====="
D="$TREES/donor-odm"
for sub in etc/vconfig etc/vintf etc/init bin firmware; do
  echo "--- odm/$sub"; ls "$D/$sub" 2>/dev/null | head -30 || echo "(missing)"
done
echo "--- odm/etc/selinux"; ls "$D/etc/selinux" 2>/dev/null | head -10 || echo "(missing)"
echo "--- odm/etc/permissions (count + names)"; ls "$D/etc/permissions" 2>/dev/null | head -30; echo "count: $(ls "$D/etc/permissions" 2>/dev/null | wc -l)"
echo "--- odm lib64 .so count:"; find "$D/lib64" "$D/lib" -maxdepth 1 -name '*.so' 2>/dev/null | wc -l
echo "--- odm lib64 .so sample:"; find "$D/lib64" "$D/lib" -maxdepth 1 -name '*.so' 2>/dev/null | head -40
echo "--- donor tr_product apps"; ls "$TREES/donor-tr_product/app" "$TREES/donor-tr_product/priv-app" 2>/dev/null || echo "(missing)"
echo "--- donor system_dlkm content"; find "$TREES/donor-system_dlkm" -maxdepth 3 | head -20
echo; echo "===== D. /odm + /system_dlkm + new-tr references (donor system-side) ====="
SS="$TREES/donor-system/system/etc $TREES/donor-system_ext/etc $TREES/donor-product/etc $TREES/donor-tr_product/etc $TREES/donor-system/init*"
echo "--- files referencing /odm/:"; grep -rl '/odm/' $SS 2>/dev/null | head -20 || echo "(none)"
echo "--- unique /odm/ paths:"; grep -rh -o '/odm/[^"'\'' :]*' $SS 2>/dev/null | sort -u | head -30 || echo "(none)"
echo "--- files referencing /system_dlkm:"; grep -rl 'system_dlkm' $SS 2>/dev/null | head -20 || echo "(none)"
echo "--- files referencing tr_misc|tr_manifest|tr_overlayfs:"; grep -rl -E 'tr_misc|tr_manifest|tr_overlayfs' $SS 2>/dev/null | head -20 || echo "(none)"
echo "--- wait/mount lines for those:"; grep -rhn -E '(wait|mount)[^\n]*(tr_misc|tr_manifest|tr_overlayfs|system_dlkm|/odm/)' $SS 2>/dev/null | head -20 || echo "(none)"
echo; echo "===== E. stamp-survival test (SELinux xattr + owner + mode) ====="
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
  echo "MOUNT-FAILED (kernel lacks EROFS loop mount?) — rmdir $MNT"
  rmdir "$MNT"
fi
log "deep survey done."
