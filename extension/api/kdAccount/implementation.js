/* KD Mail – Experiment API (kører med fulde Thunderbird-rettigheder).
 * Serverindstillinger er låst her, så siden i tilføjelsen kun kan sende
 * brugernavn, adgangskode, navn og signatur. */
"use strict";

var { ExtensionCommon } = ChromeUtils.importESModule(
  "resource://gre/modules/ExtensionCommon.sys.mjs"
);
var { ExtensionUtils } = ChromeUtils.importESModule(
  "resource://gre/modules/ExtensionUtils.sys.mjs"
);
var { MailServices } = ChromeUtils.importESModule(
  "resource:///modules/MailServices.sys.mjs"
);
var { AddonManager } = ChromeUtils.importESModule(
  "resource://gre/modules/AddonManager.sys.mjs"
);

const KD = {
  domain: "kd.dk",
  imap: { host: "mail.simply.com", port: 143 }, // STARTTLS
  smtp: { host: "smtp.simply.com", port: 587 }, // STARTTLS
};

function findKdIdentity() {
  for (const account of MailServices.accounts.accounts) {
    for (const identity of account.identities) {
      if ((identity.email || "").toLowerCase().endsWith("@" + KD.domain)) {
        return { account, identity };
      }
    }
  }
  return null;
}

async function storeLogin(scheme, host, username, password) {
  const origin = `${scheme}://${host}`;
  for (const old of Services.logins.findLogins(origin, null, origin)) {
    if (old.username === username) Services.logins.removeLogin(old);
  }
  const info = Cc["@mozilla.org/login-manager/loginInfo;1"].createInstance(
    Ci.nsILoginInfo
  );
  info.init(origin, null, origin, username, password, "", "");
  await Services.logins.addLoginAsync(info);
}

function applySignature(identity, html) {
  identity.htmlSigFormat = true;
  identity.htmlSigText = html;
  identity.attachSignature = false;
  identity.suppressSigSep = true; // ingen "-- " linje
  identity.sigBottom = true;
  identity.sigOnReply = true;
  identity.sigOnForward = true;
  identity.composeHtml = true;
}

function createOutgoing(email) {
  // TB 128+: MailServices.outgoingServer, ældre: MailServices.smtp
  const svc = MailServices.outgoingServer || MailServices.smtp;
  let server;
  try {
    server = svc.createServer("smtp");
  } catch (e) {
    server = svc.createServer();
  }
  let smtp = server;
  try {
    smtp = server.QueryInterface(Ci.nsISmtpServer);
  } catch (e) {}
  smtp.hostname = KD.smtp.host;
  smtp.port = KD.smtp.port;
  server.socketType = Ci.nsMsgSocketType.alwaysSTARTTLS;
  server.authMethod = Ci.nsMsgAuthMethod.passwordCleartext;
  server.username = email;
  try {
    server.description = "KD (Simply.com)";
  } catch (e) {}
  return server;
}

this.kdAccount = class extends ExtensionCommon.ExtensionAPI {
  getAPI(context) {
    return {
      kdAccount: {
        async findExisting() {
          const hit = findKdIdentity();
          if (!hit) return null;
          return {
            accountId: hit.account.key,
            identityId: hit.identity.key,
            email: hit.identity.email,
          };
        },

        async create({ localPart, password, fullName, signatureHtml }) {
          localPart = String(localPart || "").trim().toLowerCase();
          if (!/^[a-z0-9._+-]+$/.test(localPart)) {
            throw new ExtensionUtils.ExtensionError(
              "Ugyldigt brugernavn – brug kun bogstaver, tal, punktum og bindestreg."
            );
          }
          const email = `${localPart}@${KD.domain}`;
          if (findKdIdentity()) {
            throw new ExtensionUtils.ExtensionError(
              "Der findes allerede en @kd.dk-konto i KD Mail."
            );
          }
          const am = MailServices.accounts;

          // Indgående (IMAP)
          const incoming = am.createIncomingServer(email, KD.imap.host, "imap");
          incoming.port = KD.imap.port;
          incoming.socketType = Ci.nsMsgSocketType.alwaysSTARTTLS;
          incoming.authMethod = Ci.nsMsgAuthMethod.passwordCleartext;
          incoming.prettyName = email;

          // Udgående (SMTP)
          const outgoing = createOutgoing(email);

          // Adgangskoder i Thunderbirds adgangskodelager
          await storeLogin("imap", KD.imap.host, email, password);
          await storeLogin("smtp", KD.smtp.host, email, password);

          // Identitet + signatur
          const identity = am.createIdentity();
          identity.email = email;
          identity.fullName = fullName;
          identity.smtpServerKey = outgoing.key;
          identity.valid = true;
          applySignature(identity, signatureHtml);

          const account = am.createAccount();
          account.incomingServer = incoming;
          account.addIdentity(identity);
          if (!am.defaultAccount) am.defaultAccount = account;

          try {
            am.saveAccountInfo();
          } catch (e) {}
          Services.prefs.savePrefFile(null);

          // Hent mappelisten med det samme
          try {
            incoming.performExpand(null);
          } catch (e) {}

          return { accountId: account.key, identityId: identity.key, email };
        },

        async checkForUpdate() {
          // Tjek straks for en ny KD-tilføjelse (ellers gør Thunderbird det kun én gang i døgnet)
          const addon = await AddonManager.getAddonByID(context.extension.id);
          if (!addon) return false;
          return new Promise((resolve) => {
            addon.findUpdates(
              {
                onUpdateAvailable(a, install) {
                  install.install();
                  resolve(true);
                },
                onNoUpdateAvailable() {
                  resolve(false);
                },
                onUpdateFinished() {
                  resolve(false);
                },
              },
              AddonManager.UPDATE_WHEN_USER_REQUESTED
            );
          });
        },

        async updateIdentity({ identityId, fullName, signatureHtml }) {
          const identity = MailServices.accounts.getIdentity(identityId);
          if (!identity) {
            throw new ExtensionUtils.ExtensionError("Identiteten blev ikke fundet.");
          }
          if (fullName) identity.fullName = fullName;
          applySignature(identity, signatureHtml);
          Services.prefs.savePrefFile(null);
          return true;
        },
      },
    };
  }
};
