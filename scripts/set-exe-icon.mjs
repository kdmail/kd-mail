// KD Mail – skifter ikon og versionsinfo i en Windows .exe
// Brug: node set-exe-icon.mjs <exe> <ico> <version>
import fs from "node:fs";
import * as PE from "pe-library";
import * as ResEdit from "resedit";

const [exePath, icoPath, version] = process.argv.slice(2);
const exe = PE.NtExecutable.from(fs.readFileSync(exePath), { ignoreCert: true });
const res = PE.NtExecutableResource.from(exe);
const ico = ResEdit.Data.IconFile.from(fs.readFileSync(icoPath));
const icons = ico.icons.map((i) => i.data);

// Erstat alle ikongrupper (programikon + dokumentikoner)
const groups = ResEdit.Resource.IconGroupEntry.fromEntries(res.entries);
if (groups.length === 0) {
  ResEdit.Resource.IconGroupEntry.replaceIconsForResource(res.entries, 1, 1033, icons);
} else {
  for (const g of groups) {
    ResEdit.Resource.IconGroupEntry.replaceIconsForResource(res.entries, g.id, g.lang, icons);
  }
}

// Versionsinfo – det er "FileDescription", Windows viser i Jobliste og proceslinje
const vis = ResEdit.Resource.VersionInfo.fromEntries(res.entries);
const parts = String(version).split(/[^\d]+/).filter(Boolean).map(Number);
while (parts.length < 4) parts.push(0);
for (const vi of vis) {
  for (const lang of vi.getAllLanguagesForStringValues()) {
    vi.setStringValues(lang, {
      FileDescription: "KD Mail",
      ProductName: "KD Mail",
      CompanyName: "Kristendemokraterne",
      InternalName: "KD Mail",
      LegalCopyright: "KD Mail er baseret på Mozilla Thunderbird (MPL 2.0)",
    });
  }
  vi.setFileVersion(...parts.slice(0, 4), 1033);
  vi.outputToResourceEntries(res.entries);
}

res.outputResource(exe);
fs.writeFileSync(exePath, Buffer.from(exe.generate()));
console.log(`  ${exePath}: ikon (${groups.length || 1} grupper) + versionsinfo`);
