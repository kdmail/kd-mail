# KD Mail

Kristendemokraternes eget mailprogram til Windows, macOS og Linux. Det er en
fork af Mozilla Thunderbird (ESR) med KD's navn, logo, farver og ikon og med
automatisk opsætning af @kd.dk-mail (Simply.com) og KD-signatur.

## Sådan virker forken

`build.sh` henter Mozillas officielle danske Thunderbird-pakker og bygger dem
om til KD Mail:

| Hvad | Hvor |
|---|---|
| Navnet "KD Mail" i hele programmet | `scripts/rebrand.py` (brand.ftl/.properties/.dtd i omni.ja) |
| App-ikon og logoer | `branding/` → omni.ja, Windows-exe, macOS .icns, Linux-ikoner |
| Egen profilmappe, så KD Mail ikke deler data med en evt. Thunderbird | `application.ini` (Profile=KDMail) |
| KD-farver (blå #00238C, orange #F58220) | `extension/background.js` |
| Kontoopsætning og signatur | `extension/` (indbygget, kan ikke fjernes) |
| Låste indstillinger, ingen Mozilla-opdateringer | `distribution/policies.json` |
| Installationsprogrammer | `scripts/package-*.sh`, `packaging/` |

Resultat i `dist/`:

- **Windows:** `KD-Mail-Setup-<version>.exe`. Installeres pr. bruger og kræver ikke administrator.
- **macOS:** `KD-Mail-<version>-macOS.dmg`. Universel (Intel og Apple Silicon), ad hoc-signeret.
- **Linux:** `kd-mail_<version>_amd64.deb` (Ubuntu/Debian/Mint) og `kd-mail-<version>.x86_64.rpm` (Fedora/openSUSE).

## Byg (anbefalet: GitHub)

1. Læg mappen i et GitHub-repository, fx `kd-dk/kd-mail`.
2. Gå til **Actions → Byg KD Mail → Run workflow**.
3. Efter ca. 15 minutter (første gang ca. 30 minutter) kan du hente installationsfilerne under *Artifacts*.
4. Et tag som `v1.0` laver en *Release* med filerne, som kan linkes fra kd.dk.

Workflowet kører også automatisk hver mandag, så nye sikkerhedsopdateringer
fra Thunderbird kommer med.

Lokalt på Linux kan du køre `./build.sh`. Det kræver nsis, p7zip, hfsprogs,
rpm, node, python3-pil, `dmg`/`hfsplus` (mozilla/libdmg-hfsplus) og `rcodesign`.

## Nye versioner

- **Ny Thunderbird:** Kør workflowet. `TB_VERSION=esr` i `kdmail.conf` henter altid den nyeste ESR.
- **Kun KD-ændringer** (signatur, farver m.m.): Tæl `KD_REVISION` op i `kdmail.conf`.
- Brugerne installerer en ny version oven i den gamle. Konto, mails og signatur bliver liggende.

## Installation for brugerne (usignerede filer)

Indtil filerne signeres, advarer styresystemet første gang:

- **Windows:** "Windows beskyttede din pc" → **Flere oplysninger** → **Kør alligevel**.
- **macOS:** Åbn .dmg-filen → træk KD Mail til Programmer → åbn KD Mail → OK →
  **Systemindstillinger → Anonymitet og sikkerhed → Åbn alligevel**. Vejledningen ligger også i .dmg-filen.
- **Linux:** Dobbeltklik på .deb- eller .rpm-filen → **Installér** i Software-centret.

Advarslerne forsvinder, når filerne signeres. Det kræver et Apple Developer ID
(99 USD/år) og et Windows-kodesigneringscertifikat.

## Licens

Thunderbird er udgivet under Mozilla Public License 2.0. KD Mail ændrer
MPL-filer (brandingtekster), så kildekoden i dette repository skal være
offentligt tilgængelig for dem, der får KD Mail. Et offentligt GitHub-repository
er nok. Navnet "Thunderbird" og dets logo bruges ikke i KD Mail. Programmet
oplyser blot, at det er baseret på Mozilla Thunderbird.
