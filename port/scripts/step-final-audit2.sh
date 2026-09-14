#!/usr/bin/env bash
# step-final-audit2.sh — CORRECTED face-offs (no extraction, ~2 min):
# HAL manifests incl. fragments + format column; FCM requires-vs-provides;
# vendor hardware features; agares declaration. Needs trees/donor-vendor.
# Usage: bash port/scripts/step-final-audit2.sh
set -euo pipefail
set -E
. "$(dirname "$0")/lib.sh"
trap 'log "!!! FAILED at line $LINENO: $BASH_COMMAND"' ERR
BASE="${BASE:-$HOME/hios-port}"
TREES="$BASE/trees"
[[ -d "$TREES/donor-vendor" ]] || die "run step-final-audit.sh first (donor vendor missing)"
log "0. manifest files parsed…"
find "$TREES/donor-vendor/etc/vintf" "$TREES/stock-vendor/etc/vintf" -name '*.xml' 2>/dev/null || true
log "1. HAL face-off v2 (fragments + format)…"
python3 - "$TREES/donor-vendor/etc/vintf" "$TREES/stock-vendor/etc/vintf" <<'EOF' || true
import sys, glob, os, xml.etree.ElementTree as ET
def load(d):
    out = {}
    files = [os.path.join(d, 'manifest.xml')] + sorted(glob.glob(os.path.join(d, 'manifest', '*.xml')))
    for path in files:
        try: r = ET.parse(path).getroot()
        except Exception as e:
            print(f"(skip {path}: {e})"); continue
        for hal in r.iter('hal'):
            n = (hal.findtext('name') or '').strip()
            f = hal.get('format', '?')
            vs = [v.text.strip() for v in hal.findall('version') if v.text and v.text.strip()]
            if n: out.setdefault((n, f), set()).update(vs)
    return out
def vmax(vs):
    ps = []
    for v in vs:
        try: ps.append(tuple(int(x) for x in v.split('.')))
        except ValueError: pass
    return max(ps) if ps else ()
a, b = load(sys.argv[1]), load(sys.argv[2])
print(f"(parsed {len(a)} donor HALs, {len(b)} stock HALs)")
print(f"{'HAL':48} {'fmt':>5} {'donor':>10} {'stock':>10}  verdict")
for (n, f) in sorted(set(a) | set(b)):
    va, vb = a.get((n, f), set()), b.get((n, f), set())
    sa = ','.join(sorted(va)) or '(none)'; sb = ','.join(sorted(vb)) or '(none)'
    if (n, f) not in a: v = 'ONLY-STOCK'
    elif (n, f) not in b: v = 'ONLY-DONOR'
    elif va == vb: v = 'SAME'
    elif vmax(va) > vmax(vb): v = 'DONOR-NEWER'
    elif vmax(va) < vmax(vb): v = 'STOCK-NEWER'
    else: v = 'SAME-MAX'
    print(f"{n:48} {f:>5} {sa:>10} {sb:>10}  {v}")
EOF
log "2. FCM requires vs stock vendor…"
FCM="$(find "$TREES/donor-system" "$TREES/donor-system_ext" -name '*compatibility_matrix*' 2>/dev/null || true)"
echo "FCM files: ${FCM:-<none found!>}"
for f in $FCM; do echo "--- $f"
python3 - "$f" "$TREES/stock-vendor/etc/vintf" <<'EOF' || true
import sys, glob, os, re, xml.etree.ElementTree as ET
def provload(d):
    out = {}
    files = [os.path.join(d, 'manifest.xml')] + sorted(glob.glob(os.path.join(d, 'manifest', '*.xml')))
    for path in files:
        try: r = ET.parse(path).getroot()
        except Exception: continue
        for hal in r.iter('hal'):
            n = (hal.findtext('name') or '').strip()
            vs = [v.text.strip() for v in hal.findall('version') if v.text and v.text.strip()]
            if n: out.setdefault(n, set()).update(vs)
    return out
def vnum(s):
    try: return tuple(int(x) for x in s.split('.'))
    except ValueError: return None
try:
    mr = ET.parse(sys.argv[1]).getroot()
except Exception as e:
    print(f"(cannot parse matrix: {e})"); sys.exit(0)
req = {}
for hal in mr.iter('hal'):
    n = (hal.findtext('name') or '').strip()
    opt = hal.get('optional', 'false') == 'true'
    vs = set()
    for v in hal.findall('version'):
        t = (v.text or '').strip()
        m = re.match(r'(\d+)\.(\d+)', t)
        if m: vs.add((int(m.group(1)), int(m.group(2))))
    if n: req[n] = (vs, opt)
prov = provload(sys.argv[2])
print(f"(matrix requires {len(req)} HALs)")
print(f"{'HAL':48} {'required':>10} {'stock-has':>10}  verdict")
for n in sorted(req):
    vs, opt = req[n]
    pv = prov.get(n, set())
    sr = ','.join(f"{a}.{b}" for a, b in sorted(vs)) or '-'
    sp = ','.join(sorted(pv)) or '-'
    ok = any(vnum(p) and vnum(p)[0] == a and vnum(p) >= (a, b) for (a, b) in vs for p in pv)
    v = 'OK' if ok else ('MISSING-OPT' if (not pv and opt) else ('SHORT-OPT' if opt else ('MISSING' if not pv else 'SHORT')))
    print(f"{n:48} {sr:>10} {sp:>10}  {v}")
EOF
done
log "3. vendor hardware features face-off…"
grep -hoE 'android\.hardware\.[a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)*' "$TREES/donor-vendor/etc/permissions/"*.xml 2>/dev/null | sed 's/\.xml.*//' | sort -u > /tmp/feat-donorv.txt || true
grep -hoE 'android\.hardware\.[a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)*' "$TREES/stock-vendor/etc/permissions/"*.xml 2>/dev/null | sed 's/\.xml.*//' | sort -u > /tmp/feat-stockv.txt || true
wc -l /tmp/feat-donorv.txt /tmp/feat-stockv.txt
echo "--- comm (< donor-only, > stock-only):"
comm -3 /tmp/feat-donorv.txt /tmp/feat-stockv.txt | head -50 || true
echo "--- full stock vendor list:"; cat /tmp/feat-stockv.txt || true
log "4. agares declaration…"
grep -rn 'agares' "$TREES/donor-product/etc/" "$TREES/donor-system_ext/etc/" 2>/dev/null | head || echo "(none)"
log "audit2 done."
