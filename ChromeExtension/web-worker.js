/* Independent queues and tab ownership for opt-in Claude/Codex polling. */
(() => {
  'use strict';
  const p=globalThis.WebUsageParser;
  const touched=new Set();
  let queue=Promise.resolve();
  const serial=fn=>{ const next=queue.then(fn,fn); queue=next.catch(()=>{}); return next; };
  const key=id=>'webPending.'+id;
  async function enabled(id) { return ((await chrome.storage.local.get('webEnabled')).webEnabled||[]).includes(id); }
  async function pending(id) { return (await chrome.storage.session.get(key(id)))[key(id)]; }
  async function status(id,state) { await chrome.storage.local.set({['webStatus.'+id]:state}); }
  async function finish(id) {
    const record=await pending(id);
    await chrome.storage.session.remove(key(id));
    await chrome.alarms.clear('web-timeout.'+id);
    if(!record) return;
    try {
      const tab=await chrome.tabs.get(record.tabId);
      if(!tab.active && !record.userTouched && !touched.has(record.tabId)) await chrome.tabs.remove(record.tabId);
    } catch (_) {}
    touched.delete(record.tabId);
  }
  async function deliver(v) {
    // Forward only the protocol fields, even if an incoming object has extra data.
    const clean={version:2,provider:v.provider,status:v.status,sourceURL:v.sourceURL,
      observedAt:v.observedAt,used:v.used,labels:v.labels};
    try {
      const result=await chrome.runtime.sendNativeMessage('com.local.ai_usage_bar.gemini',clean);
      if(!result?.ok) throw new Error('host');
      await status(v.provider,{state:v.status,used:v.used,labels:v.labels,observedAt:v.observedAt});
      return true;
    } catch (_) { await status(v.provider,{state:'host_unavailable'}); return false; }
  }
  function failure(id,state='unavailable') {
    return {version:2,provider:id,status:state,sourceURL:p.URLS[id],observedAt:new Date().toISOString(),used:[],labels:[]};
  }
  async function poll(id) {
    if(!Object.hasOwn(p.URLS,id) || !await enabled(id)) return {started:false};
    const record=await pending(id);
    if(record && Date.now()-record.startedAt<60000) return {started:false};
    await finish(id);
    try {
      const tab=await chrome.tabs.create({url:p.URLS[id],active:false});
      await chrome.storage.session.set({[key(id)]:{tabId:tab.id,startedAt:Date.now(),userTouched:touched.has(tab.id)}});
      await chrome.alarms.create('web-timeout.'+id,{when:Date.now()+35000});
      await status(id,{state:'loading'});
      return {started:true};
    } catch (_) { await deliver(failure(id)); return {started:false}; }
  }
  async function receive(m,sender) {
    const own=sender.url===chrome.runtime.getURL('popup.html');
    if(m.kind==='webToggle' && own && Object.hasOwn(p.URLS,m.provider) && typeof m.enabled==='boolean') {
      const list=new Set((await chrome.storage.local.get('webEnabled')).webEnabled||[]);
      if(m.enabled) list.add(m.provider); else list.delete(m.provider);
      await chrome.storage.local.set({webEnabled:[...list]});
      await finish(m.provider);
      const accepted=await deliver(failure(m.provider,m.enabled?'unavailable':'disabled'));
      if(m.enabled) await poll(m.provider);
      return {accepted};
    }
    if(m.kind==='webRefresh' && own) return poll(m.provider);
    const v=m.value;
    if(m.kind!=='webSnapshot' || sender.frameId!==0 || sender.tab?.id===undefined ||
       !p.validate(v) || v.status==='disabled' || v.sourceURL!==sender.url ||
       p.providerForURL(sender.url)!==v.provider || !await enabled(v.provider)) return {accepted:false};
    const record=await pending(v.provider);
    // Only the tab opened for this poll can supply data; unrelated profiles/tabs
    // cannot race a current poll or keep overwriting the chosen connection.
    if(!record || record.tabId!==sender.tab.id) return {accepted:false};
    const accepted=await deliver(v);
    if(accepted) await finish(v.provider);
    return {accepted};
  }
  chrome.runtime.onMessage.addListener((m,s,r)=>{
    if(!['webToggle','webRefresh','webSnapshot'].includes(m?.kind)) return false;
    serial(()=>receive(m,s)).then(r).catch(()=>r({accepted:false})); return true;
  });
  chrome.alarms.onAlarm.addListener(a=>serial(async()=>{
    if(a.name==='web-refresh') { for(const id of Object.keys(p.URLS)) await poll(id); }
    if(a.name.startsWith('web-timeout.')) {
      const id=a.name.slice('web-timeout.'.length);
      if(Object.hasOwn(p.URLS,id) && await pending(id)) { await deliver(failure(id)); await finish(id); }
    }
  }));
  async function startup() {
    await chrome.alarms.create('web-refresh',{periodInMinutes:5});
    for(const id of Object.keys(p.URLS)) await poll(id);
  }
  chrome.runtime.onInstalled.addListener(()=>serial(startup));
  chrome.runtime.onStartup.addListener(()=>serial(startup));
  chrome.tabs.onActivated.addListener(info=>{
    touched.add(info.tabId);
    serial(async()=>{
      let owned=false;
      for(const id of Object.keys(p.URLS)) {
        const r=await pending(id);
        if(r?.tabId===info.tabId) { owned=true; await chrome.storage.session.set({[key(id)]:{...r,userTouched:true}}); }
      }
      if(!owned) touched.delete(info.tabId);
    });
  });
  chrome.tabs.onRemoved.addListener(tabId=>serial(async()=>{
    touched.delete(tabId);
    for(const id of Object.keys(p.URLS)) { const r=await pending(id); if(r?.tabId===tabId) await finish(id); }
  }));
})();
