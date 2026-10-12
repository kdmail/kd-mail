#!/bin/bash
# KD Mail – macOS-diskbillede (.dmg), ad hoc-signeret
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"; KDV="$1"
DMG_TOOL="${DMG_TOOL:-dmg}"; HFS_TOOL="${HFS_TOOL:-hfsplus}"; RCODESIGN="${RCODESIGN:-rcodesign}"
W="$REPO/build/mac"; rm -rf "$W"; mkdir -p "$W/x" "$W/stage" "$REPO/dist"

# Udpak Mozillas .dmg
if "$DMG_TOOL" extract "$REPO/downloads/thunderbird-mac.dmg" "$W/tb.hfs" >/dev/null 2>&1 \
   && "$HFS_TOOL" "$W/tb.hfs" extractall / "$W/x" >/dev/null 2>&1; then :; else
  7z x -y -o"$W/x" "$REPO/downloads/thunderbird-mac.dmg" >/dev/null
fi
SRC_APP="$(find "$W/x" -maxdepth 3 -type d -name '*.app' | head -1)"
[ -n "$SRC_APP" ] || { echo "Fandt ingen .app i macOS-pakken"; exit 1; }
APP="$W/stage/KD Mail.app"
mv "$SRC_APP" "$APP"

python3 "$REPO/scripts/mac-bundle.py" "$APP" "$REPO" "$KDV"
python3 "$REPO/scripts/rebrand.py" "$APP/Contents/Resources" "$REPO" "$KDV"

# Ad hoc-signering af hver programfil for sig (uden Apple-certifikat).
# Mozillas Team ID og "hardened runtime" fjernes overalt – blandes de, nægter
# macOS at starte hjælpeprocesserne (plugin-container, crashhelper).
python3 "$REPO/scripts/mac-sign.py" "$RCODESIGN" "$APP" \
  "$REPO/packaging/mac/entitlements.plist" "$W/sign.log"

# Byg .dmg med genvej til Programmer
ln -s /Applications "$W/stage/Applications"
cp "$REPO/packaging/mac/"*.txt "$W/stage/"
MB=$(( $(du -sm "$W/stage" | cut -f1) * 12 / 10 + 20 ))
dd if=/dev/zero of="$W/kd.hfs" bs=1M count="$MB" status=none
mkfs.hfsplus -v "KD Mail" "$W/kd.hfs" >/dev/null
"$HFS_TOOL" "$W/kd.hfs" -s clone_link addall "$W/stage" >/dev/null
OUT="$REPO/dist/KD-Mail-$KDV-macOS.dmg"
"$DMG_TOOL" -c lzma build "$W/kd.hfs" "$OUT" >/dev/null 2>&1 || "$DMG_TOOL" build "$W/kd.hfs" "$OUT" >/dev/null
echo "  $OUT"
