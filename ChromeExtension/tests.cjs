const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { randomUUID } = require('node:crypto');
const parser = require('./parser.js');

const TEST_ACCOUNT = 'someone@example.com';
const OTHER_ACCOUNT = 'other@example.com';
function avatar(account) { return ['Google 계정: 사용자 (' + account + ')']; }
function withPinnedAccount(account, body) {
  parser.setExpectedAccount(account);
  try { body(); } finally { parser.setExpectedAccount(''); }
}

test('Korean percentages and section labels, including decimal values', () => {
  assert.deepEqual(parser.parseUsage('사용량 한도\n현재 사용량\n95% 사용됨\n다음 리셋\n주간 한도\n32.5% 사용됨'),
    { used: [95, 32.5], labels: ['5시간', '주간'] });
});
test('English percentages, decimal comma and reordered sections', () => {
  assert.deepEqual(parser.parseUsage('Weekly limit\n32,5% used\nCurrent usage\n0% used'),
    { used: [32.5, 0], labels: ['주간', '5시간'] });
});
test('single unidentified meter does not claim to be weekly', () => {
  assert.deepEqual(parser.parseUsage('45% 사용됨'), { used: [45], labels: ['사용량'] });
});
test('missing, malformed, negative and excessive percentages fail closed', () => {
  for (const text of ['', 'No usage info', '101% used', '1000% used', '-4% used', 'NaN% used', '1% used 2% used 3% used']) {
    assert.equal(parser.parseUsage(text), null, text);
  }
});
test('URL scope excludes other origins and Gemini chat', () => {
  assert.equal(parser.isUsageURL(parser.USAGE_URL), true);
  assert.equal(parser.isUsageURL('https://gemini.google.com/u/0/usage#ai-usage-bar=a'), true);
  for (const url of ['https://gemini.google.com/app', 'https://evil.test/usage', 'https://gemini.google.com.evil.test/usage', 'https://x@gemini.google.com/usage', 'https://gemini.google.com:123/usage', 'http://gemini.google.com/usage']) {
    assert.equal(parser.isUsageURL(url), false, url);
  }
});
test('authuser URL alone is not account verification', () => {
  const value = parser.snapshot({ text: 'Current usage\n10% used', accountLabels: [], sourceURL: parser.USAGE_URL });
  assert.equal(value.status, 'unavailable');
  assert.deepEqual(value.used, []);
});
test('a pinned account refuses another account\'s percentages', () => {
  const forged = { ...goodValue(), account: OTHER_ACCOUNT };
  withPinnedAccount(TEST_ACCOUNT, () => {
    const value = parser.snapshot({ text: 'Current usage\n10% used', accountLabels: avatar(OTHER_ACCOUNT), sourceURL: parser.USAGE_URL });
    assert.equal(value.status, 'account_mismatch');
    assert.deepEqual(value.used, []);
    // A forged "ok" naming the other account must not survive validation.
    assert.equal(parser.validateSnapshot(forged), false);
    assert.equal(parser.validateSnapshot(goodValue()), true);
  });
});
test('with no pinned account the signed-in account is used as-is', () => {
  const value = goodValue();
  assert.equal(value.status, 'ok');
  assert.equal(value.account, TEST_ACCOUNT);
  assert.equal(parser.validateSnapshot(value), true);
  assert.equal(parser.USAGE_URL, 'https://gemini.google.com/usage');
});
test('a pinned account is normalised and routed with authuser', () => {
  withPinnedAccount('  Someone@Example.com ', () => {
    assert.equal(parser.expectedAccount(), TEST_ACCOUNT);
    assert.equal(parser.USAGE_URL, 'https://gemini.google.com/usage?authuser=someone%40example.com');
    assert.equal(parser.validateSnapshot(goodValue()), true);
  });
  for (const bad of ['', '   ', 'not-an-email', 'a@b']) {
    assert.equal(parser.setExpectedAccount(bad), '', bad);
  }
});
test('ambiguous avatar account evidence is rejected', () => {
  assert.equal(parser.accountFromLabels([TEST_ACCOUNT, OTHER_ACCOUNT]), '');
});
test('correct avatar and rendered usage produce accepted snapshot', () => {
  const value = goodValue();
  assert.equal(value.status, 'ok');
  assert.equal(parser.validateSnapshot(value), true);
  assert.equal(parser.validateSnapshot({ ...value, used: [NaN] }), false);
  assert.equal(parser.validateSnapshot({ ...value, observedAt: 'not-a-date' }), false);
  assert.equal(parser.validateSnapshot({ ...value, observedAt: new Date(0).toISOString() }), false);
  assert.equal(parser.validateSnapshot({ ...value, labels: ['injected label'] }), false);
});

function goodValue(url = parser.USAGE_URL) {
  return parser.snapshot({ text: 'Current usage\n10% used', accountLabels: avatar(TEST_ACCOUNT), sourceURL: url });
}
function event() {
  const handlers = [];
  return { addListener: fn => handlers.push(fn), emit: (...args) => Promise.all(handlers.map(fn => fn(...args))) };
}
function storageArea() {
  const data = {};
  return {
    data,
    async get(key) { return { [key]: data[key] }; },
    async set(value) { Object.assign(data, structuredClone(value)); },
    async remove(key) { delete data[key]; },
  };
}
function harness(initialRecord) {
  let nextId = 1;
  const tabs = new Map();
  const removed = [];
  const native = [];
  const alarms = new Map();
  let hostWorks = true;
  const chrome = {
    storage: { local: storageArea(), session: storageArea() },
    runtime: {
      onInstalled: event(), onStartup: event(), onMessage: event(),
      getURL: path => 'chrome-extension://test/' + path,
      async sendNativeMessage(host, value) {
        if (!hostWorks) throw new Error('host unavailable');
        native.push({ host, value });
        return { ok: true };
      },
    },
    tabs: {
      onRemoved: event(), onActivated: event(),
      async create(options) { const tab = { id: nextId++, ...options }; tabs.set(tab.id, tab); return tab; },
      async get(id) { if (!tabs.has(id)) throw new Error('missing'); return tabs.get(id); },
      async remove(id) { removed.push(id); tabs.delete(id); },
    },
    alarms: {
      onAlarm: event(),
      async create(name, options) { alarms.set(name, options); },
      async clear(name) { return alarms.delete(name); },
    },
  };
  if (initialRecord) {
    chrome.storage.session.data.pending = initialRecord;
    tabs.set(initialRecord.tabId, { id: initialRecord.tabId, active: false, url: parser.USAGE_URL + '#ai-usage-bar=' + initialRecord.nonce });
    nextId = initialRecord.tabId + 1;
  }
  const context = vm.createContext({ chrome, GeminiUsageParser: parser, importScripts() {}, URL, Date, Promise, crypto: { randomUUID } });
  vm.runInContext(fs.readFileSync(__dirname + '/worker.js', 'utf8'), context);
  return {
    chrome, tabs, removed, native, alarms,
    hostFails() { hostWorks = false; },
    async start() { await chrome.runtime.onInstalled.emit(); },
    message(message, sender) { return new Promise(resolve => chrome.runtime.onMessage.emit(message, sender, resolve)); },
  };
}

test('periodic polling creates one inactive tab and coalesces concurrent polls', async () => {
  const h = harness();
  await h.start();
  await Promise.all([h.chrome.alarms.onAlarm.emit({ name: 'gemini-usage-refresh' }), h.message({ kind: 'refresh' }, { url: 'chrome-extension://test/popup.html' })]);
  assert.equal(h.tabs.size, 1);
  assert.equal([...h.tabs.values()][0].active, false);
  assert.equal(h.alarms.get('gemini-usage-refresh').periodInMinutes, 5);
});
test('valid usage is forwarded and only the owned background tab is closed', async () => {
  const h = harness();
  await h.start();
  const tab = [...h.tabs.values()][0];
  const result = await h.message({ kind: 'snapshot', value: goodValue(tab.url) }, { url: tab.url, frameId: 0, tab: { id: tab.id } });
  assert.equal(result.accepted, true);
  assert.equal(h.native.length, 1);
  assert.equal(h.native[0].host, parser.HOST);
  assert.deepEqual(h.removed, [tab.id]);
  assert.equal(h.chrome.storage.session.data.pending, undefined);
});
test('a user-activated polling tab is retained even after switching away', async () => {
  for (const stillActive of [true, false]) {
    const h = harness();
    await h.start();
    const tab = [...h.tabs.values()][0];
    const originalURL = tab.url;
    await h.chrome.tabs.onActivated.emit({ tabId: tab.id });
    tab.active = stillActive;
    tab.url = 'https://gemini.google.com/app';
    await h.message({ kind: 'snapshot', value: goodValue(originalURL) }, { url: originalURL, frameId: 0, tab: { id: tab.id } });
    assert.deepEqual(h.removed, []);
  }
});
test('login redirects and stripped fragments cannot leak background tabs', async () => {
  for (const redirectedURL of [undefined, 'https://accounts.google.com/signin', 'https://gemini.google.com/usage']) {
    const h = harness();
    await h.start();
    const tab = [...h.tabs.values()][0];
    tab.url = redirectedURL;
    await h.chrome.alarms.onAlarm.emit({ name: 'gemini-usage-timeout' });
    assert.deepEqual(h.removed, [tab.id]);
  }
});
test('user-touched ownership survives service worker restart', async () => {
  const h = harness({ tabId: 7, nonce: 'before-worker-restart', startedAt: Date.now() - 40000, userTouched: true });
  await h.chrome.alarms.onAlarm.emit({ name: 'gemini-usage-timeout' });
  assert.deepEqual(h.removed, []);
});
test('forged sender, subframe and URL mismatch never reach native host', async () => {
  const h = harness();
  for (const sender of [
    { url: 'https://evil.test/usage', frameId: 0, tab: { id: 9 } },
    { url: parser.USAGE_URL, frameId: 1, tab: { id: 9 } },
    { url: parser.USAGE_URL + '&extra=1', frameId: 0, tab: { id: 9 } },
    { url: 'chrome-extension://test/popup.html', frameId: 0 },
  ]) {
    const result = await h.message({ kind: 'snapshot', value: goodValue() }, sender);
    assert.equal(result.accepted, false);
  }
  assert.equal(h.native.length, 0);
});
test('an ordinary user usage tab is read without ever being closed', async () => {
  const h = harness();
  const result = await h.message({ kind: 'snapshot', value: goodValue() }, { url: parser.USAGE_URL, frameId: 0, tab: { id: 99 } });
  assert.equal(result.accepted, true);
  assert.deepEqual(h.removed, []);
});
test('service worker restart restores ownership and times out gracefully', async () => {
  const h = harness({ tabId: 7, nonce: 'before-worker-restart', startedAt: Date.now() - 40000 });
  await h.chrome.alarms.onAlarm.emit({ name: 'gemini-usage-timeout' });
  assert.equal(h.native[0].value.status, 'unavailable');
  assert.deepEqual(h.removed, [7]);
});
test('missing native host is visible and still cleans up owned tab', async () => {
  const h = harness();
  h.hostFails();
  await h.start();
  const tab = [...h.tabs.values()][0];
  const result = await h.message({ kind: 'snapshot', value: goodValue(tab.url) }, { url: tab.url, frameId: 0, tab: { id: tab.id } });
  assert.equal(result.accepted, false);
  assert.equal(h.chrome.storage.local.data.status.state, 'host_unavailable');
  assert.deepEqual(h.removed, [tab.id]);
});
test('the pinned account is read back from extension storage', async () => {
  const value = goodValue();
  const storage = storageArea();
  globalThis.chrome = { storage: { local: storage } };
  try {
    await storage.set({ [parser.ACCOUNT_KEY]: OTHER_ACCOUNT });
    assert.equal(await parser.syncAccount(), OTHER_ACCOUNT);
    assert.equal(parser.validateSnapshot(value), false);

    await storage.set({ [parser.ACCOUNT_KEY]: '' });
    assert.equal(await parser.syncAccount(), '');
    assert.equal(parser.validateSnapshot(value), true);
  } finally {
    delete globalThis.chrome;
    parser.setExpectedAccount('');
  }
});
