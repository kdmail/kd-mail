/* KD Mail – opsætnings- og redigeringsside */
"use strict";

const $ = (id) => document.getElementById(id);
const params = new URLSearchParams(location.search);
let mode = params.get("mode") === "edit" ? "edit" : "new";
let existing = null;

function formData() {
  const local = $("localPart").value.trim().toLowerCase().replace(/@.*$/, "");
  return {
    localPart: local,
    password: $("password").value,
    fullName: $("fullName").value.trim(),
    roles: $("roles").value,
    mobile: $("mobile").value.trim(),
    greeting: $("greeting").value.trim(),
    email: existing ? existing.email : (local ? `${local}@kd.dk` : "dit.navn@kd.dk"),
  };
}

function render() {
  const d = formData();
  $("preview").innerHTML = buildKdSignature({
    ...d,
    fullName: d.fullName || "Dit Navn",
  });
}

function showError(msg) {
  $("error").textContent = msg;
  $("error").hidden = !msg;
}

async function init() {
  existing = await browser.kdAccount.findExisting();
  if (existing) mode = "edit";
  document.body.classList.toggle("edit", mode === "edit");

  const { profile } = await browser.storage.local.get("profile");
  if (profile) {
    for (const k of ["fullName", "roles", "mobile", "greeting"]) {
      if (profile[k] != null) $(k).value = profile[k];
    }
  }
  if (mode === "edit") {
    document.querySelector("header h1").textContent = "Ret din KD-signatur";
    $("intro").textContent = `Signaturen gælder for ${existing ? existing.email : "din KD-konto"}.`;
    $("submit").textContent = "Gem signatur";
  }
  render();
}

$("form").addEventListener("input", render);

$("form").addEventListener("submit", async (ev) => {
  ev.preventDefault();
  showError("");
  const d = formData();

  if (mode === "new") {
    if (!/^[a-z0-9._+-]+$/.test(d.localPart)) {
      return showError("Skriv den del af din mailadresse, der står før @kd.dk.");
    }
    if (!d.password) return showError("Skriv din adgangskode.");
  }
  if (!d.fullName) return showError("Skriv dit fulde navn.");

  const signatureHtml = buildKdSignature(d);
  $("submit").disabled = true;
  try {
    await browser.storage.local.set({
      profile: {
        fullName: d.fullName, roles: d.roles, mobile: d.mobile, greeting: d.greeting,
      },
    });
    if (mode === "new") {
      const res = await browser.kdAccount.create({
        localPart: d.localPart,
        password: d.password,
        fullName: d.fullName,
        signatureHtml,
      });
      $("doneText").textContent =
        `Din konto ${res.email} er oprettet, og din signatur er sat på. ` +
        `Du kan altid rette signaturen via knappen "KD-signatur" i værktøjslinjen.`;
    } else {
      await browser.kdAccount.updateIdentity({
        identityId: existing.identityId,
        fullName: d.fullName,
        signatureHtml,
      });
      $("doneText").textContent = "Din signatur er gemt.";
    }
    $("form").closest("main").hidden = true;
    $("done").hidden = false;
  } catch (e) {
    showError(e.message || String(e));
  } finally {
    $("submit").disabled = false;
    $("password").value = "";
  }
});

$("close").addEventListener("click", () => window.close());

init().catch((e) => showError(e.message || String(e)));
