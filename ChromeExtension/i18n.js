/* Popup text in the browser's language. Window labels ("5시간", "주간") are
   protocol identifiers shared with the menu bar app, so they are translated
   only for display and never changed in stored or forwarded data. */
(function (scope) {
  'use strict';
  const LABEL_KEYS = { '5시간': 'label5h', '주간': 'labelWeekly', '사용량': 'labelUsage' };

  function t(key, substitutions) {
    return chrome.i18n.getMessage(key, substitutions) || key;
  }

  function label(value) {
    return Object.hasOwn(LABEL_KEYS, value) ? t(LABEL_KEYS[value]) : String(value ?? '');
  }

  /** "5-hour 46% left · Weekly 52% left" from parallel used/labels arrays. */
  function remainingLine(used, labels) {
    return used.map((n, i) => `${label(labels[i])} ${Math.round(100 - n)}% ${t('remainingSuffix')}`).join(' · ');
  }

  function apply(doc) {
    for (const node of doc.querySelectorAll('[data-i18n]')) node.textContent = t(node.dataset.i18n);
    for (const node of doc.querySelectorAll('[data-i18n-placeholder]')) node.placeholder = t(node.dataset.i18nPlaceholder);
    doc.documentElement.lang = chrome.i18n.getUILanguage();
    doc.title = t('popupTitle');
  }

  const api = { t, label, remainingLine, apply };
  scope.PopupI18n = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (typeof document !== 'undefined') apply(document);
})(globalThis);
