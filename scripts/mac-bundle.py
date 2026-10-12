#!/usr/bin/env python3
"""KD Mail – macOS-specifik omdøbning af app-bundlen.

Brug: mac-bundle.py <KD Mail.app> <repo-dir> <kd-version>
"""
import os
import plistlib
import re
import shutil
import sys

app, repo, kd_version = sys.argv[1:4]
contents = os.path.join(app, "Contents")
res = os.path.join(contents, "Resources")

# Info.plist
plist_path = os.path.join(contents, "Info.plist")
with open(plist_path, "rb") as f:
    pl = plistlib.load(f)
icon_file = pl.get("CFBundleIconFile", "thunderbird.icns")
if not icon_file.endswith(".icns"):
    icon_file += ".icns"
pl.update({
    "CFBundleName": "KD Mail",
    "CFBundleDisplayName": "KD Mail",
    "CFBundleIdentifier": "dk.kd.mail",
    "CFBundleGetInfoString": f"KD Mail {kd_version}",
    "NSHumanReadableCopyright": "KD Mail er baseret på Mozilla Thunderbird (MPL 2.0)",
    "CFBundleIconFile": icon_file,
})
pl.pop("CFBundleIconName", None)  # tving brug af .icns frem for Assets.car
for k in ("SMPrivilegedExecutables",):
    pl.pop(k, None)
with open(plist_path, "wb") as f:
    plistlib.dump(pl, f)
print("  Info.plist: KD Mail / dk.kd.mail")

# Lokaliserede navne (InfoPlist.strings)
n = 0
for root, _, files in os.walk(res):
    for fn in files:
        if fn != "InfoPlist.strings":
            continue
        p = os.path.join(root, fn)
        raw = open(p, "rb").read()
        enc = "utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8"
        txt = raw.decode(enc)
        txt = re.sub(r'(CFBundle(?:Display)?Name\s*=\s*)"[^"]*"', r'\1"KD Mail"', txt)
        txt = txt.replace("Mozilla Thunderbird", "KD Mail").replace("Thunderbird", "KD Mail")
        open(p, "wb").write(txt.encode(enc))
        n += 1
print(f"  InfoPlist.strings: {n} sprog")

# Ikon – erstat alle .icns i Resources (app-ikon og evt. dokumentikoner)
kd_icns = os.path.join(repo, "branding", "kd-mail.icns")
for fn in os.listdir(res):
    if fn.endswith(".icns"):
        shutil.copy(kd_icns, os.path.join(res, fn))
shutil.copy(kd_icns, os.path.join(res, icon_file))
assets = os.path.join(res, "Assets.car")
if os.path.exists(assets):
    os.remove(assets)
print(f"  ikon: {icon_file}")

# Fjern Mozillas opdateringsprogram (KD Mail opdateres via nye KD-pakker)
for p in (
    os.path.join(contents, "MacOS", "updater.app"),
    os.path.join(contents, "Library", "LaunchServices"),
):
    if os.path.exists(p):
        shutil.rmtree(p)

# Gamle signaturer er ugyldige efter ændringerne – fjern dem, så de kan erstattes ad hoc
for root, dirs, _ in os.walk(app):
    for d in list(dirs):
        if d == "_CodeSignature":
            shutil.rmtree(os.path.join(root, d))
            dirs.remove(d)
for name in ("CodeResources",):
    p = os.path.join(contents, name)
    if os.path.exists(p):
        os.remove(p)

# Sikr kørselsrettigheder (nogle udpakkere mister dem)
for root, _, files in os.walk(os.path.join(contents, "MacOS")):
    for fn in files:
        p = os.path.join(root, fn)
        if not os.path.islink(p):
            os.chmod(p, 0o755 if (root.endswith("MacOS") or fn.endswith(".dylib") or "." not in fn) else os.stat(p).st_mode)
