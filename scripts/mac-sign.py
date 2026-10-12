#!/usr/bin/env python3
"""KD Mail – ad hoc-signering af hele macOS-app-pakken, indefra og ud.

Alle Mach-O-filer (programmer, hjælpeprogrammer, biblioteker) og alle
indlejrede bundles signeres hver for sig uden Mozillas Team ID og uden
"hardened runtime". Ellers nægter macOS at lade fx plugin-container indlæse
bibliotekerne ("different Team IDs"), og KD Mail kan ikke starte sine
hjælpeprocesser.

Brug: mac-sign.py <rcodesign> <KD Mail.app> <entitlements.plist> <log>
"""
import os
import subprocess
import sys

MACHO_MAGIC = {
    b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe",  # 32-bit
    b"\xfe\xed\xfa\xcf", b"\xcf\xfa\xed\xfe",  # 64-bit
    b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca",  # universal (fat)
}
BUNDLE_EXT = (".app", ".framework", ".appex", ".xpc", ".bundle", ".plugin")

rcodesign, app, entitlements, log_path = sys.argv[1:5]
log = open(log_path, "w")


def is_macho(path):
    try:
        with open(path, "rb") as f:
            head = f.read(8)
    except OSError:
        return False
    if head[:4] not in MACHO_MAGIC:
        return False
    # cafebabe bruges også af Java .class – fat Mach-O har få arkitekturer
    if head[:4] == b"\xca\xfe\xba\xbe":
        return int.from_bytes(head[4:8], "big") < 20
    return True


def sign(path, shallow=False):
    cmd = [rcodesign, "sign", "--code-signature-flags", "hard",
           "--entitlements-xml-file", entitlements]
    if shallow:
        cmd.append("--shallow")
    cmd.append(path)
    r = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT)
    if r.returncode != 0:
        log.flush()
        print(open(log_path).read()[-3000:])
        raise SystemExit(f"Signering fejlede: {path}")


def depth(p):
    return p.count(os.sep)


machos, bundles = [], []
for root, dirs, files in os.walk(app):
    for d in dirs:
        if d.endswith(BUNDLE_EXT):
            bundles.append(os.path.join(root, d))
    for f in files:
        p = os.path.join(root, f)
        if not os.path.islink(p) and is_macho(p):
            machos.append(p)

# 1) Alle Mach-O-filer, dybeste først
for p in sorted(machos, key=depth, reverse=True):
    sign(p)
# 2) Indlejrede bundles, dybeste først (binder Info.plist og ressourcer)
for b in sorted(bundles, key=depth, reverse=True):
    sign(b, shallow=True)
# 3) Selve KD Mail.app
sign(app, shallow=True)

# 4) Kontrol: ingen fil må have Team ID eller hardened runtime tilbage
bad = []
for p in machos:
    out = subprocess.run([rcodesign, "print-signature-info", p],
                         capture_output=True, text=True).stdout
    if "team_name" in out or "RUNTIME" in out or "code_directory" not in out:
        bad.append(os.path.relpath(p, app))
if bad:
    raise SystemExit("Disse filer er ikke signeret korrekt:\n  " + "\n  ".join(bad))
print(f"  ad hoc-signeret: {len(machos)} programfiler, {len(bundles)} indlejrede bundles – kontrolleret")
