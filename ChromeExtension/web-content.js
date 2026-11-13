/* Only extracts a settings/usage section, never a conversation or account token. */
(() => {
  'use strict';
  const p=globalThis.WebUsageParser;
  let last='', retry=0, stopped=false;
  const started=Date.now();
  function sectionText(provider) {
    // Select the smallest ancestor of the Usage heading containing a quota meter.
    // Do not fall back to document.body, where unrelated page content could live.
    const headings=[...document.querySelectorAll('h1,h2,h3,[role="heading"]')]
      .filter(n=>/^(사용량|Usage)$/i.test(n.textContent.trim()) && n.getClientRects().length);
    for(const heading of headings) {
      let node=heading.parentElement;
      for(let i=0;node && node!==document.body && i<6;i++,node=node.parentElement) {
        const text=node.innerText||'';
        if(text.length>100000) break;
        if(provider==='codex' ? /플랜 사용 한도|Plan usage limits/i.test(text) : /현재 세션|이번 주|Current session|Weekly limits|This week/i.test(text)) return text;
      }
    }
    return '';
  }
  let inFlight = false;
  async function read() {
    if (inFlight) return;
    inFlight = true;
    try { await readOnce(); } finally { inFlight = false; }
  }
  async function readOnce() {
    if(stopped) return;
    if(Date.now()-started>45000) { stopped=true; clearInterval(timer); return; }
    if(Date.now()<retry) return;
    const provider=p.providerForURL(location.href);
    if(!provider) return;
    const stored=await chrome.storage.local.get('webEnabled');
    if(!stored.webEnabled?.includes(provider)) return;
    const value=p.snapshot(provider,sectionText(provider),location.href);
    if(!value || (value.status!=='ok' && Date.now()-started<20000)) return;
    const key=JSON.stringify([provider,value.status,value.used,value.labels]);
    if(last===key) return;
    try {
      const reply=await chrome.runtime.sendMessage({kind:'webSnapshot',value});
      if(reply?.accepted) { last=key; stopped=true; clearInterval(timer); }
      else retry=Date.now()+30000;
    } catch (_) { stopped=true; clearInterval(timer); }
  }
  const timer=setInterval(()=>read().catch(()=>{}),1500);
  read().catch(()=>{});
})();
