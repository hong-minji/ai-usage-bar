const parser = globalThis.GeminiUsageParser;
const accountField = document.getElementById('account');
const hint = document.getElementById('hint');
const messages = {
  loading: 'Gemini 사용량을 읽는 중…',
  login_required: '크롬의 Gemini 로그인이 필요합니다.',
  account_mismatch: '지정한 계정과 다른 Google 계정이 선택되어 있습니다.',
  unavailable: '사용량을 확인하지 못했습니다. 아래 페이지에서 로그인과 사용량 표시를 확인하세요.',
  host_unavailable: '메뉴바 앱 연결이 필요합니다. 앱 설정의 Chrome 연결…을 누르세요.',
};

async function render() {
  const stored = await chrome.storage.local.get(['status', parser.ACCOUNT_KEY]);
  const pinned = parser.setExpectedAccount(stored[parser.ACCOUNT_KEY]);
  if (document.activeElement !== accountField) accountField.value = pinned;

  const status = stored.status;
  let text = '첫 연결을 기다리는 중입니다.';
  if (status?.state === 'ok') {
    text = status.used.map((used, i) => `${status.labels[i]} ${Math.round(100 - used)}% 남음`).join(' · ');
    if (status.observedAt) text += '\n' + new Date(status.observedAt).toLocaleTimeString('ko-KR') + ' 확인';
  } else if (status) text = messages[status.state] || messages.unavailable;
  document.getElementById('result').textContent = text;

  const seen = status?.account;
  hint.textContent = pinned
    ? `${pinned} 계정의 수치만 사용합니다.`
    : seen ? `현재 확인된 계정: ${seen}` : '크롬에 로그인된 계정을 그대로 사용합니다.';
}

async function saveAccount() {
  const value = accountField.value.trim();
  if (value && !parser.normalizeAccount(value)) {
    hint.textContent = '이메일 주소 형식이 아닙니다.';
    return;
  }
  await chrome.storage.local.set({ [parser.ACCOUNT_KEY]: parser.normalizeAccount(value) });
  await render();
}

accountField.addEventListener('change', saveAccount);
accountField.addEventListener('blur', saveAccount);
document.getElementById('refresh').addEventListener('click', async () => {
  document.getElementById('result').textContent = messages.loading;
  await chrome.runtime.sendMessage({ kind: 'refresh' });
  await render();
});
document.getElementById('usage').addEventListener('click', () => chrome.tabs.create({ url: parser.USAGE_URL }));
chrome.storage.onChanged.addListener(render);
render();
