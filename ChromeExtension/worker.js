importScripts('parser.js');

const parser = globalThis.GeminiUsageParser;
const PERIODIC = 'gemini-usage-refresh';
const DEADLINE = 'gemini-usage-timeout';
let queue = Promise.resolve();
const userTouchedTabs = new Set();

function serial(work) {
  const result = queue.then(work, work);
  queue = result.catch(() => {});
  return result;
}

async function pending() {
  return (await chrome.storage.session.get('pending')).pending || null;
}

async function status(values) {
  await chrome.storage.local.set({ status: { ...values, changedAt: new Date().toISOString() } });
}

async function closeOwnedTab(record) {
  if (!record) return;
  try {
    const tab = await chrome.tabs.get(record.tabId);
    // Chrome may redirect to sign-in or its SPA may drop the marker fragment.
    // Ownership comes from the session-stored tab ID, not the current URL. A tab
    // the user has ever selected is theirs now, even after they switch away.
    if (!tab.active && !record.userTouched && !userTouchedTabs.has(record.tabId)) {
      await chrome.tabs.remove(record.tabId);
    }
  } catch (_) { /* User may have already closed it. */ }
}

async function finish(record) {
  await chrome.storage.session.remove('pending');
  await chrome.alarms.clear(DEADLINE);
  await closeOwnedTab(record);
  if (record) userTouchedTabs.delete(record.tabId);
}

async function deliver(value) {
  try {
    const reply = await chrome.runtime.sendNativeMessage(parser.HOST, value);
    if (!reply?.ok) throw new Error('host rejected reading');
    await status({ state: value.status, account: value.account, used: value.used, labels: value.labels, observedAt: value.observedAt });
    return true;
  } catch (_) {
    await status({ state: 'host_unavailable', observedAt: value.observedAt });
    return false;
  }
}

async function poll() {
  await parser.syncAccount();
  const previous = await pending();
  if (previous && Date.now() - previous.startedAt < 60000) return { started: false };
  if (previous) await finish(previous);
  const nonce = crypto.randomUUID();
  try {
    // Reuse the user's signed-in profile. active:false leaves their current tab
    // selected; no passwords, cookies or remote-debugging port are needed.
    const tab = await chrome.tabs.create({ url: parser.USAGE_URL + '#ai-usage-bar=' + nonce, active: false });
    await chrome.storage.session.set({ pending: { tabId: tab.id, nonce, startedAt: Date.now(), userTouched: userTouchedTabs.has(tab.id) } });
    await chrome.alarms.create(DEADLINE, { when: Date.now() + 35000 });
    await status({ state: 'loading' });
    return { started: true };
  } catch (_) {
    await status({ state: 'unavailable' });
    return { started: false };
  }
}

async function timedOut() {
  const record = await pending();
  if (!record) return;
  await deliver({ version: 1, status: 'unavailable', sourceURL: parser.USAGE_URL, account: '', observedAt: new Date().toISOString(), used: [], labels: [] });
  await finish(record);
}

async function receive(message, sender) {
  if (message?.kind === 'refresh' && sender.url?.startsWith(chrome.runtime.getURL(''))) return poll();
  await parser.syncAccount();
  if (message?.kind !== 'snapshot' || sender.frameId !== 0 || sender.tab?.id === undefined ||
      !parser.isUsageURL(sender.url) || message.value?.sourceURL !== sender.url ||
      !parser.validateSnapshot(message.value)) return { accepted: false };

  const record = await pending();
  // Unrelated signed-in usage tabs cannot replace the requested account's data
  // with their errors while the background poll is in progress.
  if (message.value.status !== 'ok' && record?.tabId !== sender.tab.id) return { accepted: false };
  const accepted = await deliver(message.value);
  if (record?.tabId === sender.tab.id) await finish(record);
  return { accepted };
}

chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (!['refresh', 'snapshot'].includes(message?.kind)) return false;
  serial(() => receive(message, sender)).then(respond).catch(() => respond({ accepted: false }));
  return true;
});
chrome.alarms.onAlarm.addListener(alarm => {
  if (alarm.name === PERIODIC) return serial(poll);
  if (alarm.name === DEADLINE) return serial(timedOut);
});
async function startup() {
  await chrome.alarms.create(PERIODIC, { periodInMinutes: 5 });
  await poll();
}
chrome.runtime.onInstalled.addListener(() => serial(startup));
chrome.runtime.onStartup.addListener(() => serial(startup));
chrome.tabs.onActivated.addListener(info => {
  // Mark synchronously so an activation during an awaited native-host call is
  // respected before its queued storage update can run.
  userTouchedTabs.add(info.tabId);
  return serial(async () => {
    const record = await pending();
    if (record?.tabId === info.tabId) {
      await chrome.storage.session.set({ pending: { ...record, userTouched: true } });
    } else {
      userTouchedTabs.delete(info.tabId);
    }
  });
});
chrome.tabs.onRemoved.addListener(tabId => serial(async () => {
  userTouchedTabs.delete(tabId);
  const record = await pending();
  if (record?.tabId === tabId) {
    await chrome.storage.session.remove('pending');
    await chrome.alarms.clear(DEADLINE);
  }
}));

importScripts('web-parser.js', 'web-worker.js');
