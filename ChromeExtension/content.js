/* Only injected into the Gemini usage page, in Chrome's isolated world. */
(() => {
  'use strict';
  const parser = globalThis.GeminiUsageParser;
  if (!parser.isUsageURL(location.href)) return;
  const started = Date.now();
  let lastFingerprint = '';
  let retryAfter = 0;
  let timer;
  let stopped = false;
  let ready = false;

  function accountLabels() {
    const values = [];
    for (const node of document.querySelectorAll('[aria-label], [title], a[href*="accounts.google.com/SignOutOptions"]')) {
      if (!node.getClientRects().length || getComputedStyle(node).visibility === 'hidden') continue;
      const label = node.getAttribute('aria-label') || '';
      const title = node.getAttribute('title') || '';
      // Google's avatar identifies the currently selected account. Never infer
      // identity from authuser, page prose, or an arbitrary email in the DOM.
      if (/Google\s*(?:계정|account)/i.test(label + ' ' + title) ||
          (node.tagName === 'A' && (node.getAttribute('href') || '').includes('accounts.google.com/SignOutOptions'))) {
        values.push(label, title);
      }
    }
    return values;
  }

  let inFlight = false;
  async function read() {
    if (inFlight) return;
    inFlight = true;
    try { await readOnce(); } finally { inFlight = false; }
  }
  async function readOnce() {
    if (!ready || stopped) return;
    if (Date.now() - started > 45000) { stop(); return; }
    if (Date.now() < retryAfter || !parser.isUsageURL(location.href)) return;
    const value = parser.snapshot({ text: document.body?.innerText || '', accountLabels: accountLabels(), sourceURL: location.href });
    // A loading page and an unknown account are not evidence of a zero balance.
    if (!value || (value.status !== 'ok' && Date.now() - started < 20000)) return;
    const fingerprint = JSON.stringify([value.status, value.account, value.used, value.labels]);
    if (fingerprint === lastFingerprint) return;
    try {
      const response = await chrome.runtime.sendMessage({ kind: 'snapshot', value });
      if (response?.accepted) { lastFingerprint = fingerprint; stop(); }
      else retryAfter = Date.now() + 30000;
    } catch (_) {
      // Extension reload invalidates this document's context; navigation restores it.
      stop();
    }
  }

  function stop() {
    stopped = true; observer.disconnect(); clearInterval(timer); clearTimeout(observer.debounce);
  }
  const observer = new MutationObserver(() => {
    clearTimeout(observer.debounce);
    observer.debounce = setTimeout(read, 250);
  });
  observer.observe(document.documentElement, { subtree: true, childList: true, attributes: true, characterData: true });
  // The pinned account lives in extension storage; never start parsing before
  // it is known, or a second signed-in account could be reported as a match.
  chrome.storage.onChanged.addListener((changes, area) => {
    if (area === 'local' && changes[parser.ACCOUNT_KEY]) {
      parser.setExpectedAccount(changes[parser.ACCOUNT_KEY].newValue);
    }
  });
  parser.syncAccount().catch(() => {}).then(() => {
    ready = true;
    timer = setInterval(read, 1000);
    read();
  });
})();
