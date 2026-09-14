#!/usr/bin/env bash
# step-final-audit.sh — FINAL CROSS-CHECK stock T1101 vs donor T1103:
# extract donor vendor + face off build.props, HAL manifests (vendor-vs-vendor
# AND framework-requires-vs-vendor-provides), linker/VNDK, insmod refs, APEXs,
# hardware features, BOOTCLASSPATH hunt. Read-only (one new tree). ~8 min.
# Independent of the DSU test — run both in parallel.
# Usage: bash port/scripts/step-final-audit.sh
set -euo pipefail
set -E
. "$(dirname "$0")/lib.sh"
trap 'log "!!! FAILED at line $LINENO: $BASH_COMMAND"' ERR
BASE="${BASE:-$HOME/hios-port}"
WORK="$BASE/work"; TREES="$BASE/trees"
S="$PORT_ROOT/scripts"
DONOR_RAW="${DONOR_RAW:-$BASE/donor-super.raw}"
log "0. supers on disk + space…"
ls -l "$BASE"/*.raw "$BASE"/*.img 2>/dev/null || true
find "$BASE" -maxdepth 3 -iname '*super*' 2>/dev/null | head || true
df -h "$BASE" | tail -1
log "1. extract donor vendor_a (655MB)…"
bash "$S/02-unpack-one.sh" "$DONOR_RAW" vendor "$WORK/" a 2>&1 | tail -3
bash "$S/03-extract-erofs-lowram.sh" "$WORK/vendor_t1103.img" "$TREES/donor-vendor" 2>&1 | tail -3
du -sh "$TREES/donor-vendor"
log "2. vendor build.prop face-off…"
for p in "$TREES/stock-vendor/build.prop" "$TREES/donor-vendor/build.prop"; do
  echo "--- $p"
  grep -E 'ro\.(product\.vendor\.(device|model|brand|name)|vendor\.build\.(fingerprint|version|id)|build\.version\.sdk|board\.first_api_level|vndk\.version)' "$p" 2>/dev/null || echo "(no matches)"
done
log "3. HAL face-off: donor vendor (expects) vs stock vendor (provides)…"
python3 - "$TREES/donor-vendor/etc/vintf/manifest.xml" "$TREES/stock-vendor/etc/vintf/manifest.xml" <<'EOF' || true
import sys, xml.etree.ElementTree as ET
def load(path):
    try:
        r = ET.parse(path).getroot()
    except Exception as e:
        print(f"(cannot parse {path}: {e})"); return {}
    out = {}
    for hal in r.iter('hal'):
        n = hal.findtext('name')
        vs = [v.text.strip() for v in hal.findall('version') if v.text and v.text.strip()]
        if n: out.setdefault(n.strip(), set()).update(vs)
    return out
def vmax(vs):
    ps = []
    for v in vs:
        try: ps.append(tuple(int(x) for x in v.split('.')))
        except ValueError: pass
    return max(ps) if ps else ()
a, b = load(sys.argv[1]), load(sys.argv[2])
print(f"(parsed {len(a)} donor HALs, {len(b)} stock HALs)")
print(f"{'HAL':52} {'donor':>10} {'stock':>10}  verdict")
for n in sorted(set(a) | set(b)):
    va, vb = a.get(n, set()), b.get(n, set())
    sa = ','.join(sorted(va)) or '-'; sb = ','.join(sorted(vb)) or '-'
    if not va: v = 'ONLY-STOCK'
    elif not vb: v = 'ONLY-DONOR'
    elif va == vb: v = 'SAME'
    elif vmax(va) > vmax(vb): v = 'DONOR-NEWER'
    elif vmax(va) < vmax(vb): v = 'STOCK-NEWER'
    else: v = 'SAME-MAX'
    print(f"{n:52} {sa:>10} {sb:>10}  {v}")
EOF
log "4. framework manifest requirements vs stock vendor…"
FM="$(find "$TREES/donor-system" -path '*vintf*manifest.xml' 2>/dev/null | head -1 || true)"
echo "framework manifest: ${FM:-<none found>}"
if [[ -n "$FM" ]]; then
python3 - "$FM" "$TREES/stock-vendor/etc/vintf/manifest.xml" <<'EOF' || true
import sys, re, xml.etree.ElementTree as ET
def vers(s):
    try: return tuple(int(x) for x in s.split('.'))
    except ValueError: return None
try:
    fr = ET.parse(sys.argv[1]).getroot()
except Exception as e:
    print(f"(cannot parse framework manifest: {e})"); sys.exit(0)
req = {}
for hal in fr.iter('hal'):
    n = hal.findtext('name')
    vs = set()
    for v in hal.findall('version'):
        if v.text and v.text.strip(): vs.add(v.text.strip())
    for f in hal.findall('fqname'):
        m = re.match(r'(.+)@(\d+)\.(\d+)::', (f.text or '').strip())
        if m: n = n or m.group(1); vs.add(f"{m.group(2)}.{m.group(3)}")
    if n: req.setdefault(n.strip(), set()).update(vs)
try:
    vr = ET.parse(sys.argv[2]).getroot()
except Exception as e:
    print(f"(cannot parse vendor manifest: {e})"); sys.exit(0)
prov = {}
for hal in vr.iter('hal'):
    n = hal.findtext('name')
    vs = [v.text.strip() for v in hal.findall('version') if v.text and v.text.strip()]
    if n: prov.setdefault(n.strip(), set()).update(vs)
print(f"(framework requires {len(req)} HALs)")
print(f"{'HAL':52} {'required':>10} {'stock-has':>10}  verdict")
for n in sorted(req):
    rv, pv = req[n], prov.get(n, set())
    sr = ','.join(sorted(rv)) or '-'; sp = ','.join(sorted(pv)) or '-'
    ok = any(vers(r) and vers(p) and vers(p)[0] == vers(r)[0] and vers(p) >= vers(r) for r in rv for p in pv)
    v = 'OK' if ok else ('SHORT' if pv else 'MISSING')
    print(f"{n:52} {sr:>10} {sp:>10}  {v}")
EOF
fi
log "5. linker/VNDK peek…"
ls "$TREES/donor-system/system/etc/" | grep -i linker || echo "(no donor linker configs)"
ls -d "$TREES/stock-vendor/lib/vndk"* "$TREES/stock-vendor/lib64/vndk"* 2>/dev/null || echo "(no stock vndk dirs?)"
ls -d "$TREES/donor-vendor/lib/vndk"* "$TREES/donor-vendor/lib64/vndk"* 2>/dev/null || echo "(no donor vndk dirs?)"
log "6. insmod refs in donor init…"
grep -rn 'insmod' "$TREES/donor-system/system/etc/init/" 2>/dev/null | head -20 || echo "(none)"
log "7. APEX lists…"
for d in "$TREES/donor-system/system/apex" "$TREES/donor-system_ext/apex" "$TREES/stock-system/system/apex" "$TREES/stock-system_ext/apex"; do echo "--- $d"; ls "$d" 2>/dev/null || echo "(missing)"; done
log "8. hardware features face-off (comm: < donor-only, > stock-only)…"
grep -hoE 'android\.hardware\.[a-zA-Z0-9_.]+' "$TREES/donor-system/system/etc/permissions/"*.xml "$TREES/donor-system_ext/etc/permissions/"*.xml "$TREES/donor-product/etc/permissions/"*.xml "$TREES/donor-tr_product/etc/permissions/"*.xml 2>/dev/null | sort -u > /tmp/feat-donor.txt || true
grep -hoE 'android\.hardware\.[a-zA-Z0-9_.]+' "$TREES/stock-system/system/etc/permissions/"*.xml "$TREES/stock-system_ext/etc/permissions/"*.xml "$TREES/stock-product/etc/permissions/"*.xml 2>/dev/null | sort -u > /tmp/feat-stock.txt || true
wc -l /tmp/feat-donor.txt /tmp/feat-stock.txt
comm -3 /tmp/feat-donor.txt /tmp/feat-stock.txt | head -40 || true
echo "--- stock vendor declares:"; grep -hoE 'android\.hardware\.[a-zA-Z0-9_.]+' "$TREES/stock-vendor/etc/permissions/"*.xml 2>/dev/null | sort -u | head -30 || echo "(none)"
log "9. BOOTCLASSPATH closing hunt…"
echo "--- donor apex:"; ls "$TREES/donor-system/system/apex/" 2>/dev/null || echo "(none)"
echo "--- BCP in vendor init:"; grep -rn 'BOOTCLASSPATH' "$TREES/stock-vendor/etc/init/" "$TREES/donor-vendor/etc/init/" 2>/dev/null | head || echo "(none)"
FL="$(find "$TREES" -name build.prop 2>/dev/null || true)"
[[ -n "$FL" ]] && grep -rn -i 'bootclasspath' $FL 2>/dev/null | head || echo "(none in build.props)"
echo "--- agares refs:"; grep -rln 'agares' "$TREES/donor-system/system/etc" "$TREES/donor-vendor/etc" 2>/dev/null | head || echo "(none)"
log "10. donor vendor shape…"
du -d1 "$TREES/donor-vendor" 2>/dev/null | sort -rh | head -15 || true
echo "donor vendor libCamera count: $(find "$TREES/donor-vendor" -name 'libCamera_*' 2>/dev/null | wc -l)"
log "audit done. Paste it all back (or in halves if cut)."
