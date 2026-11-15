/* Two small touches: copy the Homebrew command, and let the example reading
   in the menu bar drain slowly, the way a real quota does. */
(() => {
  'use strict';

  for (const button of document.querySelectorAll('[data-copy]')) {
    button.addEventListener('click', async () => {
      const done = button.dataset.done || 'Copied';
      const label = button.textContent;
      try {
        await navigator.clipboard.writeText(button.dataset.copy);
        button.textContent = done;
        setTimeout(() => { button.textContent = label; }, 1600);
      } catch (_) { /* Clipboard blocked: the command is still selectable. */ }
    });
  }

  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  const bar = document.querySelector('[data-demo="bar"]');
  const row = document.querySelector('[data-demo="row"]');
  const on = document.querySelector('[data-demo="meter-on"]');
  const off = document.querySelector('[data-demo="meter-off"]');
  if (!bar || !row || !on || !off) return;

  let remaining = Number(bar.textContent);
  const floor = remaining - 9;
  const timer = setInterval(() => {
    if (document.hidden) return;
    remaining -= 1;
    for (const node of [bar, row]) {
      node.textContent = String(remaining);
      node.classList.remove('tick');
      void node.offsetWidth;
      node.classList.add('tick');
    }
    // Same 10-cell gauge the app draws: filled cells are what is left.
    const filled = Math.round(remaining / 10);
    on.textContent = '█'.repeat(filled);
    off.textContent = '░'.repeat(10 - filled);
    if (remaining <= floor) clearInterval(timer);
  }, 4200);
})();
