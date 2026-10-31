/*
 * WebLibre cookie banner handler - background page.
 *
 * Owns the rule pack and the native port. Content scripts ask this page for the
 * configuration of their own host; the native side only ever sends the mode and
 * per-site overrides, so the rules never have to travel through Dart.
 */
"use strict";

const NATIVE_PORT_NAME = "cookieBanner";

let config = { mode: "rejectOrHide", siteModes: {} };
let rules = null;
let rulesPromise = null;

function loadRules() {
  if (rules) {
    return Promise.resolve(rules);
  }
  if (rulesPromise) {
    return rulesPromise;
  }

  rulesPromise = (async () => {
    try {
      const cached = await browser.storage.local.get("cookieBannerRules");
      const stored = cached && cached.cookieBannerRules;
      if (stored && typeof stored.version === "number" && stored.version > 0) {
        rules = stored;
        return rules;
      }
    } catch (error) {
      // Storage is a cache, never the source of truth.
    }

    try {
      const response = await fetch(browser.runtime.getURL("rules.json"));
      const bundled = await response.json();
      if (bundled && Array.isArray(bundled.rules)) {
        rules = bundled;
        try {
          await browser.storage.local.set({ cookieBannerRules: bundled });
        } catch (error) {
          // A full or unavailable cache must not disable the handler.
        }
        return rules;
      }
    } catch (error) {
      console.error("Cookie banner: failed to load rules.json", error);
    }

    rules = { version: 0, textPhrases: [], rules: [] };
    return rules;
  })();

  return rulesPromise;
}

function hostOf(url) {
  try {
    return new URL(url).hostname;
  } catch (error) {
    return "";
  }
}

function resolveMode(url) {
  const host = hostOf(url);
  const overrides = config.siteModes || {};
  let match = null;

  for (const key of Object.keys(overrides)) {
    if (!key) {
      continue;
    }
    if (host === key || host.endsWith("." + key)) {
      if (!match || key.length > match.length) {
        match = key;
      }
    }
  }

  const mode = match ? overrides[match] : config.mode;
  return mode || "rejectOrHide";
}

async function configFor(url) {
  const loadedRules = await loadRules();
  return {
    mode: resolveMode(url),
    rules: loadedRules,
    disabledRules: config.disabledRules || [],
    customSelectors: config.customSelectors || {},
  };
}

let port = null;

function connectNative() {
  try {
    port = browser.runtime.connectNative(NATIVE_PORT_NAME);
  } catch (error) {
    port = null;
    return;
  }

  port.onMessage.addListener(async (message) => {
    if (!message || message.type !== "config") {
      // Allow the app to push a fresh rule pack. Cache it and push to tabs.
      if (message && message.type === "rules" && typeof message.rules === "string") {
        try {
          const parsed = JSON.parse(message.rules);
          if (parsed && Array.isArray(parsed.rules)) {
            rules = parsed;
            await browser.storage.local.set({ cookieBannerRules: parsed });
            const tabs = await browser.tabs.query({});
            for (const tab of tabs) {
              if (!tab || typeof tab.id !== "number") continue;
              try {
                await browser.tabs.sendMessage(tab.id, {
                  type: "cookieBanner:configChanged",
                  config: await configFor(tab.url || ""),
                });
              } catch (error) {}
            }
          }
        } catch (error) {
          console.error("Cookie banner: invalid rule pack", error);
        }
      }
      return;
    }

    config = {
      mode: message.mode || "rejectOrHide",
      siteModes:
        message.siteModes && typeof message.siteModes === "object"
          ? message.siteModes
          : {},
      disabledRules: Array.isArray(message.disabledRules)
        ? message.disabledRules
        : [],
      customSelectors:
        message.customSelectors && typeof message.customSelectors === "object"
          ? message.customSelectors
          : {},
    };

    // Push the new mode to tabs that are already open, so a settings change
    // applies without a reload.
    try {
      const tabs = await browser.tabs.query({});
      for (const tab of tabs) {
        if (!tab || typeof tab.id !== "number") {
          continue;
        }
        try {
          await browser.tabs.sendMessage(tab.id, {
            type: "cookieBanner:configChanged",
            config: await configFor(tab.url || ""),
          });
        } catch (error) {
          // Tabs without a content script (about:, PDF viewer) reject this.
        }
      }
    } catch (error) {
      // Tab enumeration is best-effort only.
    }
  });

  port.onDisconnect.addListener(() => {
    port = null;
    // The native side goes away with the engine. Retrying forever would keep
    // a dead engine's process alive, so one delayed retry is enough.
    window.setTimeout(() => {
      if (!port) {
        connectNative();
      }
    }, 5000);
  });
}

browser.runtime.onMessage.addListener((message, sender) => {
  if (!message || typeof message !== "object") {
    return undefined;
  }

  if (message.type === "cookieBanner:getConfig") {
    const url =
      message.url || (sender && sender.tab && sender.tab.url) || "";
    return configFor(url).then((resolved) => ({
      ok: true,
      config: resolved,
    }));
  }

  if (message.type === "cookieBanner:event" && message.event) {
    if (port) {
      try {
        port.postMessage({ type: "event", event: message.event });
      } catch (error) {
        // Dropping one status event must never affect the page.
      }
    }
    return undefined;
  }

  return undefined;
});

connectNative();
