/*
 * WebLibre cookie banner handler.
 *
 * Rejects non-essential consent where a reject control exists. It never clicks
 * accept-like text: the phrase list in rules.json contains reject phrases only,
 * and every click is additionally checked against an accept denylist.
 *
 * The script is deliberately conservative. It only acts inside an element that
 * a rule already identified as a banner, caps itself at three clicks per page,
 * gives up after a short window, and stops when a form field has focus.
 */
(() => {
  "use strict";

  if (window.__weblibreCookieBanner) {
    return;
  }
  window.__weblibreCookieBanner = true;

  if (!/^https?:$/.test(location.protocol) || window.top !== window) {
    return;
  }

  const MAX_CLICKS = 3;
  const SCAN_WINDOW_MS = 30000;
  const MUTATION_THROTTLE_MS = 750;
  const MAX_ELEMENTS = 6000;

  const ACCEPT_WORDS = [
    "accept",
    "accept all",
    "accept cookies",
    "agree",
    "agree all",
    "allow",
    "allow all",
    "got it",
    "ok",
    "okay",
    "continue",
    "confirm",
    "save",
    "i understand",
    "yes",
    "yes, i agree",
    "einverstanden",
    "akzeptieren",
    "accepter",
    "aceptar",
    "accetta",
    "aceitar",
    "accepteren",
  ];

  const TEXT_CANDIDATES =
    "button, a, [role='button'], input[type='button'], input[type='submit'], input[type='reset']";

  const startedAt = Date.now();
  let config = null;
  let stopped = false;
  let clickCount = 0;
  let observer = null;
  let scanInterval = null;
  let scanScheduled = false;
  let reported = new Set();

  function normalize(text) {
    return (text || "")
      .toLowerCase()
      .replace(/[\u2018\u2019\u201c\u201d]/g, "'")
      .replace(/\s+/g, " ")
      .trim();
  }

  function isAcceptLike(text) {
    const normalized = normalize(text);
    if (!normalized) {
      return true;
    }
    return ACCEPT_WORDS.some(
      (word) =>
        normalized === word ||
        normalized.startsWith(word + " ") ||
        normalized.startsWith(word + ",") ||
        normalized.includes(" " + word + " "),
    );
  }

  function rejectPhrases() {
    const phrases = config && config.rules && config.rules.textPhrases;
    return Array.isArray(phrases) ? phrases : [];
  }

  function matchesRejectPhrase(text) {
    const normalized = normalize(text);
    if (!normalized || normalized.length > 90) {
      return false;
    }
    for (const phrase of rejectPhrases()) {
      const candidate = normalize(phrase);
      if (!candidate) {
        continue;
      }
      // An explicit reject phrase wins even when it happens to contain a word
      // like "accepting" (for example "continue without accepting").
      if (normalized === candidate) {
        return true;
      }
      if (
        normalized.startsWith(candidate) &&
        normalized.length <= candidate.length + 28
      ) {
        return true;
      }
    }
    return false;
  }

  function collectRoots(limit) {
    const roots = [];
    const queue = [document];
    let visited = 0;

    while (queue.length > 0 && visited < limit) {
      const current = queue.shift();
      roots.push(current);

      let walker;
      try {
        walker = document.createTreeWalker(current, NodeFilter.SHOW_ELEMENT);
      } catch (error) {
        continue;
      }

      let node = walker.nextNode();
      while (node) {
        visited += 1;
        if (visited >= limit) {
          break;
        }
        if (node.shadowRoot) {
          queue.push(node.shadowRoot);
        }
        node = walker.nextNode();
      }
    }

    return roots;
  }

  function queryAll(selector, roots) {
    const found = [];
    for (const root of roots) {
      try {
        for (const element of root.querySelectorAll(selector)) {
          found.push(element);
        }
      } catch (error) {
        // A malformed selector in a future rule pack must never break the page.
      }
    }
    return found;
  }

  function isVisible(element) {
    if (!element || !element.isConnected) {
      return false;
    }
    let style;
    try {
      style = window.getComputedStyle(element);
    } catch (error) {
      return false;
    }
    if (
      !style ||
      style.display === "none" ||
      style.visibility === "hidden" ||
      style.opacity === "0"
    ) {
      return false;
    }
    const rect = element.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }

  function elementText(element) {
    if (!element) {
      return "";
    }
    const tag = (element.tagName || "").toLowerCase();
    if (tag === "input") {
      return element.value || element.getAttribute("aria-label") || "";
    }
    return (
      element.innerText ||
      element.textContent ||
      element.getAttribute("aria-label") ||
      ""
    );
  }

  function isFormFocused() {
    let active = document.activeElement;
    // Descend into open shadow roots to find the real focused control.
    while (active && active.shadowRoot && active.shadowRoot.activeElement) {
      active = active.shadowRoot.activeElement;
    }
    if (!active) {
      return false;
    }
    const tag = (active.tagName || "").toLowerCase();
    return (
      tag === "input" ||
      tag === "textarea" ||
      tag === "select" ||
      active.isContentEditable === true
    );
  }

  function globalExists(path) {
    let value = window;
    for (const part of String(path || "").split(".")) {
      if (!part) {
        continue;
      }
      value = value ? value[part] : undefined;
    }
    return Boolean(value);
  }

  function findBanner(rule, roots) {
    const confidence = typeof rule.confidence === "number" ? rule.confidence : 0.5;

    for (const detector of rule.detectors || []) {
      if (detector.type === "css" || detector.type === "shadow") {
        if (!detector.selector) {
          continue;
        }
        for (const element of queryAll(detector.selector, roots)) {
          if (isVisible(element)) {
            return { root: element, confidence: confidence };
          }
        }
      }

      if (detector.type === "global") {
        if (!globalExists(detector.name)) {
          continue;
        }
        // A global alone is not proof of a visible banner: require one of the
        // rule's own hide selectors to be on screen.
        for (const selector of rule.hide || []) {
          for (const element of queryAll(selector, roots)) {
            if (isVisible(element)) {
              return { root: element, confidence: confidence };
            }
          }
        }
      }
    }

    return null;
  }

  function findRejectElement(rule, roots) {
    // Site-specific overrides take precedence over the rule pack.
    const host = location.hostname;
    const custom = (config && config.customSelectors && config.customSelectors[host])
      ? config.customSelectors[host]
      : [];
    for (const selector of custom) {
      for (const element of queryAll(selector, roots)) {
        if (isVisible(element)) {
          return element;
        }
      }
    }

    for (const action of rule.reject || []) {
      if (action.type !== "click" || !action.selector) {
        continue;
      }
      for (const element of queryAll(action.selector, roots)) {
        if (isVisible(element)) {
          return element;
        }
      }
    }

    const hasTextAction = (rule.reject || []).some(
      (action) => action.type === "text",
    );
    if (!hasTextAction) {
      return null;
    }

    for (const element of queryAll(TEXT_CANDIDATES, roots)) {
      if (!isVisible(element)) {
        continue;
      }
      const text = elementText(element);
      if (!matchesRejectPhrase(text) || isAcceptLike(text)) {
        continue;
      }
      return element;
    }

    return null;
  }

  function tryCmpApi(rule) {
    // OneTrust's own API is more reliable than its DOM, which changes between
    // releases. Every other CMP is handled through explicit selectors.
    if (rule.id === "onetrust") {
      try {
        if (
          window.OneTrust &&
          typeof window.OneTrust.RejectAll === "function"
        ) {
          window.OneTrust.RejectAll();
          return true;
        }
      } catch (error) {
        // Fall through to the DOM path.
      }
    }
    return false;
  }

  function safeClick(element) {
    if (stopped || isFormFocused()) {
      return false;
    }
    try {
      element.scrollIntoView({ block: "center", inline: "center" });
    } catch (error) {
      // Older engines may not accept the options object.
    }
    try {
      element.click();
      return true;
    } catch (error) {
      return false;
    }
  }

  function restoreScrollLock() {
    for (const element of [document.documentElement, document.body]) {
      if (!element) {
        continue;
      }
      let overflow = "";
      try {
        overflow = window.getComputedStyle(element).overflow;
      } catch (error) {
        continue;
      }
      if (overflow === "hidden") {
        if (!element.hasAttribute("data-weblibre-cookie-overflow")) {
          element.setAttribute(
            "data-weblibre-cookie-overflow",
            element.style.overflow || "",
          );
        }
        element.style.setProperty("overflow", "auto", "important");
      }
    }
  }

  function hideBanner(rule, roots, detectedRoot) {
    let hidden = false;

    for (const selector of rule.hide || []) {
      for (const element of queryAll(selector, roots)) {
        if (!element || !element.isConnected) {
          continue;
        }
        element.style.setProperty("display", "none", "important");
        element.setAttribute("data-weblibre-cookie-hidden", "1");
        hidden = true;
      }
    }

    if (
      !hidden &&
      rule.allowHideRoot === true &&
      detectedRoot &&
      detectedRoot !== document.body &&
      detectedRoot !== document.documentElement
    ) {
      detectedRoot.style.setProperty("display", "none", "important");
      detectedRoot.setAttribute("data-weblibre-cookie-hidden", "1");
      hidden = true;
    }

    if (hidden) {
      restoreScrollLock();
    }

    return hidden;
  }

  function report(action, rule, confidence) {
    const key = action + ":" + (rule && rule.id ? rule.id : "");
    if (reported.has(key)) {
      return;
    }
    reported.add(key);

    const event = {
      url: location.href,
      siteKey: location.hostname,
      action: action,
      ruleId: rule && rule.id ? rule.id : null,
      confidence:
        typeof confidence === "number"
          ? confidence
          : rule && typeof rule.confidence === "number"
            ? rule.confidence
            : null,
      occurredAtMs: Date.now(),
    };

    try {
      const result = browser.runtime.sendMessage({
        type: "cookieBanner:event",
        event: event,
      });
      if (result && typeof result.catch === "function") {
        result.catch(() => {});
      }
    } catch (error) {
      // The background page can be asleep; an unrecorded status is harmless.
    }
  }

  function stop() {
    stopped = true;
    if (observer) {
      observer.disconnect();
      observer = null;
    }
    if (scanInterval) {
      clearInterval(scanInterval);
      scanInterval = null;
    }
  }

  function scan() {
    if (stopped || !config || config.mode === "off") {
      return;
    }
    if (!document.body) {
      return;
    }
    if (Date.now() - startedAt > SCAN_WINDOW_MS) {
      stop();
      return;
    }
    if (isFormFocused()) {
      return;
    }

    const disabled = (config && Array.isArray(config.disabledRules))
      ? config.disabledRules
      : [];
    const rules = (config.rules && Array.isArray(config.rules.rules))
      ? config.rules.rules.filter((r) => !disabled.includes(r.id))
      : [];
    if (rules.length === 0) {
      return;
    }

    const roots = collectRoots(MAX_ELEMENTS);
    let sawBanner = false;
    let sawFailure = false;

    for (const rule of rules) {
      const found = findBanner(rule, roots);
      if (!found) {
        continue;
      }

      sawBanner = true;
      report("detected", rule, found.confidence);

      if (config.mode === "detect") {
        continue;
      }

      if (clickCount >= MAX_CLICKS) {
        sawFailure = true;
        continue;
      }

      if (tryCmpApi(rule)) {
        clickCount += 1;
        report("rejected", rule, found.confidence);
        stop();
        return;
      }

      const rejectElement = findRejectElement(rule, roots);
      if (rejectElement && safeClick(rejectElement)) {
        clickCount += 1;
        report("rejected", rule, found.confidence);
        stop();
        return;
      }

      if (config.mode === "rejectOrHide") {
        if (hideBanner(rule, roots, found.root)) {
          report("hidden", rule, found.confidence);
          stop();
          return;
        }
      }

      sawFailure = true;
    }

    if (sawBanner && sawFailure) {
      report("failed", null, null);
    }
  }

  function scheduleScan() {
    if (stopped || scanScheduled) {
      return;
    }
    scanScheduled = true;
    window.setTimeout(() => {
      scanScheduled = false;
      scan();
    }, MUTATION_THROTTLE_MS);
  }

  function startObservers() {
    if (stopped || observer) {
      return;
    }
    try {
      observer = new MutationObserver(scheduleScan);
      observer.observe(document.documentElement || document, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ["class", "style", "hidden", "aria-hidden"],
      });
    } catch (error) {
      observer = null;
    }
    scanInterval = window.setInterval(scheduleScan, 2500);
  }

  function applyConfig(next) {
    if (!next || typeof next !== "object") {
      return;
    }
    config = {
      mode: next.mode || "rejectOrHide",
      rules: next.rules || null,
      disabledRules: Array.isArray(next.disabledRules) ? next.disabledRules : [],
      customSelectors:
        next.customSelectors && typeof next.customSelectors === "object"
          ? next.customSelectors
          : {},
    };
    if (config.mode === "off") {
      stop();
      return;
    }
    if (!config.rules) {
      return;
    }
    startObservers();
    scheduleScan();
  }

  async function loadConfig() {
    try {
      const response = await browser.runtime.sendMessage({
        type: "cookieBanner:getConfig",
        url: location.href,
      });
      if (response && response.ok && response.config) {
        applyConfig(response.config);
      }
    } catch (error) {
      // No background page or extension disabled: do nothing at all.
    }
  }

  try {
    browser.runtime.onMessage.addListener((message) => {
      if (message && message.type === "cookieBanner:configChanged") {
        applyConfig(message.config);
      }
    });
  } catch (error) {
    // Not fatal; the next page load will pick the configuration up again.
  }

  window.addEventListener("pagehide", stop, { once: true });

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", loadConfig, { once: true });
  } else {
    loadConfig();
  }
})();
