#!/usr/bin/env bash
# 04-compare-trees.sh — diff T1101 stock vs T1103 donor without needing full images.
# Works off Tier-0 dumps (filelists + build.props + fstabs + vintf) OR live dirs.
# Usage:
#   bash 04-compare-trees.sh port/dumps/t1101 port/dumps/t1103 > compare.txt
#   bash 04-compare-trees.sh work/sys_t1101 work/sys_t1103 --dirs > compare.txt
set -euo pipefail
. "$(dirname "$0")/lib.sh"
A="${1:?usage: 04-compare-trees.sh <t1101dir> <t1103dir> [--dirs]}"
B="${2:?usage: 04-compare-trees.sh <t1101dir> <t1103dir> [--dirs]}"
MODE="${3:-}"
say() { echo; echo "===== $* ====="; }
if [[ "$MODE" == "--dirs" ]]; then
  say "file presence diff (donor-only files = HiOS16 additions, review before keeping)"
  diff -rq "$A" "$B" | head -100 || true
  say "common text-file content diff (props/rc/xml, first 200 lines)"
  diff -r -u --exclude='*.so' --exclude='*.ko' --exclude='*.bin' --exclude='*.img' --exclude='*.apex' "$A" "$B" | head -200 || true
  exit 0
fi
say "lpdump diff"; diff -u "$A/lpdump.txt" "$B/lpdump.txt" | head -80 || true
say "first-stage fstab diff (boot-critical)"; diff -u "$A/fstab.mt6789" "$B/fstab.mt6789" | head -80 || true
say "build.prop key diffs"
for p in system-build system_ext-build product-build vendor-build; do
  [[ -f "$A/build-props/$p.prop" && -f "$B/build-props/$p.prop" ]] || { echo "-- $p: missing on one side, skip"; continue; }
  echo "--- $p"; diff -u "$A/build-props/$p.prop" "$B/build-props/$p.prop" | grep -E '^[+-].*ro\.(product|build|sf|surface|vendor|system)' | head -40 || true
done
say "density/fingerprint lines (the two most common boot-UI breakers)"
grep -h -E 'lcd_density|build.fingerprint|product.device|build.product' "$A"/build-props/*.prop 2>/dev/null | sort | sed 's/^/[t1101] /' || true
grep -h -E 'lcd_density|build.fingerprint|product.device|build.product' "$B"/build-props/*.prop 2>/dev/null | sort | sed 's/^/[t1103] /' || true
say "vintf manifest diff"; diff -u "$A/vintf/manifest.xml" "$B/vintf/manifest.xml" | head -60 || true
say "overlay lists"; diff -u "$A/overlays.txt" "$B/overlays.txt" | head -40 || true
say "filelist-only-in-donor (system, top 60 — audit each before keeping)"
if [[ -f "$A/filelists/system.txt" && -f "$B/filelists/system.txt" ]]; then
  comm -13 <(awk '{print $3}' "$A/filelists/system.txt"|sort) <(awk '{print $3}' "$B/filelists/system.txt"|sort) | head -60
fi
echo; echo "Full report saved by caller. Next: 06-patch-props.sh applies the mechanical prop fixes."
