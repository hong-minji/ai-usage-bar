(() => {
  const p=globalThis.WebUsageParser;
  const messages={loading:'사용량을 읽는 중…',unavailable:'사용량을 읽지 못했습니다. Chrome 로그인과 사용량 페이지를 확인하세요.',disabled:'연결 꺼짐',host_unavailable:'앱 설정 → Chrome 연결…을 누르고 확장을 새로고침하세요.'};
  async function render() {
    const data=await chrome.storage.local.get(['webEnabled','webStatus.claude','webStatus.codex','autoRefresh']);
    document.getElementById('auto-refresh').checked=data.autoRefresh!==false;
    for(const id of Object.keys(p.URLS)) {
      document.getElementById(id+'-enabled').checked=(data.webEnabled||[]).includes(id);
      const s=data['webStatus.'+id];
      document.getElementById(id+'-result').textContent=s?.state==='ok'
        ? s.used.map((n,i)=>s.labels[i]+' '+Math.round(100-n)+'% 남음').join(' · ')
        : messages[s?.state] || '연결을 켜면 현재 Chrome 로그인으로 확인합니다.';
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
