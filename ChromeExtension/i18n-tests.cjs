const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = name => fs.readFileSync(path.join(__dirname, name), 'utf8');
const locale = lang => JSON.parse(read(`_locales/${lang}/messages.json`));
const en = locale('en');
const ko = locale('ko');
const manifest = JSON.parse(read('manifest.json'));

test('Korean and English catalogs define the same messages', () => {
  assert.deepEqual(Object.keys(ko).sort(), Object.keys(en).sort());
  for (const [lang, messages] of [['en', en], ['ko', ko]]) {
    for (const [key, entry] of Object.entries(messages)) {
      assert.match(key, /^[A-Za-z0-9_@]+$/, `${lang}.${key} is a valid message name`);
      assert.ok(typeof entry.message === 'string' && entry.message.trim(), `${lang}.${key} has text`);
    }
  }
});

test('placeholders match between languages and are all used', () => {
  for (const key of Object.keys(en)) {
    const names = entry => Object.keys(entry.placeholders || {}).sort();
    assert.deepEqual(names(ko[key]), names(en[key]), `${key} placeholders`);
    for (const entry of [en[key], ko[key]]) {
      const used = [...entry.message.matchAll(/\$([A-Za-z0-9_@]+)\$/g)].map(m => m[1].toLowerCase()).sort();
      assert.deepEqual(used, names(entry), `${key} uses exactly its declared placeholders`);
    }
  }
});

test('English text contains no Korean, and labels keep their protocol values in Korean', () => {
  for (const [key, entry] of Object.entries(en)) assert.doesNotMatch(entry.message, /[가-힣]/, key);
  assert.equal(ko.label5h.message, '5시간');
  assert.equal(ko.labelWeekly.message, '주간');
  assert.equal(ko.labelUsage.message, '사용량');
});

test('manifest resolves every localized field and falls back to English', () => {
  assert.equal(manifest.default_locale, 'en');
  const refs = JSON.stringify(manifest).match(/__MSG_([A-Za-z0-9_@]+)__/g) || [];
  assert.ok(refs.length >= 3, 'name, description and action title are localized');
  for (const ref of refs) assert.ok(Object.hasOwn(en, ref.slice(6, -2)), ref);
  // Chrome limits: name 75 characters, description 132.
  for (const messages of [en, ko]) {
    assert.ok(messages.extName.message.length <= 75);
    assert.ok(messages.extDescription.message.length <= 132);
  }
});

test('every key used by the popup exists', () => {
  const used = new Set();
  const html = read('popup.html');
  for (const m of html.matchAll(/data-i18n(?:-placeholder)?="([^"]+)"/g)) used.add(m[1]);
  for (const file of ['popup.js', 'web-popup.js', 'i18n.js']) {
    for (const m of read(file).matchAll(/\bt\('([A-Za-z0-9_@]+)'/g)) used.add(m[1]);
    for (const m of read(file).matchAll(/'(label[A-Za-z0-9]+)'/g)) used.add(m[1]);
  }
  assert.ok(used.size > 25, 'popup keys were found');
  for (const key of used) assert.ok(Object.hasOwn(en, key), `missing message: ${key}`);
  // Nothing in the catalog is dead apart from the manifest-only strings.
  const manifestOnly = new Set(['extName', 'extDescription', 'actionTitle']);
  for (const key of Object.keys(en)) assert.ok(used.has(key) || manifestOnly.has(key), `unused message: ${key}`);
  assert.ok(html.indexOf('i18n.js') < html.indexOf('popup.js'), 'i18n loads before the scripts that use it');
  assert.doesNotMatch(html.replace(/<style>[\s\S]*?<\/style>/, ''), /[가-힣]/, 'no hard-coded Korean left in the popup');
});

function fakeChrome(messages, language) {
  return { i18n: {
    getUILanguage: () => language,
    getMessage(key, substitutions = []) {
      const entry = messages[key];
      if (!entry) return '';
      return entry.message.replace(/\$([A-Za-z0-9_@]+)\$/g, (_, name) => {
        const content = entry.placeholders[name.toLowerCase()].content;
        return content.replace(/\$(\d)/g, (_, n) => [].concat(substitutions)[n - 1] ?? '');
      });
    },
  } };
}

function loadI18n(messages, language) {
  delete require.cache[require.resolve('./i18n.js')];
  globalThis.chrome = fakeChrome(messages, language);
  try { return require('./i18n.js'); } finally { delete globalThis.PopupI18n; }
}

test('labels are translated for display only', () => {
  const english = loadI18n(en, 'en-US');
  assert.equal(english.label('5시간'), '5-hour');
  assert.equal(english.label('주간'), 'Weekly');
  assert.equal(english.label('사용량'), 'Usage');
  assert.equal(english.label('unexpected'), 'unexpected');
  assert.equal(english.remainingLine([54, 48], ['5시간', '주간']), '5-hour 46% left · Weekly 52% left');
  assert.equal(english.t('checkedAt', ['3:04 PM']), 'Checked 3:04 PM');
  assert.equal(english.t('pinnedOnly', ['a@example.com']), 'Only readings from a@example.com are used.');

  const korean = loadI18n(ko, 'ko');
  assert.equal(korean.remainingLine([54, 48], ['5시간', '주간']), '5시간 46% 남음 · 주간 52% 남음');
  assert.equal(korean.t('checkedAt', ['오후 3:04']), '오후 3:04 확인');
  assert.equal(korean.t('noSuchKey'), 'noSuchKey', 'a missing key is visible rather than blank');
  delete globalThis.chrome;
});

test('static popup text is filled from the catalog', () => {
  const nodes = [
    { dataset: { i18n: 'popupTitle' }, textContent: '' },
    { dataset: { i18n: 'refreshNow' }, textContent: '' },
  ];
  const fields = [{ dataset: { i18nPlaceholder: 'accountPlaceholder' }, placeholder: '' }];
  const doc = {
    documentElement: {}, title: '',
    querySelectorAll: selector => selector === '[data-i18n]' ? nodes : fields,
  };
  loadI18n(en, 'en-GB').apply(doc);
  assert.equal(nodes[0].textContent, 'AI Usage Bar Web Connection');
  assert.equal(nodes[1].textContent, 'Refresh now');
  assert.equal(fields[0].placeholder, 'Leave blank for the current account');
  assert.equal(doc.documentElement.lang, 'en-GB');
  assert.equal(doc.title, 'AI Usage Bar Web Connection');
  delete globalThis.chrome;
});
