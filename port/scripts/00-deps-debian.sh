#!/usr/bin/env bash
# 00-deps-debian.sh — install everything port/scripts needs on Debian + set up swap.
# Run once. Safe to re-run.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
log "installing packages (needs sudo)…"
sudo apt-get update -qq
sudo apt-get install -y -qq \
  android-sdk-libsparse-utils lptools 2>/dev/null \
  || sudo apt-get install -y -qq brotli lz4 zstd simg2img img2simg 2>/dev/null \
  || true
# Fallback set that exists on stock Debian:
sudo apt-get install -y -qq \
  git curl wget python3 file gdisk e2fsprogs f2fs-tools \
  brotli lz4 zstd unzip zip xz-utils device-tree-compiler \
  erofs-utils avbtool 2>/dev/null || {
  log "some packages missing from apt (normal on minimal Debian); installing core set…"
  sudo apt-get install -y -qq git curl wget python3 file e2fsprogs brotli lz4 zstd unzip zip xz-utils
}
# lp* tools: prefer AOSP builds if apt lacks them
if ! command -v lpdump >/dev/null 2>&1; then
  log "lpdump/lpunpack/lpmake not in apt — fetch static builds is a manual step."
  log "Options: (a) pipx: pip install lp-tools (b) copy from Android SDK platform-tools (c) build from AOSP system/extras."
  log "DNA-Android can cover unpack/repack until then; inspection scripts that need lpdump will tell you."
fi
command -v simg2img >/dev/null 2>&1 || log "NOTE: simg2img missing — DNA-Android 'convert image formats' covers this."
command -v mkfs.erofs >/dev/null 2>&1 || log "NOTE: mkfs.erofs missing (package erofs-utils) — needed for rebuild step."
# swap for 4GB box
if ! swapon --show | grep -q .; then
  log "no swap detected — creating 8G /swapfile…"
  sudo fallocate -l 8G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
  echo 10 | sudo tee /proc/sys/vm/swappiness >/dev/null || true
  log "swap on. Add '/swapfile none swap sw 0 0' to /etc/fstab to keep it."
else
  log "swap already active:"
  swapon --show
fi
free -h; df -h .
log "done. Missing-tool notes above are non-fatal; each script checks what it needs."
