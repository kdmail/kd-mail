#!/usr/bin/env python3
"""KD Mail – omdøber en udpakket Thunderbird til KD Mail.

Fælles for alle platforme. Arbejder på "resources"-mappen, dvs. mappen med
omni.ja og application.ini:
  Linux:   kd-mail/
  Windows: core/
  macOS:   KD Mail.app/Contents/Resources/

Brug: rebrand.py <resources-dir> <repo-dir> <kd-version>
"""
import base64
import io
import os
import re
import shutil
import sys
import time
import zipfile

from PIL import Image

NAME = "KD Mail"
ORANGE = "#F58220"
TRADEMARK = "KD Mail er baseret på Mozilla Thunderbird og udgives af Kristendemokraterne."

BRAND_FILE = re.compile(r"(^|/)branding/[^/]*\.(ftl|properties|dtd)$")
BRAND_IMAGE = re.compile(
    r"((^|/)branding/.*|thunderbird[-_]?logo[^/]*|logo[-_]?thunderbird[^/]*)\.(png|svg|ico)$", re.I
)


# ---------------------------------------------------------------- tekster
def patch_brand_text(path, text):
    out, skip_cont = [], False
    for line in text.splitlines(keepends=True):
        nl = "\n" if line.endswith("\n") else ""
        if skip_cont:
            if line[:1] in (" ", "\t") and line.strip():
                continue
            skip_cont = False
        if path.endswith(".ftl"):
            m = re.match(r"^(-brand-[a-z-]*name)\s*=", line)
            if m:
                out.append(f"{m.group(1)} = {NAME}{nl}")
                continue
            if re.match(r"^trademarkInfo\s*=", line):
                out.append(f"trademarkInfo = {TRADEMARK}{nl}")
                skip_cont = True
                continue
        elif path.endswith(".properties"):
            m = re.match(r"^(brand\w*Name)\s*=", line)
            if m:
                out.append(f"{m.group(1)}={NAME}{nl}")
                continue
            if re.match(r"^trademarkInfo", line):
                out.append(f"trademarkInfo={TRADEMARK}{nl}")
                continue
        elif path.endswith(".dtd"):
            m = re.match(r'^(<!ENTITY\s+brand\w*Name\s+)"[^"]*"', line)
            if m:
                out.append(f'{m.group(1)}"{NAME}">{nl}')
                continue
            if re.match(r"^<!ENTITY\s+trademarkInfo", line):
                key = re.match(r"^<!ENTITY\s+(\S+)", line).group(1)
                txt = TRADEMARK if key.endswith("part1") else ""
                out.append(f'<!ENTITY {key} "{txt}">{nl}')
                continue
        if "vendor" not in line.lower():
            line = line.replace("Mozilla Thunderbird", NAME)
            line = re.sub(r"\bThunderbird\b", NAME, line)
        out.append(line)
    return "".join(out)


# ---------------------------------------------------------------- billeder
class Art:
    def __init__(self, repo):
        self.icon = Image.open(os.path.join(repo, "branding", "kd-mail-1024.png")).convert("RGBA")
        buf = io.BytesIO()
        self.icon.resize((256, 256), Image.LANCZOS).save(buf, "PNG", optimize=True)
        self.icon_b64 = base64.b64encode(buf.getvalue()).decode()
        self.ico_path = os.path.join(repo, "branding", "kd-mail.ico")

    def png(self, data):
        try:
            w, h = Image.open(io.BytesIO(data)).size
        except Exception:
            w = h = 256
        side = min(w, h)
        canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        canvas.paste(self.icon.resize((side, side), Image.LANCZOS), ((w - side) // 2, (h - side) // 2))
        out = io.BytesIO()
        canvas.save(out, "PNG", optimize=True)
        return out.getvalue()

    def svg(self, name, data):
        txt = data.decode("utf-8", "replace")
        vb = re.search(r'viewBox="([^"]+)"', txt)
        if vb:
            x, y, w, h = (float(v) for v in re.split(r"[\s,]+", vb.group(1).strip()))
        else:
            ws = re.search(r'width="([\d.]+)', txt)
            hs = re.search(r'height="([\d.]+)', txt)
            x = y = 0
            w = float(ws.group(1)) if ws else 64
            h = float(hs.group(1)) if hs else 64
        if "wordmark" in name.lower():
            fs = h * 0.8
            return (
                f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}">'
                f'<text x="{x}" y="{y + h * 0.82}" font-family="Arial, Helvetica, sans-serif" '
                f'font-weight="700" font-size="{fs}" fill="{ORANGE}" textLength="{w}" '
                f'lengthAdjust="spacingAndGlyphs">{NAME}</text></svg>'
            ).encode()
        side = min(w, h)
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}">'
            f'<image x="{x + (w - side) / 2}" y="{y + (h - side) / 2}" width="{side}" height="{side}" '
            f'href="data:image/png;base64,{self.icon_b64}"/></svg>'
        ).encode()

    def ico(self):
        with open(self.ico_path, "rb") as f:
            return f.read()

    def replace(self, name, data):
        low = name.lower()
        if low.endswith(".png"):
            return self.png(data)
        if low.endswith(".svg"):
            return self.svg(os.path.basename(name), data)
        if low.endswith(".ico"):
            return self.ico()
        return data


# ---------------------------------------------------------------- omni.ja
def rebrand_omni(path, art):
    changed = {"text": 0, "image": 0}
    tmp = path + ".new"
    with zipfile.ZipFile(path) as src, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as dst:
        for info in src.infolist():
            data = src.read(info.filename)
            name = info.filename
            if BRAND_FILE.search(name):
                data = patch_brand_text(name, data.decode("utf-8")).encode("utf-8")
                changed["text"] += 1
            elif BRAND_IMAGE.search(name):
                data = art.replace(name, data)
                changed["image"] += 1
            zi = zipfile.ZipInfo(name, date_time=info.date_time)
            zi.external_attr = info.external_attr
            zi.compress_type = zipfile.ZIP_STORED if name.endswith("/") else zipfile.ZIP_DEFLATED
            dst.writestr(zi, data)
    os.replace(tmp, path)
    return changed


# ---------------------------------------------------------------- application.ini
def patch_application_ini(path, build_id):
    lines = open(path, encoding="utf-8").read().splitlines()
    out, section, seen = [], None, set()
    # Kun BuildID ændres (tvinger Thunderbird til at genindlæse den omdøbte omni.ja).
    # Name/Profile røres ikke – det får profilstyringen til at fejle. KD Mail får alligevel
    # sin egen profil, fordi Thunderbird giver hver installationsmappe sin egen standardprofil.
    want = {"BuildID": build_id}

    def flush_missing():
        if section == "App":
            trailing = []
            while out and not out[-1].strip():
                trailing.append(out.pop())
            for k, v in want.items():
                if k not in seen:
                    out.append(f"{k}={v}")
            out.extend(trailing)

    for line in lines:
        m = re.match(r"^\[(.+)\]\s*$", line)
        if m:
            flush_missing()
            section = m.group(1)
            out.append(line)
            continue
        if section == "App" and "=" in line:
            k = line.split("=", 1)[0].strip()
            if k in want:
                out.append(f"{k}={want[k]}")
                seen.add(k)
                continue
        out.append(line)
    flush_missing()
    open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")


# ---------------------------------------------------------------- løse ikoner
def replace_loose_icons(res, art):
    n = 0
    for sub in ("chrome/icons", "icons", "browser/chrome/icons"):
        d = os.path.join(res, sub)
        for root, _, files in os.walk(d):
            for f in files:
                p = os.path.join(root, f)
                if f.lower().endswith((".png", ".ico")):
                    with open(p, "rb") as fh:
                        data = fh.read()
                    with open(p, "wb") as fh:
                        fh.write(art.replace(f, data))
                    n += 1
    return n


UPDATER_FILES = [
    "updater", "updater.exe", "updater.ini", "update-settings.ini",
    "maintenanceservice.exe", "maintenanceservice_installer.exe",
]


def main():
    res, repo, kd_version = sys.argv[1:4]
    art = Art(repo)

    omni = os.path.join(res, "omni.ja")
    print("  omni.ja:", rebrand_omni(omni, art))

    patch_application_ini(os.path.join(res, "application.ini"), time.strftime("%Y%m%d%H%M%S", time.gmtime()))
    print("  application.ini: ny BuildID")

    print("  løse ikoner:", replace_loose_icons(res, art))

    for f in UPDATER_FILES:
        p = os.path.join(res, f)
        if os.path.exists(p):
            os.remove(p)

    dist = os.path.join(res, "distribution")
    os.makedirs(os.path.join(dist, "extensions"), exist_ok=True)
    shutil.copy(os.path.join(repo, "distribution", "policies.json"), os.path.join(dist, "policies.json"))
    shutil.copy(os.path.join(repo, "build", "kd-mail.xpi"), os.path.join(dist, "extensions", "kd-mail@kd.dk.xpi"))
    with open(os.path.join(dist, "distribution.ini"), "w", encoding="utf-8") as f:
        f.write(f"[Global]\nid=kd-mail\nversion={kd_version}\nabout={NAME}\n")
    print("  distribution: politikker + KD-tilføjelse")


if __name__ == "__main__":
    main()
