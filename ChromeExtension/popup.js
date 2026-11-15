const parser = globalThis.GeminiUsageParser;
const accountField = document.getElementById('account');
const hint = document.getElementById('hint');
const { t, remainingLine } = globalThis.PopupI18n;
// Looked up on use so each key appears as a literal for the i18n tests.
const messages = {
  loading: () => t('geminiLoading'),
  login_required: () => t('geminiLoginRequired'),
  account_mismatch: () => t('geminiAccountMismatch'),
  unavailable: () => t('geminiUnavailable'),
  host_unavailable: () => t('geminiHostUnavailable'),
};

async function render() {
  const stored = await chrome.storage.local.get(['status', parser.ACCOUNT_KEY]);
  const pinned = parser.setExpectedAccount(stored[parser.ACCOUNT_KEY]);
  if (document.activeElement !== accountField) accountField.value = pinned;

  const status = stored.status;
  let text = t('geminiWaiting');
  if (status?.state === 'ok') {
    text = remainingLine(status.used, status.labels);
    if (status.observedAt) {
      text += '\n' + t('checkedAt', [new Date(status.observedAt).toLocaleTimeString(chrome.i18n.getUILanguage())]);
    }
  } else if (status) text = (messages[status.state] || messages.unavailable)();
  document.getElementById('result').textContent = text;

  const seen = status?.account;
  hint.textContent = pinned
    ? t('pinnedOnly', [pinned])
    : seen ? t('seenAccount', [seen]) : t('usingSignedIn');
}

async function saveAccount() {
  const value = accountField.value.trim();
  if (value && !parser.normalizeAccount(value)) {
    hint.textContent = t('invalidEmail');
    return;
  }
  await chrome.storage.local.set({ [parser.ACCOUNT_KEY]: parser.normalizeAccount(value) });
  await render();
}

accountField.addEventListener('change', saveAccount);
accountField.addEventListener('blur', saveAccount);
document.getElementById('refresh').addEventListener('click', async () => {
  document.getElementById('result').textContent = messages.loading();
  await chrome.runtime.sendMessage({ kind: 'refresh' });
  await render();
});
document.getElementById('usage').addEventListener('click', () => chrome.tabs.create({ url: parser.USAGE_URL }));
chrome.storage.onChanged.addListener(render);
render();
