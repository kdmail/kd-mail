#!/bin/bash
# KD Mail – byg installationsfiler.  Brug: ./build.sh [linux] [win] [mac]   (standard: alle)
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"; cd "$REPO"
source kdmail.conf
TB_VERSION="${TB_VERSION_OVERRIDE:-$TB_VERSION}"
PLATS=("$@"); [ ${#PLATS[@]} -gt 0 ] || PLATS=(linux win mac)

echo "== KD-tilføjelse"
mkdir -p build && rm -rf build/kd-mail.xpi build/extension
cp -R extension build/extension
# Nyt versionsnummer ved hvert byg – ellers beholder eksisterende profiler den gamle tilføjelse
EXT_VERSION="1.${KD_REVISION}.$(date -u +%y%j%H%M)"
python3 - "$EXT_VERSION" <<'PY'
import json, sys
p = "build/extension/manifest.json"
m = json.load(open(p, encoding="utf-8"))
m["version"] = sys.argv[1]
json.dump(m, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
PY
echo "   tilføjelse version $EXT_VERSION"
(cd build/extension && zip -qr -X ../kd-mail.xpi . -x '.*')

echo "== Henter Thunderbird"
python3 scripts/fetch.py "$TB_VERSION" "$TB_LOCALE" downloads "${PLATS[@]}"
TBV="$(cat downloads/VERSION)"; KDV="${TBV}-kd${KD_REVISION}"
echo "   KD Mail $KDV"

if [[ " ${PLATS[*]} " == *" win "* ]] && [ ! -d scripts/node_modules ]; then (cd scripts && npm install --silent); fi
for p in "${PLATS[@]}"; do
  echo "== $p"
  case "$p" in
    linux) bash scripts/package-linux.sh "$KDV" ;;
    win)   bash scripts/package-windows.sh "$KDV" "$TBV" ;;
    mac)   bash scripts/package-mac.sh "$KDV" ;;
  esac
done
echo "== Færdig – se dist/"; ls -lh dist
