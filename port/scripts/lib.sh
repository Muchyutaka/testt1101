#!/usr/bin/env bash
# Shared helpers for port/scripts/*. Single source for logging + low-RAM guards.
# shellcheck disable=SC2034
set -euo pipefail
PORT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log()  { printf '[port] %s\n' "$*"; }
die()  { printf '[port][ERROR] %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing tool: $1 (run 00-deps-debian.sh)"; }
need_file() { [[ -f "$1" ]] || die "missing file: $1"; }
# Warn (not fail) when free RAM+swap looks too small for the job.
ram_check() { # $1 = min MB recommended
  local avail
  avail="$(free -m | awk '/^Mem:/{m=$7} /^Swap:/{s=$3} END{print m+s+0}')" || avail=0
  if (( avail < $1 )); then
    log "WARNING: free RAM+swap ${avail}MB < recommended ${1}MB — close apps, enable swap, work one partition at a time."
  fi
}
disk_check() { # $1 = dir, $2 = min GB
  local avail
  avail="$(df -BG "$1" | awk 'NR==2{gsub("G",""); print $4}')" || avail=0
  if (( avail < $2 )); then
    die "only ${avail}G free in $1, need >= ${2}G. Free disk before continuing."
  fi
}
