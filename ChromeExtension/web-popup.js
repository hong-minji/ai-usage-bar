(() => {
  const p=globalThis.WebUsageParser;
  const {t,remainingLine}=globalThis.PopupI18n;
  const messages={loading:()=>t('webLoading'),unavailable:()=>t('webUnavailable'),disabled:()=>t('webDisabled'),host_unavailable:()=>t('webHostUnavailable')};
  async function render() {
    const data=await chrome.storage.local.get(['webEnabled','webStatus.claude','webStatus.codex','autoRefresh']);
    document.getElementById('auto-refresh').checked=data.autoRefresh!==false;
    for(const id of Object.keys(p.URLS)) {
      document.getElementById(id+'-enabled').checked=(data.webEnabled||[]).includes(id);
      const s=data['webStatus.'+id];
      document.getElementById(id+'-result').textContent=s?.state==='ok'
        ? remainingLine(s.used,s.labels)
        : Object.hasOwn(messages,s?.state) ? messages[s.state]() : t('webIdle');
    }
  }
  for(const id of Object.keys(p.URLS)) {
    document.getElementById(id+'-enabled').addEventListener('change',async e=>{
      await chrome.runtime.sendMessage({kind:'webToggle',provider:id,enabled:e.target.checked}); await render();
    });
    document.getElementById(id+'-refresh').addEventListener('click',async()=>{
      await chrome.runtime.sendMessage({kind:'webRefresh',provider:id}); await render();
    });
    document.getElementById(id+'-page').addEventListener('click',()=>chrome.tabs.create({url:p.URLS[id]}));
  }
  document.getElementById('auto-refresh').addEventListener('change',async e=>{
    await chrome.storage.local.set({autoRefresh:e.target.checked}); await render();
  });
  chrome.storage.onChanged.addListener(render);
  render();
})();
