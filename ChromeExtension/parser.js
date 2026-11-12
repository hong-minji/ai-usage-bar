/* Pure, bounded parser shared by the content script, service worker and tests. */
(function (scope) {
  'use strict';
  const HOST = 'com.local.ai_usage_bar.gemini';
  const ACCOUNT_KEY = 'expectedAccount';
  const labels = new Set(['5시간', '주간', '사용량']);
  const EMAIL = /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i;

  // Optional. Empty means "whichever Google account this Chrome profile is
  // signed in to"; set it from the popup to pin one account on a multi-account
  // profile. Never read from the page or the URL -- only from extension storage.
  let expected = '';

  function normalizeAccount(value) {
    const text = String(value ?? '').trim().toLowerCase();
    return EMAIL.test(text) && text.length <= 254 ? text : '';
  }

  function setExpectedAccount(value) {
    expected = normalizeAccount(value);
    return expected;
  }

  function expectedAccount() {
    return expected;
  }

  /** Refreshes the pinned account from extension storage. No-op under tests. */
  async function syncAccount() {
    if (typeof chrome === 'undefined' || !chrome.storage) return expected;
    const stored = await chrome.storage.local.get(ACCOUNT_KEY);
    return setExpectedAccount(stored[ACCOUNT_KEY]);
  }

  function usageURL() {
    const base = 'https://gemini.google.com/usage';
    return expected ? base + '?authuser=' + encodeURIComponent(expected) : base;
  }

  function isUsageURL(value) {
    try {
      const url = new URL(value);
      return typeof value === 'string' && value.length <= 2048 &&
        url.protocol === 'https:' && url.hostname === 'gemini.google.com' &&
        !url.username && !url.password && !url.port && /^\/(?:u\/\d+\/)?usage\/?$/.test(url.pathname);
    } catch (_) { return false; }
  }

  function accountFromLabels(values) {
    const found = new Set();
    for (const value of values) {
      for (const email of String(value).match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi) || []) {
        found.add(email.toLowerCase());
      }
    }
    return found.size === 1 ? [...found][0] : '';
  }

  function labelFor(text) {
    // Most recent heading wins if more than one heading is in the excerpt.
    const patterns = [
      [/주간(?:\s*(?:한도|사용량))?|weekly(?:\s+(?:limit|usage))?/gi, '주간'],
      [/현재\s*사용량|5\s*시간|current\s+usage|5[-\s]?hour(?:ly)?/gi, '5시간'],
    ];
    let last = -1;
    let label = '사용량';
    for (const [pattern, candidate] of patterns) {
      for (const match of text.matchAll(pattern)) {
        if (match.index > last) { last = match.index; label = candidate; }
      }
    }
    return label;
  }

  function parseUsage(text) {
    const input = String(text).slice(0, 100000);
    const matches = [...input.matchAll(/(?<![\d.,+\-])(\d{1,3}(?:[.,]\d+)?)\s*%\s*(?:사용됨|사용\s*중|used\b)/gi)];
    if (matches.length === 0 || matches.length > 2) return null;
    const used = [];
    const resultLabels = [];
    let previousEnd = 0;
    for (const match of matches) {
      const value = Number(match[1].replace(',', '.'));
      if (!Number.isFinite(value) || value < 0 || value > 100) return null;
      const before = input.slice(Math.max(previousEnd, match.index - 250), match.index);
      used.push(value);
      resultLabels.push(labelFor(before));
      previousEnd = match.index + match[0].length;
    }
    return { used, labels: resultLabels };
  }

  function snapshot({ text, accountLabels, sourceURL, now = new Date() }) {
    if (!isUsageURL(sourceURL)) return null;
    const account = accountFromLabels(accountLabels);
    const base = { version: 1, sourceURL, account, observedAt: now.toISOString(), used: [], labels: [] };
    if (account && expected && account !== expected) return { ...base, status: 'account_mismatch' };
    if (!account) {
      const needsLogin = /(?:^|\n)\s*(?:로그인|sign in)\s*(?:\n|$)/i.test(text);
      return { ...base, status: needsLogin ? 'login_required' : 'unavailable' };
    }
    const usage = parseUsage(text);
    return usage ? { ...base, ...usage, status: 'ok' } : { ...base, status: 'unavailable' };
  }

  function validateSnapshot(value, now = Date.now()) {
    if (!value || value.version !== 1 || !isUsageURL(value.sourceURL) ||
        !['ok', 'login_required', 'account_mismatch', 'unavailable'].includes(value.status) ||
        typeof value.account !== 'string' || value.account.length > 254 ||
        typeof value.observedAt !== 'string' || Math.abs(Date.parse(value.observedAt) - now) > 120000 ||
        !Number.isFinite(Date.parse(value.observedAt)) || !Array.isArray(value.used) ||
        !Array.isArray(value.labels) || value.labels.length !== value.used.length) return false;
    if (value.status !== 'ok') return value.used.length === 0;
    // An "ok" reading always names the account the page itself showed, and must
    // match the pinned account when one is configured.
    return normalizeAccount(value.account) === value.account && value.account !== '' &&
      (!expected || value.account === expected) &&
      value.used.length > 0 && value.used.length <= 2 &&
      value.used.every(n => typeof n === 'number' && Number.isFinite(n) && n >= 0 && n <= 100) &&
      value.labels.every(label => labels.has(label));
  }

  const api = {
    HOST, ACCOUNT_KEY, normalizeAccount, setExpectedAccount, expectedAccount, syncAccount,
    usageURL, isUsageURL, accountFromLabels, parseUsage, snapshot, validateSnapshot,
  };
  // Kept as a property so call sites read naturally; it tracks the pinned account.
  Object.defineProperty(api, 'USAGE_URL', { get: usageURL, enumerable: true });
  scope.GeminiUsageParser = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(globalThis);
