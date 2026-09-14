# HiOS 16 (MegaPad 2 T1103) → MegaPad 11 (T1101) Port Guide

Target: **TECNO MegaPad 11 (T1101)** — Helio G99 / mt6789 (MT8781), stock Android 14
Donor: **TECNO MegaPad 2 (T1103)** — same Helio G99/MT8781, HiOS 16 / Android 16
Recovery: OrangeFox in this repo (recovery → `vendor_boot`, stock `boot.img` untouched)
Strategy: **minimal first boot** — keep T1101 kernel + DTB/DTBO + vendor + firmware,
take only HiOS 16 **system framework + apps** from T1103.

> Secondary ref MegaPad SE 2 (Helio G88) is a different SoC — use it only to
> eyeball a HiOS 16 APK or overlay, never as a base.

---

## 0. Ground truth from this tree (read this first)

These values are already proven on T1101 hardware — the port must match them,
not the donor's:

| Item | T1101 value (this repo) |
|---|---|
| SoC / platform | `mt6789` (Helio G99 = MT8781), kernel 5.10 GKI, boot header v4 |
| Super size | `9126805504` bytes, group `main` (`BoardConfig.mk`) |
| Dynamic partitions | `system, system_ext, product, vendor, vendor_dlkm, odm_dlkm` + Transsion `tr_mi, tr_theme, tr_region, tr_company, tr_carrier, tr_product, tr_preload` (see `recovery/root/system/etc/recovery.fstab`) |
| FS types | `system/system_ext/product/vendor` = EROFS, `vendor_dlkm/odm_dlkm` = ext4 |
| Slots | Virtual A/B, `slotselect` everywhere, no dedicated recovery partition |
| Recovery fstab | `recovery/root/system/etc/recovery.fstab` |
| First-stage fstab | `recovery/root/first_stage_ramdisk/fstab.mt6789` (this is the boot-critical one) |
| Panels (90 Hz) | `jd9366ts_..._x1101`, `icnl9951r_..._x1101` kernel modules |
| Touch | `adaptive-ts.ko` (patched), OTG `tran_otg.ko` (patched), see `tools/` |
| Fingerprint | `TECNO/TSSI/T1101:14/UP1A.231005.007/260410V1046:user/release-keys` |

Golden rule: **T1101's first-stage fstab + kernel + DTB/DTBO + vendor_boot ramdisk
win every argument against the donor.** If the donor image disagrees, the donor
gets edited, never the T1101 boot chain — at least until first boot works.

---

## 1. Reusing recovery configs (fstab / mount points / init)

### 1.1 Which fstab is which

There are 3 fstabs in an MTK Virtual-A/B device. Confusing them is the #1
cause of port bootloops:

1. **First-stage fstab** (`fstab.mt6789` in `vendor_boot` ramdisk) — mounted by
   `init` first stage. Controls `system/vendor/product/system_ext/vendor_dlkm/odm_dlkm`
   + `metadata` + `vbmeta_*` + all the `tr_*` Transsion partitions. **This file
   decides whether you boot at all.** Source of truth:
   `recovery/root/first_stage_ramdisk/fstab.mt6789`.
2. **Recovery fstab** (`recovery/root/system/etc/recovery.fstab`) — used by
   OrangeFox/TWRP only. Same partition list, simpler flags. Use it to verify
   OrangeFox can mount every logical partition of your *ported* super before
   you ever try to boot it.
3. **System fstab** (inside `vendor/etc/fstab.*` of the booted ROM) — used for
   late-mount. On Transsion devices it is normally identical to the first-stage
   one. Keep the T1101 copy.

### 1.2 Adapting the T1103 image to the T1101 layout

Do NOT flash the T1103 `super.img` as-is. Even on the same SoC, Transsion
changes group sizes, `tr_*` partition sets, and extents between models. Instead:

```
T1101 super (rebuilt, same size/group as stock)
├── system      ← T1103 (HiOS 16)  + T1101 props/overlays patched in
├── system_ext  ← T1103 (HiOS 16)  + T1101 props patched in
├── product     ← T1103 (HiOS 16)  + T1101 overlays checked
├── vendor      ← T1101 STOCK (keep 100% for first boot)
├── vendor_dlkm ← T1101 STOCK (kernel modules must match T1101 kernel)
├── odm_dlkm    ← T1101 STOCK
└── tr_*        ← T1101 STOCK (all 7: mi/theme/region/company/carrier/product/preload)
```

Steps:

1. Dump both supers (`unsuper super.img --list`, script: `port/scripts/01-inspect-super.sh` —
   Debian apt has no lpdump, so `unsuper` from pip is our lister/extractor).
   Compare group sizes, partition sizes, and `tr_*` presence.
2. Unpack **one partition at a time** (never the whole super on 4 GB RAM):
   `unsuper super_t1103.img work/ -p system_a -j2` (script: `02-unpack-one.sh`).
3. Rebuild with `lpmake` using **T1101's** `BOARD_SUPER_PARTITION_SIZE`,
   group `main`, and slot suffixes — only swapping the 3 image files
   (script: `port/scripts/05-minimal-port.sh`).
4. Before flashing, boot OrangeFox and check every mount:
   `adb shell twrp mount /system && ls /system/system/app` etc., or just
   Install → Mount in the GUI. If OrangeFox (which uses the recovery fstab
   above) can't mount it, Android won't either.
5. Keep `slotselect` + `logical` + `wait` flags exactly as in the T1101
   fstabs. Dropping `slotselect` on a Virtual-A/B device = instant bootloop.

### 1.3 init / ramdisk reuse

- Keep the **entire T1101 `vendor_boot` ramdisk**: `init.recovery.mt6789.rc`
  flow, `fstab.mt6789`, `modules.load.recovery`, `otgd.sh`, keymint/gatekeeper
  services. The donor's ramdisk has T1103 paths/services you don't want.
- Keep T1101 `boot.img` (kernel + generic ramdisk) 100% stock for first boot.
- Only *after* first boot works, diff donor `init.*.rc` / `ueventd*.rc` for
  HiOS 16-only services you actually need, and cherry-pick lines — never
  wholesale replace.
- Panel/touch/OTG kernel modules listed in `modules.load.recovery` (the two
  `..._x1101` panel drivers, `adaptive-ts`, `tran_otg`) must stay T1101. A
  T1103 panel driver will give you a black screen even if everything else is
  perfect.

---

## 2. Low-RAM workflow (Debian 4 GB)

### 2.1 Ground rules

- Super is ~8.5 GB raw. Unpacked + working copies need **25–30 GB free disk**.
  Check first: `df -h .` — disk kills more ports than RAM does.
- Add swap before anything big (do once):
  `sudo fallocate -l 8G /swapfile && sudo chmod 600 /swapfile &&
   sudo mkswap /swapfile && sudo swapon /swapfile`
  Plus `echo 10 | sudo tee /proc/sys/vm/swappiness` to prefer RAM but survive spikes.
- Close the browser while running `lpunpack/lpmake/mkfs.erofs`. They are the
  peak-RAM tools.
- If `/tmp` is a small tmpfs (`df -h /tmp` shows ~2G), point temp at the big disk:
  `mkdir -p ~/hios-port/tmp && export TMPDIR=~/hios-port/tmp` (super tools stage
  12 GB+ temp files; the scripts set `--temp-dir` automatically, but raw `unsuper`
  calls need it by hand).
- Work **one partition at a time**, delete/convert intermediates immediately.
- Prefer streaming/convert-in-place: `simg2img in.simg out.raw` then
  `rm in.simg`; never keep sparse + raw + extracted tree for 2 partitions at once.
- `lpmake` needs all *input .img files present* but reads them sequentially —
  fine on 4 GB as long as nothing else hogs RAM. `mkfs.erofs` is the hungriest;
  pass `--workers=1` and avoid `-zlzma` on this box (use `-zlz4`).

### 2.2 What to do where (Debian vs DNA-Android)

| Operation | Do it on | Why |
|---|---|---|
| `lpdump`, size/AVB inspection, `diff` of props/fstabs/file-lists | Debian | instant, scriptable, needs <100 MB RAM |
| `lpunpack` **single** partition | Either (Debian preferred) | DNA works but hides errors; CLI shows them |
| `lpunpack` whole super | Neither — don't do it | OOM + disk hog; always `--partition=` |
| EROFS extract (`dump.erofs/fsck.erofs`) | Debian, one partition at a time | needs erofs-utils; DNA extract is fine as fallback |
| EROFS rebuild (`mkfs.erofs`) | Debian | deterministic flags; needs disk, not RAM |
| `lpmake` final super | Debian | exact size/group control via script |
| `simg2img/img2simg`, `br/lz4/zstd/dat` converts, split/merge sparse | DNA-Android | its strongest feature; saves Debian setup |
| `vbmeta` patch / AVB + verity disable | DNA-Android | one tap; or script `07-avb-disable.sh` on Debian |
| `fstab` quick test edits | DNA-Android for trial, Debian for final | DNA is faster to iterate, Debian keeps the canonical copy |
| APK decompile/patch/recompile, permission patches | DNA-Android | purpose-built; on Debian you'd hand-roll apktool |
| `boot.img` / `vendor_boot` unpack/repack | Debian (`tools/unpack_vendor_boot.py`, magiskboot) | reproducible; DNA as cross-check |
| DTB/DTBO inspect (`dtc -I dtb`) | Debian | DNA can't do this well |
| File-compare + scripted prop edits | Debian | `diff -r`, `grep -r`, `sed`, git diff |
| Flash + log capture | OrangeFox + `adb` (either host) | `port/scripts/10-collect-logs.sh` |

### 2.3 Safe super workflow (step by step, 4 GB-proof)

```bash
# 0. deps + swap (once). NOTE: run all blocks under bash — if your shell is
#    fish (prompt shows `fish:` errors), just type `bash` + Enter first.
bash port/scripts/00-deps-debian.sh

# 1. inspect, don't unpack yet (tiny RAM)
bash port/scripts/01-inspect-super.sh stock/super_t1101.img  > inspect-t1101.txt
bash port/scripts/01-inspect-super.sh donor/super_t1103.img  > inspect-t1103.txt
diff -u inspect-t1101.txt inspect-t1103.txt | less

# 2. pull ONE partition (repeat per partition, deleting intermediates)
bash port/scripts/02-unpack-one.sh stock/super_t1101.img system work/   # → work/system_t1101.img
bash port/scripts/02-unpack-one.sh donor/super_t1103.img system work/   # → work/system_t1103.img

# 3. convert sparse→raw only if file(1) says "sparse", then extract (one at a time)
bash port/scripts/03-extract-erofs-lowram.sh work/system_t1103.img work/sys_t1103

# 4. patch that extracted tree (props/overlays/permissions), rebuild that ONE image
#    mkfs.erofs --workers=1 ...
# 5. repeat for system_ext, product — vendor* + tr_* stay stock, never extracted
# 6. rebuild super from the 3 new + N stock images
bash port/scripts/05-minimal-port.sh work/manifest.json out/super_ported.img
```

Never `lpunpack super.img outdir/` without `--partition` on this laptop.
The script `02-unpack-one.sh` enforces single-partition mode for exactly this reason.

---

## 3. Tool allocation (full matrix)

### DNA-Android (on-device GUI) — use for

- Unpack/repack `super.img`, repack individual dynamic partitions.
- Format converts: `bin/br/lz4/dat/img/zstd`, sparse merge/split.
- Patch `vbmeta`, disable AVB + verification/verity.
- `fstab` trial patches (validate in OrangeFox mount test, then commit to repo).
- APK: decompile → edit resources/permissions → recompile; SafetyNet-file patches.
- `boot.img` quick unpack/repack sanity checks; decrypt/encrypt helpers.

### Debian CLI — use for

- `lpdump` metadata, `avbtool info_image`, `file`, `blkid`, size math.
- T1101-vs-T1103 firmware `diff` (fstab, props, file lists, SELinux contexts).
- `lpunpack --partition`, `lpmake` (exact group/size control).
- EROFS extract/rebuild (`dump.erofs`, `fsck.erofs`, `mkfs.erofs`).
- `boot/vendor_boot` + DTB/DTBO surgery (`unpack_bootimg/mkbootimg/magiskboot/dtc`).
- Scripted, repeatable edits (everything in `port/scripts/`) + git history.

Rule of thumb: **DNA for speed, Debian for truth.** If they disagree about a
partition size, AVB flag, or mount result, believe Debian + OrangeFox, then
re-do the DNA step with corrected inputs.

---

## 4. Files & patches (T1103 → T1101)

Minimal-first-boot order: get it booting with the smallest diff, then fix
peripherals one at a time. Do not "fix" audio/camera/sensors before you have
a boot animation — you'll never know which change broke boot.

### 4.1 Keep from T1101 (do NOT take donor copies)

- `boot.img`: kernel, DTB, generic ramdisk, `fstab`, `init*` — 100% stock.
- `vendor_boot.img`: ramdisk, `fstab.mt6789`, `modules.load*`, `init.*.rc`.
- `dtbo.img`, `vbmeta*` (patched only to disable verification, not replaced).
- `vendor.img`, `vendor_dlkm.img`, `odm_dlkm.img`: all HALs, `.rc`, `.xml`,
  firmware, keylayouts, `vintf/manifest.xml`, SELinux policy.
- All 7 `tr_*` partitions.
- Display/touch: panel DTBO + `*_x1101.ko` panel drivers + `adaptive-ts.ko` +
  `chipone/jadard/novatek` firmware in `vendor/firmware/` + brightness tables.
- `vendor/usr/keylayout/*`, `vendor/etc/vintf/*`, `vendor/etc/fstab.*`,
  `vendor/etc/init/hw/*.rc`, `vendor/build.prop`, `vendor_dlkm/etc/*`.

### 4.2 Take from T1103 (HiOS 16), then patch

- `system.img`: framework, `system/app`, `priv-app`, fonts, permissions XML.
- `system_ext.img`: `system_ext/app`, `priv-app`, frameworks.
- `product.img`: HiOS apps, `product/overlay/*` (RROs — audit each, see below).
- Possibly `product/etc/sysconfig/*`, `product/etc/permissions/*` — but strip
  any `T1103`-hardware-gated entries.

### 4.3 Must-patch list (donor tree → T1101 values)

Text/prop patches (script `06-patch-props.sh` does the mechanical ones):

```
system/system/build.prop, system_ext/etc/build.prop, product/etc/build.prop,
product/build.prop, vendor/build.prop (keep T1101 file, verify):
  ro.product.device / ro.build.product / ro.product.name        → T1101
  ro.product.model / ro.product.brand / ro.product.manufacturer → MegaPad 11 / TECNO / tecno
  ro.product.system.device (etc. per-partition props)           → T1101
  ro.build.fingerprint                                          → T1101 fingerprint (BoardConfig.mk)
  ro.system.build.fingerprint                                   → T1101
  ro.sf.lcd_density                                             → T1101 value (diff donor vs stock first!)
  ro.surface_flinger.* / vendor.display.* / persist.sys.sf.*    → keep T1101
  persist.sys.timezone/locale                                   → keep user, harmless either way
```

Overlays/RROs (`product/overlay`, `vendor/overlay`, `system_ext/overlay`):
each APK whose `AndroidManifest.xml` targets `com.android.systemui` display
config, cutout, or `T1103` device codename must be disabled or replaced with
the T1101 equivalent. Symptom of a missed one: boot animation OK then
SystemUI crash loop. DNA-Android's APK decompile is the fastest way to check
`overlays.xml` + `bool/dimen` values; keep T1101's `display_cutout`,
`status_bar_height`, `navigation_bar`, `config_screenBrightness*` family.

Permissions/features (`etc/permissions/*.xml`, `etc/sysconfig/*.xml`):
keep donor HiOS 16 features, but re-add any T1101-only hardware features the
donor lacks (stylus? hall sensor `line_hall`? exact camera aux IDs?) and drop
T1103-only ones. Diff the two `ls` outputs — don't eyeball.

Init/SEPolicy: donor `system/etc/init/*.rc` + `selinux/*` mostly fine, but any
service pointing at a `/vendor` path that only exists on T1103 must be pointed
at the T1101 path or disabled. Watch `hwservicemanager` + `vintf` manifest
mismatches: `vendor/etc/vintf/manifest.xml` stays T1101, so any donor HAL
client expecting a T1103-only HAL version will spam `E HAL` — that log line
tells you exactly which entry to shim.

Keylayouts/IDC (`vendor/usr/keylayout`, `usr/idc`): T1101 wins wholesale.
Donor copies break volume/power/hall on first boot.

Refresh rate/brightness: 90 Hz + `TW_MAX_BRIGHTNESS=255` panels are driven by
T1101 DTBO + `mediatek-drm` + `leds-mtk*` + `pwm-mtk-disp`. Do not copy any
donor `libdisplay*`, `lights*`, `composer*`, `hwcomposer*`, `gralloc*`, or
`memtrack*` into vendor. If HiOS 16 system insists on a newer composer AIDL
version than T1101 vendor provides, the fix is a system-side shim/downgrade,
never a vendor HAL swap on first boot.

### 4.4 Camera/audio/sensors/Wi-Fi/BT (post-boot, in this order)

1. Wi-Fi/BT: `vendor/lib*/libbluetooth*`, `vendor/etc/bluetooth/*`,
   `vendor/firmware/*wlan*`, `wpa_supplicant*`, `init.connectivity.rc` — keep
   T1101; donor usually only needs its `system` BT app + perms.
2. Audio: `vendor/etc/audio*`, `libaudio*`, `aw87xxx/awinic` firmware + params
   — keep T1101; port only HiOS 16 `system` sound picker/effects conf if wanted.
3. Sensors: `vendor/etc/sensors*`, `libsensor*`, `line_hall` — keep T1101.
4. Camera: `vendor/lib*/camera*`, `camx*`, `mtkcam*`, `camera_test*` — keep
   T1101; HiOS 16 camera *app* from donor may need its `priv-app` perms kept.
5. Power/lights/vibrator/gatekeeper/keymint: keep T1101 (recovery already
   proves keymint-trustonic + gatekeeper work with these blobs).

---

## 5. Debugging

### 5.1 Where to look, by symptom

| Symptom | Most likely cause | First logs |
|---|---|---|
| Black screen, no vibration, back to OrangeFox/fastboot | kernel/DTB/DTBO mismatch, `vbmeta` still enforcing, super unflashable | `fastboot getvar all`, OrangeFox `/tmp/recovery.log`, `dmesg` from recovery |
| Stuck at TECNO logo (before boot animation) | first-stage fstab/mount fail, `vbmeta_system` digest mismatch, `init` can't mount `system/vendor/product` | `dmesg`, `/proc/last_kmsg`, `console-ramoops`, `init` lines |
| Boot animation loops / reboots | SELinux denial, missing HAL, `apex` fail, `zygote`/`system_server` crash | `logcat -b all`, `tombstones`, `surfaceflinger` lines |
| Boots but black/no UI | composer/HWC/gralloc mismatch, bad overlay/density | `logcat -s SurfaceFlinger,hwcomposer,Gralloc4,vendor...`, `dumpsys SurfaceFlinger` |
| No audio/camera/sensors/Wi-Fi/BT | HAL version skew, missing firmware, perms | `logcat -s audio*,camera*,Sensor*,android.hardware.wifi,android.hardware.bluetooth`, `dmesg \| grep -i -E 'wlan|bt|audio|cam|sens'` |

### 5.2 Capture commands (run from Debian with device in OrangeFox or booted)

Scripted version: `bash port/scripts/10-collect-logs.sh out/logs` — grabs all
of the below plus `getprop`, `mount`, `blkid`, `lpdump` if present.

```bash
adb devices                              # device must show; in OrangeFox enable ADB
adb shell getprop > getprop.txt          # fingerprint, slots, crypto state
adb shell cat /proc/cmdline; adb shell cat /proc/last_kmsg > last_kmsg.txt
adb shell dmesg > dmesg.txt              # kernel: panel, mmc/ufs, mount, AVB
adb pull /sys/fs/pstore/console-ramoops-0 ramoops-0.txt   # survives reboot; may need root
adb pull /sys/fs/pstore/dmesg-ramoops-0  dmesg-ramoops.txt; true
adb logcat -b all -d > logcat-all.txt    # everything since boot
adb logcat -b main,system,crash -d > logcat-crash.txt
adb shell ls -l /dev/block/mapper > mapper.txt; adb shell mount > mount.txt
adb shell lpdump --help >/dev/null 2>&1 && adb shell lpdump > lpdump-device.txt; true
adb pull /tmp/recovery.log recovery.log  # when in OrangeFox
adb shell ls -R /product/overlay /vendor/overlay > overlays.txt
```

Pstore note (MediaTek): after a bootloop reboot straight into OrangeFox and
pull pstore *before* any successful boot overwrites it.

### 5.3 Error patterns to grep (MediaTek + Transsion/HiOS)

```bash
# mount / AVB / verity (pre-animation loops)
grep -i -E 'fs_mgr|first_stage_mount|cannot mount|failed to mount|slotselect|logical|dm-verity|vbmeta|avb|digest|hashtree|fec|TRAN_AVB|tran_avb' dmesg.txt logcat-all.txt last_kmsg.txt

# SELinux (animation loops, HAL "permission denied" that isn't a unix perm)
grep -i -E 'avc:\s*denied|SELinux|seclabel|selinux_android' logcat-all.txt dmesg.txt

# HAL / vintf / binder (animation loops, per-service death)
grep -i -E 'hwservicemanager|HIDL|AIDL|VINTF|manifest|hal |hidl_|aidl_|binder.*(dead|failed|exception)|ServiceManager.*not found|cannot find|No such' logcat-all.txt

# display / composer (black screen, animation freeze)
grep -i -E 'surfaceflinger|hwcomposer|composer|gralloc|memtrack|drm|mediatek-drm|panel|dsi|display|sf |vsync|HWC|FB |FBO|EGL|vulkan|overlay|RRO|idmap' logcat-all.txt dmesg.txt

# zygote / system_server / apex (animation loops)
grep -i -E 'zygote|system_server|AndroidRuntime|FATAL EXCEPTION|apex|apexd|linker|CANNOT LINK|dlopen failed|UnsatisfiedLink|ClassNotFound|NoClassDef' logcat-all.txt

# audio/camera/sensors/power/wifi/bt (post-boot peripherals)
grep -i -E 'audio|tinyalsa|a2dp|aw87|awinic'            logcat-all.txt | head
grep -i -E 'camera|mtkcam|camx|CSI|sensor bringup'      logcat-all.txt | head
grep -i -E 'SensorService|sensors-hal|accel|gyro|hall'  logcat-all.txt | head
grep -i -E 'wlan|wifi|hostapd|wpa_supplicant|firmware.*(load|fail)' dmesg.txt logcat-all.txt | head
grep -i -E 'bluetooth|bt_|hci|a2dp|ble'                 logcat-all.txt | head
grep -i -E 'health|charger|battery|gauge|mt6358|powerhal|thermal' logcat-all.txt dmesg.txt | head
```

MediaTek tells: `mtk_plpath_utils`, `musb-hdrc`, `11270000.ufshci`,
`mt6789`, `ulg`, `ccci`, `scp`, `spm`, `dcm`, `emi_mpu`, `smi`, `cmdq`,
`transsion`, `tran_`, `TR_PRODUCT`, `tetra`/`tron` (HiOS services). If a crash
mentions `T1103` hardware paths while running on T1101 vendor, you found a
donor leftover to shim (see §4.3).

### 5.4 Fix loop discipline

1. Change ONE thing per flash (one partition or one prop file).
2. Keep every `logcat-all.txt + dmesg.txt + getprop.txt` triple in
   `port/logs/<date>-<change>/` so regressions are diffable.
3. If animation-loop: `adb logcat -b crash` usually names the exact crashing
   service in the first 50 lines — fix that service, not "the ROM".
4. If pre-animation: it's almost always fstab/slot/AVB — re-verify with
   `01-inspect-super.sh` output, not by guessing.

---

## 6. Flash & rollback (always have an exit)

```bash
# backup first (OrangeFox → Backup → boot, vendor_boot, super, nvdata, protect1/2, nvram)
fastboot flash super out/super_ported.img
fastboot --disable-verity --disable-verification flash vbmeta vbmeta_patched.img
fastboot --disable-verity --disable-verification flash vbmeta_system vbmeta_system_patched.img
fastboot --disable-verity --disable-verification flash vbmeta_vendor vbmeta_vendor_patched.img
fastboot -w   # first port boot: format data (FBE keys change across Android 14→16)
fastboot reboot
```

Rollback = re-flash your OrangeFox backup of `super + boot + vendor_boot +
vbmeta*`, or the stock firmware. Never test a port without a known-good backup
on the SD card AND on the laptop.

---

## 7. Repo layout for this port

```
port/
  README.md                  ← this guide
  FILES-TO-UPLOAD.md         ← what to push so automation can run
  manifest.example.json      ← stock+donor image URLs + sha256 template
  scripts/                   ← 4 GB-safe Debian scripts (see §2.3)
  patches/                   ← canonical prop/fstab/overlay patches
  checklists/first-boot-checklist.md
.github/workflows/port-hios16.yml  ← cloud build: uploads manifest → builds super
```
