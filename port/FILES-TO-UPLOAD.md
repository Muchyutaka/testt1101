# What to upload so the port can be automated

Direct answer to "what files do I upload to GitHub so you can just do it
automatically": **small metadata + boot images go IN git, big partition images
go in a GitHub Release (or any direct-download host) + get referenced from a
manifest.** GitHub blocks files >100 MB in git and soft-caps repos ~2 GB —
a raw `super.img` (~8.5 GB) can never be committed directly.

## Tier 0 — commit to git (required, all small)

Generate on Debian (or in OrangeFox + `adb pull`), then `git add` under
`port/dumps/<t1101|t1103>/`:

From **BOTH** T1101 stock and T1103 donor firmware:

```
lpdump.txt                  # lpdump super.img                (~20 KB)
inspect.txt                 # port/scripts/01-inspect-super.sh output
partition-list.txt          # fastboot getvar all + by-name listing
sizes.txt                   # ls -l *.img + file(1) output for every image
fstab.mt6789                # from vendor_boot ramdisk (first-stage, boot-critical)
fstab.emmc                  # if present
recovery.fstab              # if present
build-props/                # EVERY build.prop + default.prop:
  system-build.prop           #   /system/system/build.prop
  system_ext-build.prop       #   /system_ext/etc/build.prop
  product-build.prop          #   /product/etc/build.prop
  vendor-build.prop           #   /vendor/build.prop
  odm_dlkm-, vendor_dlkm-     #   if they exist
vintf/
  manifest.xml                # vendor/etc/vintf/manifest.xml
  compatibility_matrix.xml    # vendor/etc/vintf/compatibility_matrix.xml
filelists/
  system.txt system_ext.txt product.txt vendor.txt   # find <mnt> -printf '%M %s %p\n' | sort
  vendor_dlkm.txt odm_dlkm.txt tr_mi.txt ...         # one per tr_* partition
overlays.txt                # ls -R product/overlay vendor/overlay system_ext/overlay
keylayout.txt               # ls -R vendor/usr/keylayout vendor/usr/idc system/usr/keylayout
getprop.txt                 # adb shell getprop (from a booted device if possible)
```

Boot-chain binaries (small enough for git, REQUIRED for automation):

```
port/dumps/t1101/boot.img            # stock T1101 (~32-64 MB) — kept as-is
port/dumps/t1101/vendor_boot.img     # stock T1101 (~32-64 MB) — kept as-is
port/dumps/t1101/dtbo.img            # stock T1101
port/dumps/t1101/vbmeta.img vbmeta_system.img vbmeta_vendor.img
port/dumps/t1101/prebuilt-dtb.img    # optional; already have prebuilt/dtb.img
port/dumps/t1103/vendor_boot.img     # donor, for fstab/init diff only
port/dumps/t1103/dtbo.img            # donor, for diff only (do NOT flash)
```

With just Tier 0, automation can already: diff fstabs/props/vintf, generate the
exact `lpmake` command, generate prop/overlay patch lists, and tell you which
3 partitions to swap — i.e. everything except byte-copying the big images.

## Tier 1 — GitHub Release assets (required for a full auto-build)

Upload the big images as **Release attachments** (limit ~2 GB per file; split
if needed), or any host with direct `https://` links (GDrive direct, Mega,
PixelDrain, Telegram direct, your own server). Then fill
`port/manifest.json` (copy from `manifest.example.json`) with URL + sha256 per file:

```
super_t1101.img        # stock T1101 super (or super.img + _a/_b sparse chunks)
super_t1103.img        # donor T1103 super (same)
# — OR, to save upload time/bandwidth, just these per-device extracts: —
system_t1101.img  system_ext_t1101.img  product_t1101.img  vendor_t1101.img
vendor_dlkm_t1101.img  odm_dlkm_t1101.img  tr_*.img (7 files)
system_t1103.img  system_ext_t1103.img  product_t1103.img   # only 3 needed from donor
```

Splitting for the 2 GB Release cap (on Debian):

```bash
split -b 1900M super_t1103.img super_t1103.img.part-
sha256sum super_t1103.img* > sha256sums.txt
# upload all parts + sha256sums.txt to the Release, list parts in manifest.json
```

The workflow `.github/workflows/port-hios16.yml` downloads whatever
`port/manifest.json` lists, verifies sha256, runs the same scripts as
`port/scripts/`, and uploads `super_ported.img` (+ patched vbmetas + flash
script) as a new Release. That is the "just do it automatically" path.

## Tier 2 — nice to have (speeds up peripheral fixes)

```
port/dumps/t1101/dmesg-stock.txt logcat-stock.txt      # healthy-boot reference logs
port/dumps/t1103/dmesg-stock.txt logcat-stock.txt
port/dumps/t1101/twrp-backup-list.txt                  # OrangeFox backup contents
firmware scatter / DA / preloader version strings      # SP Flash Tool info, for unbrick notes
```

## What NOT to upload

- `userdata/metadata/nvdata/nvcfg/protect1/protect2/nvram/persist/frp` dumps —
  contain IMEI/keys. Never commit, never Release.
- Full EROFS extracted trees (`work/sys_t1103/...`) — regenerate from images.
- `out/` build products — CI rebuilds them.
- Anything with your Google account / Wi-Fi passwords (check `getprop.txt` for
  `persist.sys.*ssid*` — unlikely, but glance before committing).

## Commands to produce Tier 0 (copy-paste)

```bash
# from firmware images on Debian:
mkdir -p port/dumps/t1101 port/dumps/t1103
bash port/scripts/01-inspect-super.sh stock/super_t1101.img | tee port/dumps/t1101/inspect.txt
lpdump stock/super_t1101.img > port/dumps/t1101/lpdump.txt
# repeat for t1103, then per-partition file lists:
bash port/scripts/02-unpack-one.sh stock/super_t1101.img system work/
bash port/scripts/03-extract-erofs-lowram.sh work/system_t1101.img work/sys
(cd work/sys && find . -printf '%M %s %p\n' | sort) > port/dumps/t1101/filelists/system.txt
# build.props: adb pull from OrangeFox-mounted partitions, or extract from work/sys/...
adb pull /system/system/build.prop port/dumps/t1101/build-props/system-build.prop
# boot chain:
cp stock/boot.img stock/vendor_boot.img stock/dtbo.img stock/vbmeta*.img port/dumps/t1101/
cp donor/vendor_boot.img donor/dtbo.img port/dumps/t1103/
python3 tools/unpack_vendor_boot.py stock/vendor_boot.img /tmp/vb_t1101
cp /tmp/vb_t1101/first_stage_ramdisk/fstab.mt6789 port/dumps/t1101/
```

## `.gitignore` rules already expected

`port/dumps/*/boot.img` etc. are intentionally committed (small). Everything big
stays OUT of git:

```
port/dumps/**/*.img          # except the Tier-0 boot-chain files below!
!port/dumps/*/boot.img
!port/dumps/*/vendor_boot.img
!port/dumps/*/dtbo.img
!port/dumps/*/vbmeta*.img
work/ out/ *.raw *.simg
super_*.img system_*.img vendor_*.img product_*.img *_dlkm*.img tr_*.img
```
