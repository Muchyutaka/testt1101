#!/usr/bin/env bash
# 10-collect-logs.sh — pull the full debug bundle over adb (OrangeFox or booted system).
# Usage: bash 10-collect-logs.sh [outdir]   (default: port/logs/<timestamp>)
set -euo pipefail
. "$(dirname "$0")/lib.sh"
need adb
OUT="${1:-$PORT_ROOT/logs/$(date +%F-%H%M)}"; mkdir -p "$OUT"
adb devices -l | tee "$OUT/adb-devices.txt"
adb wait-for-device
grab() { # $1=desc $2=file $3=cmd...
  printf '--- %s ---\n' "$1"; "${@:3}" > "$2" 2>"$2.err" && rm -f "$2.err" || echo "(failed, see $2.err)";
}
grab getprop        "$OUT/getprop.txt"        adb shell getprop
grab cmdline        "$OUT/cmdline.txt"        adb shell cat /proc/cmdline
grab last_kmsg      "$OUT/last_kmsg.txt"      adb shell cat /proc/last_kmsg
grab dmesg          "$OUT/dmesg.txt"           adb shell dmesg
grab logcat-all     "$OUT/logcat-all.txt"     adb logcat -b all -d
grab logcat-crash   "$OUT/logcat-crash.txt"   adb logcat -b main,system,crash -d
grab mount          "$OUT/mount.txt"          adb shell mount
grab mapper         "$OUT/mapper.txt"         adb shell ls -l /dev/block/mapper
grab overlays       "$OUT/overlays.txt"       adb shell ls -R /product/overlay /vendor/overlay
adb pull /sys/fs/pstore/console-ramoops-0 "$OUT/ramoops-0.txt" || true
adb pull /sys/fs/pstore/dmesg-ramoops-0   "$OUT/dmesg-ramoops.txt" || true
adb pull /tmp/recovery.log "$OUT/recovery.log" || true
adb shell lpdump > "$OUT/lpdump-device.txt" 2>/dev/null || true
echo; log "bundle → $OUT"
ls -l "$OUT"
echo; log "triage greps (see README §5.3):"
echo "  grep -i -E 'fs_mgr|failed to mount|vbmeta|avb|digest' $OUT/dmesg.txt $OUT/logcat-all.txt | head"
echo "  grep -i -E 'avc: denied|FATAL EXCEPTION|surfaceflinger|hwcomposer|zygote' $OUT/logcat-all.txt | head"
