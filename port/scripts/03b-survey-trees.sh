#!/usr/bin/env bash
# 03b-survey-trees.sh — summarize extracted partition trees (layout-agnostic).
# Full app/file lists go to <trees-dir>/../survey-*.txt; key findings print here.
# Usage: bash 03b-survey-trees.sh <trees-dir>
set -euo pipefail
. "$(dirname "$0")/lib.sh"
T="${1:?usage: 03b-survey-trees.sh <trees-dir>}"
OUTD="$(dirname "$T")"
echo "=== tree sizes + top level ==="
for d in "$T"/*/; do
  n="$(basename "$d")"
  echo "--- $n ($(du -sh "$d" | cut -f1))"; ls "$d"
  (cd "$d" && find . | sort) > "$OUTD/survey-filelist-$n.txt"
done
echo "full file lists saved: $OUTD/survey-filelist-*.txt"
echo; echo "=== build.prop key lines ==="
find "$T" -maxdepth 3 -name build.prop | sort | while read -r f; do
  echo "--- $f"
  grep -E 'ro\.sf\.lcd_density|ro\.build\.fingerprint|ro\.system\.build\.fingerprint|ro\.product\.(device|name|model|brand|manufacturer)|ro\.build\.product|ro\.build\.description' "$f" || echo "(no key lines)"
done
echo; echo "=== overlay dirs (RROs) ==="
find "$T" -maxdepth 5 -type d -name overlay | sort | while read -r d; do
  echo "--- $d"; ls "$d"
done
echo; echo "=== app / priv-app counts ==="
find "$T" -maxdepth 4 -type d \( -name app -o -name priv-app \) | sort | while read -r d; do
  echo "$d: $(ls "$d" | wc -l) entries"
done
echo; echo "=== donor odm + tr_product app names (port decision-critical) ==="
for d in "$T"/donor-odm "$T"/donor-tr_product "$T"/donor-system_dlkm; do
  [[ -d "$d" ]] || continue
  echo "--- $d"
  find "$d" -maxdepth 4 -type d \( -name app -o -name priv-app \) | sort | while read -r a; do
    echo "  [$a]"; ls "$a"
  done
  find "$d" -maxdepth 2 | head -25
done
echo; echo "=== permissions/sysconfig xml counts ==="
for d in "$T"/*/; do
  n="$(basename "$d")"
  c1="$(find "$d" -path '*permissions/*.xml' 2>/dev/null | wc -l)"
  c2="$(find "$d" -path '*sysconfig/*.xml' 2>/dev/null | wc -l)"
  echo "$n: permissions=$c1 sysconfig=$c2"
done
log "survey done."
