# START HERE (simple version)

You have 2 firmwares. That is everything. Nothing else to download.

## The idea in 3 lines

- **T1101 firmware = the body.** It knows YOUR tablet's screen, touch, wifi, etc. We keep it.
- **T1103 firmware = the clothes.** It has HiOS 16 (the new look + apps). We take only 3 pieces from it.
- **The port = T1101 body + HiOS 16 clothes.** A script builds it for you. You do NOT need to understand the technical guide yet.

## What is inside a firmware?

A firmware folder is just a bunch of `.img` files. The two you care about:

- `super.img` — the BIG one (several GB). It is a box containing smaller boxes: `system`, `vendor`, `product`, etc.
- Small ones: `boot.img`, `vendor_boot.img`, `dtbo.img`, `vbmeta.img` (each ~10–64 MB).

Your T1101 folder and your T1103 folder should each have these (names may vary slightly — that is OK).

## Do ONLY these 3 steps now

**Step 1 — Find your files.**
On your phone, open a file manager (Files, MT Manager, or DNA-Android's browser).
Find the T1101 folder and the T1103 folder. Write down every file name + its size.

**Step 2 — Send me the two lists.**
Type them in chat, or take screenshots. Example of what I need:

```
T1101 folder:
  super.img (8.5 GB)
  boot.img (32 MB)
  ...
T1103 folder:
  ...
```

**Step 3 — Wait for my reply.**
I will look at your lists and tell you exactly which files to copy to your
Debian laptop and which ONE command to run. Then automation takes over.

## Do NOT do these yet

- Do NOT flash anything.
- Do NOT unpack everything at once (it will fill your storage).
- Do NOT upload anything yet (I will tell you exactly which file goes where).

That is it. Step 1 and 2, then I guide you file by file.
