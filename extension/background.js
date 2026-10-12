/* KD Mail – baggrund: åbner opsætningen ved første start. */
"use strict";

async function openSetupWindow(mode) {
  const url = browser.runtime.getURL(`setup/setup.html?mode=${mode}`);
  try {
    await browser.windows.create({ type: "popup", url, width: 980, height: 820 });
  } catch (e) {
    console.error("KD Mail: kunne ikke åbne vindue, bruger fane", e);
    await browser.tabs.create({ url });
  }
}

let kdSetupShown = false;
async function checkFirstRun() {
  if (kdSetupShown) return;
  let existing = null;
  try {
    existing = await browser.kdAccount.findExisting();
  } catch (e) {
    console.error("KD Mail: kunne ikke tjekke konti", e);
  }
  if (!existing) {
    kdSetupShown = true;
    await openSetupWindow("new");
  }
}

browser.runtime.onStartup.addListener(checkFirstRun);
browser.runtime.onInstalled.addListener(checkFirstRun);
// Sikkerhedsnet: tjek også, når baggrundsscriptet indlæses
setTimeout(checkFirstRun, 1500);

// Værktøjslinjeknappen "KD-signatur" åbner redigering af signaturen
browser.browserAction.onClicked.addListener(async () => {
  let existing = null;
  try { existing = await browser.kdAccount.findExisting(); } catch (e) { console.error(e); }
  await openSetupWindow(existing ? "edit" : "new");
});

// KD-farver i hele programmet: KD-blå tekst og ikoner på lys baggrund, orange markeringer.
// (Hvid tekst bruges ikke, da Thunderbird genbruger tekstfarverne i fx skrivevinduet.)
// KD_ORANGE er defineret i signature.js (de to filer deler navnerum)
const KD_BLUE = "#00238C";
try {
  browser.theme.update({
    colors: {
      frame: "#EEF1F9",
      frame_inactive: "#F5F7FC",
      tab_background_text: KD_BLUE,
      tab_selected: "#FFFFFF",
      tab_text: KD_BLUE,
      tab_line: KD_ORANGE,
      toolbar: "#FFFFFF",
      toolbar_text: KD_BLUE,
      toolbar_bottom_separator: "#E3E6EF",
      toolbar_field: "#F2F4F9",
      toolbar_field_text: KD_BLUE,
      toolbar_field_border: "#D5DBEA",
      toolbar_field_focus: "#FFFFFF",
      toolbar_field_text_focus: KD_BLUE,
      toolbar_field_border_focus: KD_ORANGE,
      button_background_hover: "rgba(0, 35, 140, 0.08)",
      button_background_active: "rgba(0, 35, 140, 0.16)",
      icons: KD_BLUE,
      icons_attention: KD_ORANGE,
      sidebar: "#F7F8FC",
      sidebar_text: KD_BLUE,
      sidebar_border: "#E3E6EF",
      sidebar_highlight: KD_ORANGE,
      sidebar_highlight_text: "#FFFFFF",
      popup: "#FFFFFF",
      popup_text: KD_BLUE,
      popup_border: "#D5DBEA",
      popup_highlight: KD_ORANGE,
      popup_highlight_text: "#FFFFFF",
    },
  });
} catch (e) {
  console.error("KD-tema kunne ikke anvendes", e);
}
