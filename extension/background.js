/* KD Mail – baggrund: åbner opsætningen ved første start. */
"use strict";

async function openSetup(mode) {
  const url = browser.runtime.getURL(`setup/setup.html?mode=${mode}`);
  await browser.windows.create({ type: "popup", url, width: 980, height: 820 });
}

async function checkFirstRun() {
  const existing = await browser.kdAccount.findExisting();
  if (!existing) await openSetup("new");
}

browser.runtime.onStartup.addListener(checkFirstRun);
browser.runtime.onInstalled.addListener(checkFirstRun);

// Værktøjslinjeknappen "KD-signatur" åbner redigering af signaturen
browser.browserAction.onClicked.addListener(async () => {
  const existing = await browser.kdAccount.findExisting();
  await openSetup(existing ? "edit" : "new");
});

// KD-farver i hele programmet
const KD_BLUE = "#00238C";
const KD_ORANGE = "#F58220";
try {
  browser.theme.update({
  colors: {
    frame: KD_BLUE,
    frame_inactive: "#0B2E8F",
    tab_background_text: "#FFFFFF",
    tab_selected: "#FFFFFF",
    tab_text: KD_BLUE,
    tab_line: KD_ORANGE,
    toolbar: "#FFFFFF",
    toolbar_text: "#1D1D1F",
    toolbar_field: "#F2F4F9",
    toolbar_field_text: "#1D1D1F",
    toolbar_field_border_focus: KD_ORANGE,
    toolbar_field_focus: "#FFFFFF",
    toolbar_field_text_focus: "#1D1D1F",
    button_background_hover: "rgba(0, 35, 140, 0.08)",
    button_background_active: "rgba(0, 35, 140, 0.16)",
    sidebar: "#F7F8FC",
    sidebar_text: "#1D1D1F",
    sidebar_highlight: KD_ORANGE,
    sidebar_highlight_text: "#FFFFFF",
    sidebar_border: "#E3E6EF",
    popup_highlight: KD_ORANGE,
    popup_highlight_text: "#FFFFFF",
    icons_attention: KD_ORANGE,
  },
});
} catch (e) {
  console.error("KD-tema kunne ikke anvendes", e);
}
