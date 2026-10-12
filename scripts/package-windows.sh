#!/bin/bash
# KD Mail – Windows-installationsprogram (.exe)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"; KDV="$1"; TBV="$2"
W="$REPO/build/windows"; rm -rf "$W"; mkdir -p "$W" "$REPO/dist"
7z x -y -o"$W/setup" "$REPO/downloads/thunderbird-win.exe" >/dev/null
CORE="$W/setup/core"
[ -f "$CORE/thunderbird.exe" ] || { echo "Fandt ikke core/thunderbird.exe i Windows-pakken"; exit 1; }
python3 "$REPO/scripts/rebrand.py" "$CORE" "$REPO" "$KDV"
node "$REPO/scripts/set-exe-icon.mjs" "$CORE/thunderbird.exe" "$REPO/branding/kd-mail.ico" "$TBV"
OUT="$REPO/dist/KD-Mail-Setup-$KDV.exe"
makensis -V2 -DVERSION="$KDV" -DSRCDIR="$CORE" -DOUTFILE="$OUT" \
  -DICON="$REPO/branding/kd-mail.ico" "$REPO/packaging/windows/installer.nsi"
echo "  $OUT"
