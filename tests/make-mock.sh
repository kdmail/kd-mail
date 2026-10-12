#!/bin/bash
# Laver falske Thunderbird-pakker med samme struktur som de rigtige, så
# byggesystemet kan testes uden netadgang til Mozilla.  Brug: tests/make-mock.sh <outdir>
set -euo pipefail
OUT="$(realpath -m "$1")"; T="$(mktemp -d)"; mkdir -p "$OUT"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
DMG_TOOL="${DMG_TOOL:-dmg}"; HFS_TOOL="${HFS_TOOL:-hfsplus}"

python3 - "$T/omni.ja" <<'PY'
import sys, zipfile, io
from PIL import Image
def png(w,h):
    b=io.BytesIO(); Image.new("RGBA",(w,h),(10,132,255,255)).save(b,"PNG"); return b.getvalue()
z=zipfile.ZipFile(sys.argv[1],"w")
z.writestr("localization/da/branding/brand.ftl","""-brand-shorter-name = Thunderbird
-brand-short-name = Thunderbird
-brand-full-name = Mozilla Thunderbird
-brand-product-name = Thunderbird
-vendor-short-name = Mozilla
trademarkInfo = Mozilla Thunderbird og Thunderbird-logoerne er
    varemærker tilhørende Mozilla Foundation.
""")
z.writestr("chrome/da/locale/branding/brand.properties","brandShorterName=Thunderbird\nbrandShortName=Thunderbird\nbrandFullName=Mozilla Thunderbird\nvendorShortName=Mozilla\n")
z.writestr("chrome/da/locale/branding/brand.dtd",'<!ENTITY brandShortName "Thunderbird">\n<!ENTITY brandFullName "Mozilla Thunderbird">\n<!ENTITY trademarkInfo.part1 "Mozilla trademark">\n')
z.writestr("chrome/messenger/content/branding/icon64.png",png(64,64))
z.writestr("chrome/messenger/content/branding/about.png",png(300,120))
z.writestr("chrome/messenger/content/branding/about-wordmark.svg",'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 172 42"><path d="M0 0h172v42H0z"/></svg>')
z.writestr("chrome/messenger/content/messenger/other.js","// uændret\n")
z.close()
PY
cat > "$T/application.ini" <<'INI'
[App]
Vendor=
Name=Thunderbird
RemotingName=thunderbird
Version=999.0esr
BuildID=20260101000000
ID={3550f703-e582-4d05-9a08-453d09bdfdc6}

[Gecko]
MinVersion=999.0
INI
python3 -c "
from PIL import Image
im=Image.new('RGBA',(256,256),(10,132,255,255))
im.save('$T/blue.ico',sizes=[(16,16),(32,32),(48,48)]); im.save('$T/blue.png')"

# Linux
L="$T/linux/thunderbird"; mkdir -p "$L/chrome/icons/default"
cp "$T/omni.ja" "$T/application.ini" "$L/"; printf '#!/bin/sh\necho mock\n' > "$L/thunderbird"; chmod +x "$L/thunderbird"; touch "$L/updater"
for s in 16 32 48 128; do python3 -c "from PIL import Image; Image.new('RGBA',($s,$s),(10,132,255,255)).save('$L/chrome/icons/default/default$s.png')"; done
tar -C "$T/linux" -cJf "$OUT/thunderbird-linux.tar.xz" thunderbird

# Windows – rigtig PE-fil med ikon og versionsinfo (lille NSIS-program)
cat > "$T/mock.nsi" <<'NSI'
Unicode true
OutFile "thunderbird.exe"
Icon "blue.ico"
VIProductVersion "999.0.0.0"
VIAddVersionKey "FileDescription" "Thunderbird"
VIAddVersionKey "ProductName" "Thunderbird"
VIAddVersionKey "FileVersion" "999.0"
Section
SectionEnd
NSI
(cd "$T" && makensis -V1 mock.nsi)
C="$T/win/core"; mkdir -p "$C/chrome/icons/default"
cp "$T/omni.ja" "$T/application.ini" "$T/thunderbird.exe" "$C/"; cp "$T/blue.ico" "$C/chrome/icons/default/messengerWindow.ico"; touch "$C/updater.exe"
(cd "$T/win" && 7z a -bd -y "$OUT/thunderbird-win.exe" core setup.exe >/dev/null 2>&1 || 7z a -bd -y "$OUT/thunderbird-win.exe" core >/dev/null)

# macOS
A="$T/mac/Thunderbird.app/Contents"; mkdir -p "$A/MacOS/updater.app" "$A/Resources/da.lproj" "$A/_CodeSignature"
cp "$T/omni.ja" "$T/application.ini" "$A/Resources/"; cp "$T/blue.png" "$A/Resources/thunderbird.icns"
# MOCK_MACHO = sti til en vilkårlig Mach-O-fil (fx en .so fra et macOS-wheel), så signering kan testes
if [ -n "${MOCK_MACHO:-}" ]; then cp "$MOCK_MACHO" "$A/MacOS/thunderbird"; cp "$MOCK_MACHO" "$A/MacOS/XUL"; else printf '#!/bin/sh\necho mock\n' > "$A/MacOS/thunderbird"; fi
chmod +x "$A/MacOS/thunderbird"
printf 'CFBundleName = "Thunderbird";\n' | iconv -t UTF-16 > "$A/Resources/da.lproj/InfoPlist.strings"
python3 -c "
import plistlib; plistlib.dump({'CFBundleName':'Thunderbird','CFBundleExecutable':'thunderbird','CFBundleIdentifier':'org.mozilla.thunderbird','CFBundleIconFile':'thunderbird','CFBundleIconName':'AppIcon','CFBundlePackageType':'APPL'}, open('$A/Info.plist','wb'))"
ln -s /Applications "$T/mac/ "
dd if=/dev/zero of="$T/m.hfs" bs=1M count=20 status=none; mkfs.hfsplus -v Thunderbird "$T/m.hfs" >/dev/null
"$HFS_TOOL" "$T/m.hfs" -s clone_link addall "$T/mac" >/dev/null
"$DMG_TOOL" -c lzma build "$T/m.hfs" "$OUT/thunderbird-mac.dmg" >/dev/null 2>&1 || "$DMG_TOOL" build "$T/m.hfs" "$OUT/thunderbird-mac.dmg" >/dev/null
echo "999.0esr" > "$OUT/VERSION"
rm -rf "$T"; ls -la "$OUT"
