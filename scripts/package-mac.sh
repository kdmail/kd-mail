#!/bin/bash
# KD Mail – macOS-installer (.pkg) og diskbillede (.dmg), ad hoc-signeret.
# Kører bedst på en Mac (GitHub "macos"-runner) med Apples egne værktøjer.
# På Linux bruges libdmg-hfsplus + rcodesign (kun til test – Gatekeeper kan afvise resultatet).
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"; KDV="$1"
W="$REPO/build/mac"; rm -rf "$W"; mkdir -p "$W/x" "$W/stage" "$W/pkgroot" "$REPO/dist"
APP="$W/stage/KD Mail.app"
DARWIN=0; [ "$(uname)" = "Darwin" ] && DARWIN=1

# 1) Udpak Mozillas .dmg
if [ "$DARWIN" -eq 1 ]; then
  MNT="$(mktemp -d)"
  hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$REPO/downloads/thunderbird-mac.dmg" >/dev/null
  SRC_APP="$(find "$MNT" -maxdepth 1 -type d -name '*.app' | head -1)"
  [ -n "$SRC_APP" ] || { hdiutil detach "$MNT" -quiet; echo "Fandt ingen .app i macOS-pakken"; exit 1; }
  ditto "$SRC_APP" "$APP"
  hdiutil detach "$MNT" -quiet
else
  DMG_TOOL="${DMG_TOOL:-dmg}"; HFS_TOOL="${HFS_TOOL:-hfsplus}"
  if "$DMG_TOOL" extract "$REPO/downloads/thunderbird-mac.dmg" "$W/tb.hfs" >/dev/null 2>&1 \
     && "$HFS_TOOL" "$W/tb.hfs" extractall / "$W/x" >/dev/null 2>&1; then :; else
    7z x -y -o"$W/x" "$REPO/downloads/thunderbird-mac.dmg" >/dev/null
  fi
  SRC_APP="$(find "$W/x" -maxdepth 3 -type d -name '*.app' | head -1)"
  [ -n "$SRC_APP" ] || { echo "Fandt ingen .app i macOS-pakken"; exit 1; }
  mv "$SRC_APP" "$APP"
fi

# 2) Omdøb til KD Mail
python3 "$REPO/scripts/mac-bundle.py" "$APP" "$REPO" "$KDV"
python3 "$REPO/scripts/rebrand.py" "$APP/Contents/Resources" "$REPO" "$KDV"

# 3) Ad hoc-signering af hver programfil for sig
if [ "$DARWIN" -eq 1 ]; then
  bash "$REPO/scripts/mac-sign-native.sh" "$APP"
else
  python3 "$REPO/scripts/mac-sign.py" "${RCODESIGN:-rcodesign}" "$APP" \
    "$REPO/packaging/mac/entitlements.plist" "$W/sign.log"
fi

# 4) .pkg – anbefalet: Installer lægger KD Mail i Programmer uden karantæne
if [ "$DARWIN" -eq 1 ]; then
  ditto "$APP" "$W/pkgroot/KD Mail.app"
  pkgbuild --analyze --root "$W/pkgroot" "$W/component.plist" >/dev/null
  plutil -replace 0.BundleIsRelocatable -bool NO "$W/component.plist"
  plutil -replace 0.BundleOverwriteAction -string upgrade "$W/component.plist" 2>/dev/null || true
  PKG="$REPO/dist/KD-Mail-$KDV-macOS.pkg"
  BASE="${KDV%%-*}"; PKGV="${BASE//[^0-9.]/}.${KDV##*-kd}"
  pkgbuild --root "$W/pkgroot" --component-plist "$W/component.plist" \
    --identifier dk.kd.mail --version "$PKGV" --install-location /Applications \
    "$PKG" >/dev/null
  echo "  $PKG"
fi

# 5) .dmg med genvej til Programmer
ln -s /Applications "$W/stage/Applications"
cp "$REPO/packaging/mac/"*.txt "$W/stage/"
OUT="$REPO/dist/KD-Mail-$KDV-macOS.dmg"
if [ "$DARWIN" -eq 1 ]; then
  hdiutil create -volname "KD Mail" -srcfolder "$W/stage" -fs HFS+ -format UDZO -ov "$OUT" >/dev/null
else
  MB=$(( $(du -sm "$W/stage" | cut -f1) * 12 / 10 + 20 ))
  dd if=/dev/zero of="$W/kd.hfs" bs=1M count="$MB" status=none
  mkfs.hfsplus -v "KD Mail" "$W/kd.hfs" >/dev/null
  "$HFS_TOOL" "$W/kd.hfs" -s clone_link addall "$W/stage" >/dev/null
  "$DMG_TOOL" -c lzma build "$W/kd.hfs" "$OUT" >/dev/null 2>&1 || "$DMG_TOOL" build "$W/kd.hfs" "$OUT" >/dev/null
fi
echo "  $OUT"
