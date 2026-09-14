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

## Notes for the port

- Same platform both sides (`MT6789`, MOLY LR13 base) — good sign.
- T1101 already ships extracted `vendor_dlkm/odm_dlkm/tr_*` imgs → verify vs super, reuse to skip unpacks.
- T1103 `system/system_ext/product` must be lpunpacked from donor `super.img`.
- T1103-only extras (`init_boot.img`, `odm`, `system_dlkm`, `tr_manifest`, `tr_misc`,
  `tr_overlayfs`, `modem.img`) stay on the donor side — do not add to T1101 super layout.
- `vendor_bootss.img` + `lk_a_patched.img` + `orfoxvendor_boot.img` in downloads root:
  user's own patched/recovery images — keep, do not mix into stock sets.
