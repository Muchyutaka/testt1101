#!/usr/bin/env bash
# 00-deps-debian.sh — install everything port/scripts needs on Debian + set up swap.
# Run once. Safe to re-run.
# NOTE: Debian apt has NO lpdump/lpunpack/lpmake (only sparse tools). We use
# `unsuper` (pure python, pip) instead — it reads sparse super.img directly.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
log "installing packages (needs sudo)…"
sudo apt-get update -qq
# Install ONE package per call so a single missing name can't poison the line.
for pkg in git curl wget python3 python3-pip file gdisk e2fsprogs f2fs-tools \
           brotli lz4 zstd unzip zip xz-utils device-tree-compiler \
           erofs-utils android-sdk-libsparse-utils python3-numpy; do
  if sudo apt-get install -y -qq "$pkg" >/dev/null 2>&1; then log "  ok: $pkg";
  else log "  skip (not in apt): $pkg"; fi
done
# unsuper: lister/extractor for super.img (sparse-safe, replaces lpdump/lpunpack)
export PATH="$HOME/.local/bin:$PATH"
if ! command -v unsuper >/dev/null 2>&1; then
  log "installing unsuper via pip…"
  pip3 install --break-system-packages -q unsuper numpy 2>&1 | tail -2 || \
  pip3 install --user -q unsuper numpy 2>&1 | tail -2 || \
  log "pip failed — run manually: pip3 install unsuper numpy (then re-run this script)"
  # pip --user lands in ~/.local/bin which may not be on PATH — link it system-wide
  if [[ -f "$HOME/.local/bin/unsuper" ]] && ! command -v unsuper >/dev/null 2>&1; then
    sudo ln -sf "$HOME/.local/bin/unsuper" /usr/local/bin/unsuper
  fi
fi
# swap — check /proc/swaps ('swapon' alone may not be in user PATH)
if [[ "$(wc -l < /proc/swaps)" -le 1 ]]; then
  log "no swap active — creating 8G /swapfile…"
  sudo fallocate -l 8G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
  echo 10 | sudo tee /proc/sys/vm/swappiness >/dev/null || true
  log "swap on. Persist across reboots: echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab"
else
  log "swap already active:"; cat /proc/swaps
fi
echo; log "tool status (missing ones show [--]):"
for t in unsuper simg2img img2simg dump.erofs fsck.erofs mkfs.erofs avbtool lpdump lpunpack lpmake adb fastboot; do
  if command -v "$t" >/dev/null 2>&1; then echo "  [OK] $t"; else echo "  [--] $t"; fi
done
free -h; df -h .
log "done. unsuper+simg2img+mkfs.erofs are the must-haves; avbtool/lp* gaps are covered by DNA-Android + fastbootd."
