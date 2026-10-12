#!/bin/bash
# KD Mail – byg installationsfiler.  Brug: ./build.sh [linux] [win] [mac]   (standard: alle)
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"; cd "$REPO"
source kdmail.conf
TB_VERSION="${TB_VERSION_OVERRIDE:-$TB_VERSION}"
PLATS=("$@"); [ ${#PLATS[@]} -gt 0 ] || PLATS=(linux win mac)

echo "== KD-tilføjelse"
mkdir -p build && rm -f build/kd-mail.xpi
(cd extension && zip -qr -X ../build/kd-mail.xpi . -x '.*')

echo "== Henter Thunderbird"
python3 scripts/fetch.py "$TB_VERSION" "$TB_LOCALE" downloads "${PLATS[@]}"
TBV="$(cat downloads/VERSION)"; KDV="${TBV}-kd${KD_REVISION}"
echo "   KD Mail $KDV"

[ -d scripts/node_modules ] || (cd scripts && npm install --silent)
for p in "${PLATS[@]}"; do
  echo "== $p"
  case "$p" in
    linux) bash scripts/package-linux.sh "$KDV" ;;
    win)   bash scripts/package-windows.sh "$KDV" "$TBV" ;;
    mac)   bash scripts/package-mac.sh "$KDV" ;;
  esac
done
echo "== Færdig – se dist/"; ls -lh dist
