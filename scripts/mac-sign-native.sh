#!/bin/bash
# KD Mail – ad hoc-signering på en rigtig Mac med Apples eget codesign.
# Hver programfil signeres for sig, indefra og ud, uden Mozillas Team ID og
# uden "hardened runtime". Til sidst kontrolleres hele pakken som Gatekeeper gør.
# Brug: mac-sign-native.sh "<KD Mail.app>"
set -euo pipefail
APP="$1"
xattr -cr "$APP"

depth_sort() { awk -F/ '{print NF "\t" $0}' | sort -rn | cut -f2-; }

# 1) Alle Mach-O-filer (programmer, hjælpeprogrammer, biblioteker), dybeste først
MACHOS="$(mktemp)"
find "$APP" -type f -print0 | while IFS= read -r -d '' f; do
  if file -b "$f" | grep -q "Mach-O"; then printf '%s\n' "$f"; fi
done | depth_sort > "$MACHOS"
while IFS= read -r f; do
  codesign --force --sign - --timestamp=none "$f"
done < "$MACHOS"

# 2) Indlejrede bundles, dybeste først
find "$APP" -mindepth 1 -type d \( -name '*.app' -o -name '*.framework' -o -name '*.appex' \
  -o -name '*.xpc' -o -name '*.bundle' -o -name '*.plugin' \) | depth_sort | while IFS= read -r b; do
  codesign --force --sign - --timestamp=none "$b"
done

# 3) Selve KD Mail.app
codesign --force --sign - --timestamp=none "$APP"

# 4) Kontrol
codesign --verify --deep --strict --verbose=1 "$APP"
BAD=0
while IFS= read -r f; do
  INFO="$(codesign -dv --verbose=2 "$f" 2>&1 || true)"
  if echo "$INFO" | grep -q "TeamIdentifier=" && ! echo "$INFO" | grep -q "TeamIdentifier=not set"; then
    echo "  Team ID tilbage: $f"; BAD=1
  fi
  if echo "$INFO" | grep -q "flags=.*runtime"; then
    echo "  Hardened runtime tilbage: $f"; BAD=1
  fi
done < "$MACHOS"
[ "$BAD" -eq 0 ] || { echo "Signeringen er ikke korrekt"; exit 1; }
echo "  ad hoc-signeret med codesign: $(wc -l < "$MACHOS" | tr -d ' ') programfiler – kontrolleret"
