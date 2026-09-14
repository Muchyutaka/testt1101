# T1101 HiOS 16 port — FLASH PLAN (2026-09-14)

## Flash set (final, all verified MATCH, all FIT)
- `~/hios-port/out/system.img` — 737337344
- `~/hios-port/out/system_ext.img` — 1801740288 (needs the resize below)
- `~/hios-port/out/product.img` — 491188224 (incl. Play Store + OOBE overlay)
- `~/hios-port/out/tr_product.img` — 628715520 (incl. Stub, minus EngineerCamera)

Total ~3.66GB. Untouched: vendor, kernel, recovery, vbmeta, odm_dlkm,
vendor_dlkm, all other tr_*.

## Rollback set (stock, already on the laptop)
- `~/hios-port/work/system_t1101.img`, `system_ext_t1101.img`, `product_t1101.img`
- `~/tr_product_stock_a.img`
- Original `system_ext_a` size: **1232695296** (for the reverse resize)

## 0. Pre-flight
- [ ] User data backed up (photos/files to PC; Google backup on) — wipe coming.
- [ ] Battery > 50%, stable USB cable, don't touch it mid-flash.
- [ ] `fastboot --version` works on the laptop.
- [ ] Bootloader unlocked (device is rooted ⇒ almost certainly; verify in step 1).

## 1. Bootloader checks
```bash
adb reboot bootloader
fastboot devices
fastboot getvar unlocked        # expect: yes (anything else → STOP, ask first)
fastboot getvar current-slot    # expect: a
```

## 2. Enter fastbootd + checks
```bash
fastboot reboot fastboot        # → fastbootd userspace (NOT the bootloader!)
fastboot devices
fastboot getvar is-userspace    # expect: yes
fastboot getvar current-slot    # expect: a
```

## 3. Cancel leftover OTA snapshots (their -cow partitions block edits)
```bash
fastboot snapshot-update cancel   # OK, or "not in snapshot" — either is fine
```
Fallback if the command is unsupported: STOP and paste the error (manual cow
delete is possible but must be done carefully).

## 4. Grow system_ext_a (1176 → 1846MB = image + 128MB margin)
```bash
fastboot resize-logical-partition system_ext_a 1935958016
fastboot getvar partition-size:system_ext_a   # expect: 1935958016
```
Fallback if resize is unsupported:
```bash
fastboot delete-logical-partition system_ext_a
fastboot create-logical-partition system_ext_a 1935958016
```

## 5. Flash the 4 images (a few minutes)
```bash
fastboot flash system_a     ~/hios-port/out/system.img
fastboot flash system_ext_a ~/hios-port/out/system_ext.img
fastboot flash product_a    ~/hios-port/out/product.img
fastboot flash tr_product_a ~/hios-port/out/tr_product.img
```
Expect OKAY on each. On any FAILED (e.g. size error): STOP, paste the error,
do NOT reboot yet.

## 6. Wipe data (Android 14 data MUST NOT be kept under Android 16)
```bash
fastboot -w     # wipes userdata + metadata
```
Alternative: OrangeFox → Format Data (same effect).

## 7. First boot
```bash
fastboot reboot
```
WAIT 15 minutes (dexopt + Android 16 first setup; long is normal). Expect the
HiOS setup wizard. An orange-state bootloader warning at boot is normal
(unlocked bootloader, expected — vbmeta was deliberately left stock).

## 8. Post-boot checks
- Setup wizard completes, WiFi connects.
- Settings > About shows sane T1101 info.
- `adb shell wm density` → 280.
- Play Store opens and updates itself (give it ~10 min on WiFi).
- Camera app: the donor T1103 app may crash (missing T1103 drivers) → install
  the stock T1101 camera APK or OpenCamera as a user app.
- Gmail/Maps/Photos/YouTube/Messages/Drive: install from the Store as needed.
- Play Integrity will FAIL (unlocked + modified) so banking apps may refuse —
  fix post-boot (Magisk + PlayIntegrityFix) if needed.

## 9. If it bootloops (no setup screen within 15 min, or a logo loop)
Do NOT wipe or reflash yet — grab logs first:
```bash
adb logcat -b all > bootloop-logcat.txt     # retry a few times, adb drops in loops
adb shell dmesg > bootloop-dmesg.txt
```
If adb never appears, boot OrangeFox (VolUp+Power) and run on the laptop:
```bash
adb pull /sys/fs/pstore/console-ramoops ramoops.txt
adb shell cat /proc/last_kmsg > last_kmsg.txt
```
Patterns that matter: `FATAL EXCEPTION`, `avc: denied`, `CANNOT LINK`,
`Failed to mount`, `E SELinux`, `system_server` crash, `fs_mgr`,
`init: cannot find`. Send the files; flash nothing until reviewed.

## 10. Rollback (back to stock)
Back to fastbootd (steps 1–2), then:
```bash
fastboot flash system_a     ~/hios-port/work/system_t1101.img
fastboot flash system_ext_a ~/hios-port/work/system_ext_t1101.img
fastboot flash product_a    ~/hios-port/work/product_t1101.img
fastboot flash tr_product_a ~/tr_product_stock_a.img
fastboot resize-logical-partition system_ext_a 1232695296
fastboot -w
fastboot reboot
```
