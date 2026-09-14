# First-boot checklist (minimal port)

Do in order. Stop at first failure, collect logs, fix, re-flash only that part.

- [ ] OrangeFox backup of boot, vendor_boot, super, vbmeta* (+nvdata/protect/nvram) on SD + laptop
- [ ] `01-inspect-super.sh` on stock + donor + ported super — sizes/group/`tr_*` match T1101
- [ ] Ported super contains: donor system/system_ext/product + stock vendor/vendor_dlkm/odm_dlkm/tr_*
- [ ] Props patched (06 script): device/product/model/brand/fingerprint/density = T1101
- [ ] Overlays audited: no T1103-gated RRO left enabled
- [ ] vbmeta* patched (flags 3) or DNA-Android AVB-disable; `avbtool info_image` confirms
- [ ] boot.img + vendor_boot.img + dtbo.img = T1101 stock (untouched)
- [ ] OrangeFox mount test: /system /vendor /product /system_ext all mount from ported super
- [ ] `fastboot flash super` + vbmeta* with `--disable-verity --disable-verification`
- [ ] `fastboot -w` (Android 14→16 FBE key change requires data format)
- [ ] Boot → collect `10-collect-logs.sh` bundle within 5 min (before pstore rotates)
- [ ] Triage with README §5 greps; fix ONE thing per flash
