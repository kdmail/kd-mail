<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <meta http-equiv="Content-Style-Type" content="text/css">
  <title></title>
  <meta name="Generator" content="Cocoa HTML Writer">
  <meta name="CocoaVersion" content="2775.1">
  <style type="text/css">
    p.p1 {margin: 0.0px 0.0px 0.0px 0.0px; font: 12.0px Helvetica}
    p.p2 {margin: 0.0px 0.0px 0.0px 0.0px; font: 12.0px Helvetica; min-height: 14.0px}
  </style>
</head>
<body>
<p class="p1">/* KD Mail – baggrund: åbner opsætningen ved første start. */</p>
<p class="p1">"use strict";</p>
<p class="p2"><br></p>
<p class="p1">async function openSetupWindow(mode) {</p>
<p class="p1"><span class="Apple-converted-space">  </span>const url = browser.runtime.getURL(`setup/setup.html?mode=${mode}`);</p>
<p class="p1"><span class="Apple-converted-space">  </span>try {</p>
<p class="p1"><span class="Apple-converted-space">    </span>await browser.windows.create({ type: "popup", url, width: 980, height: 820 });</p>
<p class="p1"><span class="Apple-converted-space">  </span>} catch (e) {</p>
<p class="p1"><span class="Apple-converted-space">    </span>console.error("KD Mail: kunne ikke åbne vindue, bruger fane", e);</p>
<p class="p1"><span class="Apple-converted-space">    </span>await browser.tabs.create({ url });</p>
<p class="p1"><span class="Apple-converted-space">  </span>}</p>
<p class="p1">}</p>
<p class="p2"><br></p>
<p class="p1">let kdSetupShown = false;</p>
<p class="p1">async function checkFirstRun() {</p>
<p class="p1"><span class="Apple-converted-space">  </span>if (kdSetupShown) return;</p>
<p class="p1"><span class="Apple-converted-space">  </span>let existing = null;</p>
<p class="p1"><span class="Apple-converted-space">  </span>try {</p>
<p class="p1"><span class="Apple-converted-space">    </span>existing = await browser.kdAccount.findExisting();</p>
<p class="p1"><span class="Apple-converted-space">  </span>} catch (e) {</p>
<p class="p1"><span class="Apple-converted-space">    </span>console.error("KD Mail: kunne ikke tjekke konti", e);</p>
<p class="p1"><span class="Apple-converted-space">  </span>}</p>
<p class="p1"><span class="Apple-converted-space">  </span>if (!existing) {</p>
<p class="p1"><span class="Apple-converted-space">    </span>kdSetupShown = true;</p>
<p class="p1"><span class="Apple-converted-space">    </span>await openSetupWindow("new");</p>
<p class="p1"><span class="Apple-converted-space">  </span>}</p>
<p class="p1">}</p>
<p class="p2"><br></p>
<p class="p1">browser.runtime.onStartup.addListener(checkFirstRun);</p>
<p class="p1">browser.runtime.onInstalled.addListener(checkFirstRun);</p>
<p class="p1">// Sikkerhedsnet: tjek også, når baggrundsscriptet indlæses</p>
<p class="p1">setTimeout(checkFirstRun, 1500);</p>
<p class="p2"><br></p>
<p class="p1">// Værktøjslinjeknappen "KD-signatur" åbner redigering af signaturen</p>
<p class="p1">browser.browserAction.onClicked.addListener(async () =&gt; {</p>
<p class="p1"><span class="Apple-converted-space">  </span>let existing = null;</p>
<p class="p1"><span class="Apple-converted-space">  </span>try { existing = await browser.kdAccount.findExisting(); } catch (e) { console.error(e); }</p>
<p class="p1"><span class="Apple-converted-space">  </span>await openSetupWindow(existing ? "edit" : "new");</p>
<p class="p1">});</p>
<p class="p2"><br></p>
<p class="p1">// KD-farver i hele programmet</p>
<p class="p1">// KD_ORANGE er defineret i signature.js (de to filer deler navnerum)</p>
<p class="p1">const KD_BLUE = "#00238C";</p>
<p class="p1">try {</p>
<p class="p1"><span class="Apple-converted-space">  </span>browser.theme.update({</p>
<p class="p1"><span class="Apple-converted-space">  </span>colors: {</p>
<p class="p1"><span class="Apple-converted-space">    </span>frame: KD_BLUE,</p>
<p class="p1"><span class="Apple-converted-space">    </span>frame_inactive: "#0B2E8F",</p>
<p class="p1"><span class="Apple-converted-space">    </span>tab_background_text: "#FFFFFF",</p>
<p class="p1"><span class="Apple-converted-space">    </span>tab_selected: "#FFFFFF",</p>
<p class="p1"><span class="Apple-converted-space">    </span>tab_text: KD_BLUE,</p>
<p class="p1"><span class="Apple-converted-space">    </span>tab_line: KD_ORANGE,</p>
<p class="p1"><span class="Apple-converted-space">    </span>toolbar: "#FFFFFF",</p>
<p class="p1"><span class="Apple-converted-space">    </span>toolbar_text: "#1D1D1F",</p>
<p class="p1"><span class="Apple-converted-space">    </span>toolbar_field: "#F2F4F9",</p>
<p class="p1"><span class="Apple-converted-space">    </span>toolbar_field_text: "#1D1D1F",</p>
<p class="p1"><span class="Apple-converted-space">    </span>toolbar_field_border_focus: KD_ORANGE,</p>
<p class="p1"><span class="Apple-converted-space">    </span>toolbar_field_focus: "#FFFFFF",</p>
<p class="p1"><span class="Apple-converted-space">    </span>toolbar_field_text_focus: "#1D1D1F",</p>
<p class="p1"><span class="Apple-converted-space">    </span>button_background_hover: "rgba(0, 35, 140, 0.08)",</p>
<p class="p1"><span class="Apple-converted-space">    </span>button_background_active: "rgba(0, 35, 140, 0.16)",</p>
<p class="p1"><span class="Apple-converted-space">    </span>sidebar: "#F7F8FC",</p>
<p class="p1"><span class="Apple-converted-space">    </span>sidebar_text: "#1D1D1F",</p>
<p class="p1"><span class="Apple-converted-space">    </span>sidebar_highlight: KD_ORANGE,</p>
<p class="p1"><span class="Apple-converted-space">    </span>sidebar_highlight_text: "#FFFFFF",</p>
<p class="p1"><span class="Apple-converted-space">    </span>sidebar_border: "#E3E6EF",</p>
<p class="p1"><span class="Apple-converted-space">    </span>popup_highlight: KD_ORANGE,</p>
<p class="p1"><span class="Apple-converted-space">    </span>popup_highlight_text: "#FFFFFF",</p>
<p class="p1"><span class="Apple-converted-space">    </span>icons_attention: KD_ORANGE,</p>
<p class="p1"><span class="Apple-converted-space">  </span>},</p>
<p class="p1">});</p>
<p class="p1">} catch (e) {</p>
<p class="p1"><span class="Apple-converted-space">  </span>console.error("KD-tema kunne ikke anvendes", e);</p>
<p class="p1">}</p>
</body>
</html>
