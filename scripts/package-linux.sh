#!/bin/bash
# KD Mail – Linux-pakker (.deb til Ubuntu/Debian/Mint, .rpm til Fedora/openSUSE)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"; KDV="$1"
W="$REPO/build/linux"; rm -rf "$W"; mkdir -p "$W" "$REPO/dist"
tar -xf "$REPO"/downloads/thunderbird-linux.tar.* -C "$W"
mv "$W/thunderbird" "$W/kd-mail"
python3 "$REPO/scripts/rebrand.py" "$W/kd-mail" "$REPO" "$KDV"

# Skrivebordsfil og ikoner
cat > "$W/kd-mail/kd-mail.desktop" <<DESK
[Desktop Entry]
Name=KD Mail
Comment=Kristendemokraternes mailprogram
GenericName=Mailprogram
Exec=kd-mail %u
Icon=kd-mail
Terminal=false
Type=Application
Categories=Network;Email;
MimeType=x-scheme-handler/mailto;message/rfc822;
StartupWMClass=kdmail
DESK
cp "$REPO/branding/kd-mail-256.png" "$W/kd-mail/kd-mail.png"

# .deb
D="$W/deb"
mkdir -p "$D/DEBIAN" "$D/opt" "$D/usr/bin" "$D/usr/share/applications"
cp -a "$W/kd-mail" "$D/opt/kd-mail"
ln -s /opt/kd-mail/thunderbird "$D/usr/bin/kd-mail"
mv "$D/opt/kd-mail/kd-mail.desktop" "$D/usr/share/applications/kd-mail.desktop"
for s in 16 22 24 32 48 64 128 256 512; do
  install -Dm644 "$REPO/branding/kd-mail-$s.png" "$D/usr/share/icons/hicolor/${s}x${s}/apps/kd-mail.png"
done
SIZE=$(du -sk "$D" | cut -f1)
cat > "$D/DEBIAN/control" <<CTRL
Package: kd-mail
Version: $KDV
Architecture: amd64
Maintainer: Kristendemokraterne <it@kd.dk>
Installed-Size: $SIZE
Depends: libgtk-3-0 | libgtk-3-0t64, libasound2 | libasound2t64, libx11-xcb1
Section: mail
Priority: optional
Homepage: https://kd.dk
Description: KD Mail – Kristendemokraternes mailprogram
 Mailprogram baseret på Mozilla Thunderbird, forudindstillet til @kd.dk-mail
 med automatisk KD-signatur.
CTRL
cat > "$D/DEBIAN/postinst" <<'POST'
#!/bin/sh
set -e
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q /usr/share/icons/hicolor || true
command -v update-desktop-database >/dev/null && update-desktop-database -q || true
POST
chmod 755 "$D/DEBIAN/postinst"
DEB="$REPO/dist/kd-mail_${KDV}_amd64.deb"
dpkg-deb --root-owner-group -Zxz --build "$D" "$DEB" >/dev/null
echo "  $DEB"

# .rpm (samme filer som .deb)
if command -v rpmbuild >/dev/null; then
  RPMV="${KDV%-*}"; RPMR="${KDV##*-}"
  RT="$W/rpm"; mkdir -p "$RT"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
  cat > "$RT/SPECS/kd-mail.spec" <<SPEC
Name: kd-mail
Version: $RPMV
Release: $RPMR
Summary: KD Mail – Kristendemokraternes mailprogram
License: MPL-2.0
URL: https://kd.dk
BuildArch: x86_64
AutoReqProv: no
Requires: gtk3, alsa-lib
%description
Mailprogram baseret på Mozilla Thunderbird, forudindstillet til @kd.dk-mail
med automatisk KD-signatur.
%install
cp -a "$D/opt" "$D/usr" %{buildroot}/
%post
gtk-update-icon-cache -q /usr/share/icons/hicolor >/dev/null 2>&1 || :
update-desktop-database -q >/dev/null 2>&1 || :
%files
/opt/kd-mail
/usr/bin/kd-mail
/usr/share/applications/kd-mail.desktop
/usr/share/icons/hicolor/*/apps/kd-mail.png
SPEC
  rpmbuild --quiet --define "_topdir $RT" --define "_build_id_links none" \
    --define "__os_install_post %{nil}" -bb "$RT/SPECS/kd-mail.spec"
  RPM="$REPO/dist/kd-mail-${RPMV}-${RPMR}.x86_64.rpm"
  cp "$RT"/RPMS/x86_64/*.rpm "$RPM"
  echo "  $RPM"
else
  echo "  (rpmbuild mangler – springer .rpm over)"
fi
