# DSU test (safe trial run before flashing) — 2026-09-14

No custom vendor image is needed, ever: the stock T1101 vendor (its drivers and
HALs) stays in place by design, and DSU keeps it automatically. The donor's
system side is generic, so it runs on top of stock vendor — that is exactly
what this test proves, with zero risk (no wipe, no resize, stock untouched).

## Constraints (super space)
- After `snapshot-update cancel`: ~3413MB free in super.
- Our 3 DSU images: system 703 + system_ext 1719 + product 468 = ~2890MB.
- DSU also needs its own fresh userdata (real data is NOT touched).
- `tr_product` can NOT ride along (DSU API has no custom partitions) — the
  stock one stays mounted. Its old apps may crash; ignore that. GMS/Store are
  tested in the real flash, not here.

## Recipes (pick by what the app accepts; total must be ≤ ~3400MB)
- **A (full, matched set):** system + system_ext + product + userdata **512MB**
  → ~3402MB. Tight fit; 512MB userdata may choke first-boot dexopt (see below).
- **B (roomy):** system + system_ext + userdata **900MB** → ~3322MB.
  Stock product mounts instead (A14 apps = noise; see BOOTCLASSPATH note).
- **C (minimal):** system only + userdata **2000MB** → ~2703MB. Framework-only
  signal; UI mix will be noisy.

BOOTCLASSPATH note: if donor system puts `/product/framework/*` (agares) on the
boot classpath, recipe A is REQUIRED (B/C would fail bogusly on the missing
jar). Check first (step 0).

## Steps
```bash
# 0. bootclasspath check (paste the output; decides A vs B)
grep -rn 'BOOTCLASSPATH' ~/hios-port/trees/donor-system/system/etc/ 2>/dev/null | head; echo ---; grep -rln 'agares' ~/hios-port/trees/donor-system/system/etc/ 2>/dev/null | head

# 1. room on the phone for the images (~3GB on internal storage)
adb shell df -h /sdcard | tail -1

# 2. cancel OTA snapshots (frees 1.9GB of super space)
adb reboot fastboot
fastboot snapshot-update cancel
fastboot reboot

# 3. push images to the phone (a few minutes; needed for any recipe)
adb push ~/hios-port/out/system.img /sdcard/DSU/
adb push ~/hios-port/out/system_ext.img /sdcard/DSU/
adb push ~/hios-port/out/product.img /sdcard/DSU/
```

4. Open DSU Sideloader → grant root → select the images per the chosen recipe
   → set userdata size → install → reboot when prompted.
5. After boot, on the laptop:
```bash
adb shell getprop sys.boot_completed            # 1 = CORE PROVEN
adb shell getprop ro.build.display.id           # expect T1101-...V1133
adb shell wm density                            # expect 280
adb shell df -m /data | tail -1                 # if 100% full, verdict is inconclusive (space, not incompat)
```

## Interpreting the result
- `sys.boot_completed=1` (even with crashing apps / no wallpaper / ugly UI) =
  framework + vendor are compatible. App crashes are expected (mixed A14/A16
  apps + stock tr_product). Display lit = display HAL works.
- No `boot_completed`, or a bootloop: grab `adb logcat -b all` + `adb shell
  dmesg` (same patterns as FLASH-PLAN.md §9) and send them before uninstalling.
- If /data filled during first boot (recipe A): inconclusive — retry recipe B.

## Back to stock
DSU Sideloader → uninstall (or the DSU notification → reboot to stock).
Worst case: fastbootd `delete-logical-partition` on the `*_gsi` partitions.
