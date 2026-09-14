# Firmware sources (user's drops, on-phone 2026-09-14)

Both are SP-Flash-Tool-style full firmwares (scatter + images). Location at time
of listing: phone storage (`~/storage/downloads/` in Termux).

## Stock: Tecno-MegaPad-11-T1101-27 (T1101, Android 14)

Key files present (sizes measured 2026-09-14):
- `super.img` **5.1G** (sparse; expands to ~8.5G raw) + `super_empty.img`
- `boot.img` 64M, `vendor_boot.img` 64M, `dtbo.img` 8.0M
- `vbmeta.img` 12K, `vbmeta_system.img` 4K, `vbmeta_vendor.img` 4K
- Pre-extracted dynamic imgs: `vendor_dlkm.img` 36M, `odm_dlkm.img` 73K,
  `tr_mi.img` 170M, `tr_theme/region/company/carrier.img` 69K each,
  `tr_product.img` 21K, `tr_preload.img` 21K (tiny Transsion placeholders — normal)
- No separate `system.img`/`vendor.img`/`product.img`/`system_ext.img` → inside `super.img`
- `.map` files (SPFT mappings, not needed), `MT6789_Android_scatter.txt/.xml`
- `preloader*.img/.bin`, `lk.img`, `lk_a_patched.img` (one dir up), `logo.bin`, `tee.img`, etc.
- `installed-files-ramdisk.txt`, `installed-files-vendor.txt`, `version.csv`

Full listing (from user terminal 2026-09-14):

```
APDB_MT6789___W2430  mcupm.img  super_empty.img  tr_region.map
APDB_MT6789___W2430_ENUM  md1img.img  system.map  tr_theme.img
MDDB_InfoCustomAppSrcP_MT6789_S00_MOLY_LR13_R2_MP_V162_P10_1_ulwctg_n.EDB  odm_dlkm.img  system_ext.map  tr_theme.map
MT6789_Android_scatter.txt  odm_dlkm.map  tee.img  tranfs.img
MT6789_Android_scatter.xml  pi_img.img  tkv.img  userdata.img
Open  preloader.img  tool_custom.ini  vbmeta.img
boot.img  preloader_emmc.img  tr_carrier.img  vbmeta_system.img
download_agent  preloader_raw.img  tr_carrier.map  vbmeta_vendor.img
dpm.img  preloader_t1101_m1101.bin  tr_company.img  vendor.map
dtbo.img  preloader_ufs.img  tr_company.map  vendor_boot-debug.img
efuse.img  product.map  tr_mi.img  vendor_boot.img
gz.img  provisioning_hpbtw.xml  tr_mi.map  vendor_bootss.img
installed-files-ramdisk.txt  scatter_checksum.xml  tr_preload.img  vendor_dlkm.img
installed-files-vendor.txt  scp.img  tr_preload.map  vendor_dlkm.map
ksunext.img  spmfw.img  tr_product.img  version.csv
lk.img  sspm.img  tr_product.map
logo.bin  super.img  tr_region.img
```

## Donor: R2-Tecno-Megapad-2-T1103 (T1103, HiOS 16 / Android 16)

Key files present:
- `super.img` + `super_empty.img` (donor dynamics ONLY here — no separate imgs)
- `boot.img`, **`init_boot.img`** (Android 16 style — reference only, do NOT flash to T1101),
  `vendor_boot.img`, `vendor_boot-debug.img`, `dtbo.img`
- `vbmeta.img`, `vbmeta_system.img`, `vbmeta_vendor.img`, `modem.img`
- Dynamic partitions: only `.map` files → must `lpunpack` from `super.img`
- `partition_info.json`, `PGPT_EMMC`, `PGPT_UFS`, `RU/` (ref/unbricking info, ignore for port)
- `MT6789_Android_scatter.txt/.xml`, `installed-files-*.txt`, `version.csv`

Full listing (from user terminal 2026-09-14):

```
APDB_MT6789___W2610  installed-files-ramdisk.txt  scatter_checksum.xml  tr_overlayfs.map
APDB_MT6789___W2610_ENUM  installed-files-vendor.txt  scp.img  tr_preload.map
MDDB_InfoCustomAppSrcP_MT6789_S00_MOLY_LR13_R2_MP_V245_6_P1_1_ulwctg_n.EDB  lk.img  spmfw.img  tr_product.map
MT6789_Android_scatter.txt  logo.img  sspm.img  tr_region.map
MT6789_Android_scatter.xml  mcupm.img  super.img  tranfs.img
PGPT_EMMC  modem.img  super_empty.img  userdata.img
PGPT_UFS  odm.map  system.map  userdata_stripe_0.img
RU  odm_dlkm.map  system_dlkm.map  userdata_stripe_1.img
boot.img  partition_info.json  system_ext.map  vbmeta.img
download_agent  pi_img.img  tee.img  vbmeta_system.img
dpm.img  preloader.img  tkv.img  vbmeta_vendor.img
dtbo.img  preloader_emmc.img  tool_custom.ini  vendor.map
efuse.img  preloader_raw.img  tr_carrier.map  vendor_boot-debug.img
gz.img  preloader_t1103_m1103.bin  tr_company.map  vendor_boot.img
init_boot.img  preloader_ufs.img  tr_manifest.map  vendor_dlkm.map
installed-files-odm.txt  product.map  tr_misc.map  version.csv
```

## Laptop copy (Debian, 2026-09-14)

Full folders copied via USB (not just the shortlist — fine, more is better):

- Stock → `~/hios-port/stock/Tecno-MegaPad-11-T1101-27/`
- Donor → `~/hios-port/donor/R2-Tecno-Megapad-2-T1103/`
- UNIDENTIFIED (user-made?): `stock/.../super_raw.img` + `stock/.../unpacked_img/`
  → SOLVED 2026-09-14: `super_raw.img` (9.0G, `file`=data) is the T1101 super
  converted to raw (2359296×4096 = 9663680256 bytes — exact match, reuse it,
  do NOT reconvert). `unpacked_img/` is empty — ignore.
- Laptop: 3.7G RAM + 14G swap (8G added by 00-deps), disk 197G.
  Was 13G free (94%) → user freed to **98G free (48%)** on 2026-09-14.
  Full laptop-side workflow now possible (donor raw 12.4G + extracts + rebuild fit).
- Debian apt has no lpdump/lpunpack/lpmake (only sparse tools via
  android-sdk-libsparse-utils) → scripts use `unsuper` (pip) instead.

## Partition maps (unsuper, 2026-09-14)

T1101 stock (`super_raw.img`, all content on `_a`, `_b` slots empty, total 5154.8MB):

| part | size | part | size |
|---|---|---|---|
| system_a | 976.6MB | vendor_a | 930.3MB |
| system_ext_a | 1175.6MB | vendor_dlkm_a | 35.7MB |
| product_a | 1864.7MB | odm_dlkm_a | 0.3MB |
| tr_mi_a | 169.7MB | tr_product/theme/preload/region/company/carrier_a | 0.3MB each |

T1103 donor (`donor-super.raw`, all content on `_a`, `_b` empty, total 5343.2MB):

| part | size | part | size |
|---|---|---|---|
| system_a | 922.7MB | vendor_a | 655.3MB |
| system_ext_a | 1790.9MB | vendor_dlkm_a | 13.6MB |
| product_a | 434.7MB | odm_a | 791.7MB |
| system_dlkm_a | 7.7MB | odm_dlkm_a | 4.0MB |
| tr_product_a | 720.3MB | tr_preload/region/carrier/company/misc/manifest/overlayfs_a | 0.3MB each |

Fit math: stock trio (system+system_ext+product) = 4016.9MB, donor trio =
3148.3MB → donor SMALLER by ~870MB, fits guaranteed. Even adding donor
`odm` (791.7MB) + donor `tr_product` (720.3MB, replaces stock 0.3MB placeholder):
new super ≈ 5.8GB in 9.66GB raw → ~3.8GB spare. No super resize needed.
OPEN QUESTION (decide from tree survey): donor moved ~1.5GB into `odm` +
`tr_product` (stock has no `odm`, empty `tr_product`). If HiOS 16 requires
`/odm` mount/content, port must add `odm_a` + fstab entry; `tr_product` (same
mount point both sides) can simply take donor content. `system_dlkm` (7.7MB,
donor GKI modules) skipped — T1101 keeps its 5.10 kernel + vendor_dlkm.
Gotcha: laptop `/tmp` is 1.9G tmpfs → unsuper sparse staging MUST use
`--temp-dir` on `/` (scripts now do this automatically).

## Donor fstab analysis (T1103 vendor_boot, 2026-09-14)

Donor REQUIRES (no `nofail`): system, system_ext, vendor, product, **odm**,
vendor_dlkm, odm_dlkm, **system_dlkm**, tr_manifest (at /mnt/vendor/tr_manifest).
Donor nofail: all other tr_* (region/company/carrier/product/preload/overlayfs/misc).
Donor tr_* verify against `/odm/etc/vconfig/tran_avb.pubkey` (stock T1101 uses
`/vendor/etc/tran_avb.pubkey`) — moot, AVB gets disabled.
Donor metadata tries f2fs first; donor userdata lacks T1101's UFS `sysfs_path`.
VERDICT: keep the T1101 fstab as boss (ext4 metadata, UFS sysfs_path, stock tr
set incl. tr_mi/tr_theme). Only open question: add an `odm` entry + partition
(pending deep survey: does donor system reference /odm? are odm files T1103-HW
specific?). system_dlkm: skip unless userspace references found. tr_manifest/
tr_misc/tr_overlayfs: skip (0.3MB empty; our fstab won't list them so no failed mounts).

## Build.prop + partition verdicts (deep survey, 2026-09-14)

- Donor system/product/system_ext/tr_product/system_dlkm build.props are 100%
  GENERIC MSSI (`mssi_64_64only_cn_armv82`/`tssi`, zero T1103 strings). All
  T1103-ness lived in donor odm (device props, camera tunings, vintf, selinux).
- Stock system is generic too (`FULL-64-ARMV82`); T1101 identity comes from
  stock product/system_ext/vendor(+vendor/odm subdir). So: NO identity
  replacement needed — patch = ADD density 280 + tablet flags only.
- Density: donor 360 (odm) vs stock 280 (vendor T1101-OP section; hal section
  says 480 — device getprop will confirm 280). Patch 280 into every taken tree.
- characteristics: donor product `default` vs stock `tablet` (+`ro.product.type=tablet`).
  Patch into donor product tree (affects tablet UI: taskbar, embedding).
- Fingerprints: left generic-on-purpose for first boot (GMS/PI tuning post-boot).
- TAKE tr_product (720MB Transsion apps, generic build.prop, same mount both sides).
  CONFIRMED 2026-09-14: it holds CORE GOOGLE APPS (GmsCore, GoogleServicesFramework,
  Velvet, Chrome64, WebView/Trichrome, LatinImeGoogle, SetupWizard + privapp
  permission XMLs) + EngineerCamera/SMTLauncher_res/TranfacIcon. Donor splits GMS
  across product + tr_product; taking both = complete set, no conflicts.
- SKIP odm for first boot (1043 .so, ~all T1103 camera tuning + T1103 vintf/selinux;
  pending section-D confirm that system doesn't reference /odm).
- SKIP system_dlkm (donor GKI modules, useless on 5.10 kernel; pending refs check).
  CONFIRMED generic: bluetooth/can/virtio/usbserial .ko only, no HiOS content.
- Stock vendor keeps T1101 camera tunings (vendor/lib64) + odm-subdir identity props.
- Risk noted: stock vendor is VNDK 31 (A12) + composer 2.1 under an SDK-36
  system — Treble-forward-compat will be proven (or disproven) by first boot logs.

## Stock device ground truth (adb getprop, booted T1101 on V1046, 2026-09-14)

- `ro.sf.lcd_density=280` ✓ (vendor T1101-OP section wins over hal 480 → LAST-wins;
  patch 280 into every taken tree so order is irrelevant)
- `ro.product.device=TECNO-T1101`, model `TECNO T1101`, brand `TECNO` ✓
- `ro.build.characteristics=tablet` ✓ (patch into donor product confirmed)
- `ro.build.fingerprint=TECNO/T1101-OP/TECNO-T1101:14/UP1A.231005.007/260410V1046`
  (matches recovery tree; firmware files are a newer V1133/V971/V931 mix — harmless)
- `ro.product.tr_product.device=TECNO-T1101` (stock tr_product carries identity;
  donor tr_product is generic — final device still T1101 via vendor, 2nd in donor order)
- adb works (device `137751556B000732`) — log collection path ready.
- Script bug found+fixed: surveys died early on `| head` (SIGPIPE + pipefail + set -e).
  Survey scripts now run with `set +o pipefail`.

## Rebuild-all run 1 (2026-09-14): died at step 0d, nothing built

- Root cause (closes the whole bug class): `SUPER="$(ls … | grep -i stock | head -1)"`
  with no matching super files → ls+grep fail → pipefail → assignment fails →
  errexit fires. There is NO immunity for failures inside $(…); earlier
  `VAR=$(…|head)` lines survived only by luck (tiny outputs, no SIGPIPE).
  Rule: surveys run +o pipefail; build scripts keep pipefail (real mkfs failures
  must kill) + every may-fail $()/pipeline gets `|| true` or loop form.
  Full audit of step-rebuild-all.sh done: SUPER→find_super loop, LIST armored,
  everything else verified safe-or-deliberately-fatal.
- Also possible: super files exist but lack "stock" in the name, or live outside
  $BASE. find_super takes any *super* file, prefers *stock*, else graceful
  fallback (fit check vs original size + raw numbers for human judgment).

## Rebuild test 2 (2026-09-14): METHOD 100% PROVEN 🎉

- Re-run with --mount-point=/product + combined fc + fixed diff line: structure
  diff EMPTY + ALL 6 samples MATCH (labels+owners+modes). 06 v4 props baked in.
- step-rebuild-all.sh = final build: same proven flags for all 4 donor partitions
  (mount-points /, /system_ext, /product, /tr_product), -zlz4hc (same LZ4 wire
  format the 5.10 kernel already reads, strictly smaller output), per-partition
  stamp verify + fit check vs stock super geometry. Output: out/*.img flash set.

## Prop recon + rebuild test 2 (2026-09-14)

- characteristics=tablet lives ONLY in stock product (line 28); donor product had
  `default` → patched in place (verified line 27). Vendor (both sides) defines none
  → product's value wins the global. ✓
- `ro.product.type=tablet` is REAL (stock product line 135, Transsion key), donor
  lacks it → 06 v4 appends it to donor product (v3 wrongly dropped it).
- display.id: stock product = T1101-...V1133; donor product lacks it; donor system
  has generic BP2A. Stock/donor vendor lack it → donor product gets stock's V1133 id
  (cosmetic About-page fix, zero boot risk).
- ro.build.type=user on both systems ✓. tr_product/system_ext/odm/vendor/… define
  none of these keys → nothing to do there (also tr_product isn't in donor's
  property_source_order, so its ro.build.* could never go global anyway).
- Test2 mechanics: combined fc = 2996 lines with /(product|system/product) entries
  present; leftover mounts cleaned; MATCH/DIFF verdict was CUT from paste —
  awaiting `sed -n '/structure diff/,$p' ~/rebuild-test2.txt`.
- Test2 run 1 DIED on the bare `diff|head` line (diff exits 1 when images differ,
  errexit+pipefail treated it as fatal) — MATCH/DIFF comparisons never ran. Fixed
  with `|| true` (both test scripts); re-run also applies 06 v4 (type+display.id)
  and packs clean (out-of-tree backup). Awaiting re-run tail.
- Lesson: 06 v3's in-tree `build.prop.orig` got PACKED into the image (+1 inode).
  v4 keeps backups in work/prop-orig/; rebuild-all deletes stray *.orig first.

## Rebuild test 1 (2026-09-14): method 80% proven

- Patch: density 280 landed in all 4 donor trees ✓
- BUT 06 v2 patched the WRONG characteristics key (added useless `ro.product.*`,
  left real `ro.build.characteristics=default`). 06 v3 fixes in place, product only.
- Structure: rebuilt image layout byte-identical to original (empty find-diff) ✓
- Owners/modes: [644 0 0] matched via chown ✓ (test2 uses --force-uid/gid instead)
- Labels: ALL (none) — cause: donor product_file_contexts is EMPTY (0 lines) and
  mkfs needs --mount-point=/product so /product* regexps match. Test2 combines ALL
  trees' fcs + --mount-point + forced ids. mkfs.erofs 1.8.6 supports everything.
- Script robustness: cmp_one died on absent sample file and leaked 2 loop mounts;
  test2 adds SKIP-on-missing + EXIT trap + leftover cleanup at start.

## Refs + stamp verdicts (survey-refs complete, 2026-09-14)

- /odm refs in donor system-side: ONLY generic plumbing (ueventd firmware paths,
  init.rc imports, plat/system_ext file+property contexts). No services, mounts
  or waits. SKIP odm FINAL.
- system_dlkm refs: ONLY SELinux mapping CIL. SKIP FINAL.
- tr_misc/tr_manifest/tr_overlayfs refs: ONE file_contexts line. No wait/mount. SKIP FINAL.
- Stamp test: extraction LOSES security.selinux xattr + resets uid/gid to the user
  (orig `u:object_r:system_file:s0 [600 0 0]` vs extracted `(none) [600 1000 1000]`).
  → Rebuilds MUST re-apply labels via mkfs.erofs --file-contexts + root ownership.
  step-patch-and-rebuild-test.sh validates the method on donor product (smallest).
- Stock: camera tunings live in vendor (380 libCamera_*); vendor/odm is a tiny
  identity+vintf shim. Untouched by the port.

## Notes for the port

- Same platform both sides (`MT6789`, MOLY LR13 base) — good sign.
- T1101 already ships extracted `vendor_dlkm/odm_dlkm/tr_*` imgs → verify vs super, reuse to skip unpacks.
- T1103 `system/system_ext/product` must be lpunpacked from donor `super.img`.
- T1103-only extras (`init_boot.img`, `odm`, `system_dlkm`, `tr_manifest`, `tr_misc`,
  `tr_overlayfs`, `modem.img`) stay on the donor side — do not add to T1101 super layout.
- `vendor_bootss.img` + `lk_a_patched.img` + `orfoxvendor_boot.img` in downloads root:
  user's own patched/recovery images — keep, do not mix into stock sets.
