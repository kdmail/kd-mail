#!/usr/bin/env python3
"""Henter officielle Thunderbird-pakker fra archive.mozilla.org.

Brug: fetch.py <version|esr|release> <locale> <outdir> [linux win mac]
Skriver den endelige version til <outdir>/VERSION.
"""
import json
import os
import re
import sys
import urllib.parse
import urllib.request

ARCHIVE = "https://archive.mozilla.org/pub/thunderbird/releases"
PLATFORMS = {
    "linux": ("linux-x86_64", (".tar.xz", ".tar.bz2")),
    "win": ("win64", (".exe",)),
    "mac": ("mac", (".dmg",)),
}


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "kd-mail-build"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def resolve_version(spec):
    if spec not in ("esr", "release"):
        return spec
    data = json.loads(get("https://product-details.mozilla.org/1.0/thunderbird_versions.json"))
    keys = ["THUNDERBIRD_ESR", "LATEST_THUNDERBIRD_VERSION"] if spec == "esr" else ["LATEST_THUNDERBIRD_VERSION"]
    for k in keys:
        if data.get(k):
            return data[k]
    raise SystemExit(f"Kunne ikke finde version for '{spec}' i product-details: {list(data)}")


def find_file(version, plat_dir, locale, exts):
    base = f"{ARCHIVE}/{version}/{plat_dir}/{locale}/"
    html = get(base).decode("utf-8", "replace")
    for href in re.findall(r'href="([^"]+)"', html):
        name = urllib.parse.unquote(href.rstrip("/").split("/")[-1])
        if name.lower().startswith("thunderbird") and name.endswith(exts) and "stub" not in name.lower():
            return base + urllib.parse.quote(name), name
    raise SystemExit(f"Ingen pakke fundet i {base}")


def main():
    spec, locale, outdir, *plats = sys.argv[1:]
    plats = plats or list(PLATFORMS)
    os.makedirs(outdir, exist_ok=True)
    version = resolve_version(spec)
    vfile = os.path.join(outdir, "VERSION")
    if os.path.exists(vfile) and open(vfile).read().strip() != version:
        for f in os.listdir(outdir):
            if f.startswith("thunderbird-"):
                os.remove(os.path.join(outdir, f))
    if not os.path.exists(vfile):
        open(vfile, "w").write(version)
    print(f"Thunderbird {version} ({locale})")
    for p in plats:
        plat_dir, exts = PLATFORMS[p]
        have = [e for e in exts if os.path.exists(os.path.join(outdir, f"thunderbird-{p}{e}"))]
        if have and open(os.path.join(outdir, "VERSION")).read().strip() == version:
            print(f"  {p}: findes allerede")
            continue
        url, name = find_file(version, plat_dir, locale, exts)
        ext = next(e for e in exts if name.endswith(e))
        dest = os.path.join(outdir, f"thunderbird-{p}{ext}")
        print(f"  {p}: {url}")
        with open(dest + ".part", "wb") as f:
            f.write(get(url))
        os.rename(dest + ".part", dest)
    with open(os.path.join(outdir, "VERSION"), "w") as f:
        f.write(version)


if __name__ == "__main__":
    main()
