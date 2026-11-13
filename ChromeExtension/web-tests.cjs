const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const p = require('./web-parser.js');
const fixture = name => fs.readFileSync(__dirname + '/fixtures/' + name, 'utf8');
test('observed Claude usage excludes product breakdown and credits', () => {
  assert.deepEqual(p.parse('claude', fixture('claude-usage-ko.txt')), {used:[14,38],labels:['5시간','주간']});
});
test('observed Codex remaining quota is inverted, discounts are excluded', () => {
  assert.deepEqual(p.parse('codex', fixture('codex-usage-ko.txt')), {used:[87],labels:['주간']});
});
test('English labels and two Codex windows', () => {
  assert.deepEqual(p.parse('codex','Plan usage limits\nChat conversations are included\nWeekly usage limit\n30% remaining'), {used:[70],labels:['주간']});
  assert.deepEqual(p.parse('claude','Usage\nCurrent session\n10% used\nWeekly limits\nAll models\n25% used\nUsage credits\n50% used'), {used:[10,25],labels:['5시간','주간']});
  assert.deepEqual(p.parse('codex','Plan usage limits\n5-hour usage limit\n80% remaining\nWeekly usage limit\n30% remaining\nCredits\n50% remaining'), {used:[20,70],labels:['5시간','주간']});
});
test('missing, out-of-range, duplicate and unsupported data fail closed', () => {
  for (const s of ['', '사용량 없음', '현재 세션\n101% 사용됨', '현재 세션\n-1% 사용됨','현재 세션\n1000% 사용됨', '현재 세션\nNaN% 사용됨','현재 세션\n10% 사용됨\n현재 세션\n20% 사용됨']) assert.equal(p.parse('claude',s),null,s);
  assert.equal(p.parse('codex','주간 사용 한도\n13% 남음'),null);
  for (const id of ['gpt','__proto__','constructor',null]) assert.equal(p.parse(id,fixture('codex-usage-ko.txt')),null);
  assert.equal(p.parse('codex','Plan usage limits\nWeekly usage limit\n-5% remaining'),null);
});
test('only observed usage routes are accepted; chats and lookalike hosts excluded', () => {
  for(const u of ['https://claude.ai/settings/usage','https://claude.ai/new#settings/usage']) assert.equal(p.providerForURL(u),'claude');
  assert.equal(p.providerForURL('https://chatgpt.com/settings/usage?tab=overview'),'codex');
  for(const u of ['https://claude.ai/new','https://claude.ai/chat/a#settings/usage','https://chatgpt.com/','https://chatgpt.com/c/a','https://chatgpt.com/settings/account','https://chatgpt.com.evil.test/settings/usage','https://x@chatgpt.com/settings/usage','https://chatgpt.com:8080/settings/usage']) assert.equal(p.providerForURL(u),null,u);
});
test('messages are bounded, fresh and cannot substitute a different provider', () => {
  const v=p.snapshot('codex',fixture('codex-usage-ko.txt'),p.URLS.codex);
  assert.equal(p.validate(v),true);
  for(const bad of [{...v,provider:null,sourceURL:'invalid'},{...v,provider:'__proto__'},{...v,provider:'gpt'},{...v,provider:'claude'},{...v,used:[NaN]},{...v,used:[101]},{...v,labels:['private text']},{...v,observedAt:new Date(0).toISOString()},{...v,status:'disabled',used:[10]}]) assert.equal(p.validate(bad),false);
  assert.equal(p.validate({...v,status:'unavailable',used:[],labels:[]}),true);
});

const vm = require('node:vm');
function event(){const handlers=[];return {addListener:f=>handlers.push(f),emit:(...args)=>Promise.all(handlers.map(f=>f(...args)))}};
function area(){const data={};return {data,async get(k){return {[k]:data[k]}},async set(v){Object.assign(data,structuredClone(v))},async remove(k){delete data[k]}}};
function worker(initial={}) {
  let id=0,works=true;
  const tabs=new Map(),removed=[],native=[];
  const chrome={storage:{local:area(),session:area()},runtime:{onInstalled:event(),onStartup:event(),onMessage:event(),getURL:s=>'chrome-extension://test/'+s,async sendNativeMessage(host,v){if(!works)throw Error('host');native.push(structuredClone(v));return {ok:true}}},tabs:{onRemoved:event(),onActivated:event(),async create(v){const t={...v,id:++id};tabs.set(id,t);return t},async get(i){if(!tabs.has(i))throw Error('missing');return tabs.get(i)},async remove(i){tabs.delete(i);removed.push(i)}},alarms:{onAlarm:event(),async create(){},async clear(){}}};
  Object.assign(chrome.storage.local.data,initial);
  vm.runInNewContext(fs.readFileSync(__dirname+'/web-worker.js','utf8'),{chrome,WebUsageParser:p,Date,Promise,Set});
  return {chrome,tabs,removed,native,failHost(){works=false},message:(m,s={url:'chrome-extension://test/popup.html'})=>new Promise(resolve=>chrome.runtime.onMessage.emit(m,s,resolve)),async alarm(name){await chrome.alarms.onAlarm.emit({name})}};
}
test('web polling is opt-in and separate per provider; concurrent refresh coalesces',async()=>{
  const h=worker(); await h.alarm('web-refresh'); assert.equal(h.tabs.size,0);
  await h.message({kind:'webToggle',provider:'claude',enabled:true});
  await h.message({kind:'webToggle',provider:'codex',enabled:true});
  await Promise.all([h.alarm('web-refresh'),h.message({kind:'webRefresh',provider:'claude'})]);
  assert.equal(h.tabs.size,2); assert.equal([...h.tabs.values()].every(t=>!t.active),true);
});
test('forged, unrelated, disabled and cross-provider reports do not reach native host',async()=>{
  const h=worker({webEnabled:['codex']}); await h.alarm('web-refresh');
  const tab=[...h.tabs.values()][0],v=p.snapshot('codex',fixture('codex-usage-ko.txt'),tab.url);
  for(const sender of [{url:'https://evil.test/settings/usage',frameId:0,tab},{url:tab.url,frameId:1,tab},{url:tab.url,frameId:0,tab:{id:99}}]) assert.equal((await h.message({kind:'webSnapshot',value:v},sender)).accepted,false);
  assert.equal((await h.message({kind:'webSnapshot',value:{...v,status:'disabled',used:[],labels:[]}},{url:tab.url,frameId:0,tab})).accepted,false);
  assert.equal(h.native.length,0);
  assert.equal((await h.message({kind:'webSnapshot',value:{...v,secret:'must not forward'}},{url:tab.url,frameId:0,tab})).accepted,true);
  assert.equal(h.native.length,1);assert.equal(h.native[0].secret,undefined);assert.deepEqual(h.removed,[tab.id]);
});
test('usage redirects preserve document identity but require the current owned URL',async()=>{
  const h=worker({webEnabled:['claude']});await h.alarm('web-refresh');
  const tab=[...h.tabs.values()][0],original=tab.url;
  tab.url='https://claude.ai/new#settings/usage';
  const v=p.snapshot('claude',fixture('claude-usage-ko.txt'),tab.url);
  const sender={url:original,frameId:0,tab};
  tab.url='https://claude.ai/new';
  assert.equal((await h.message({kind:'webSnapshot',value:v},sender)).accepted,false);
  tab.url=v.sourceURL;
  assert.equal((await h.message({kind:'webSnapshot',value:v},sender)).accepted,true);
});
test('web polls preserve user-selected tabs and clean redirect/timeouts',async()=>{
  for(const touch of [true,false]){
    const h=worker({webEnabled:['claude']});await h.alarm('web-refresh');
    const tab=[...h.tabs.values()][0];
    if(touch)await h.chrome.tabs.onActivated.emit({tabId:tab.id});
    // Drain queued activation before timing out.
    await h.message({kind:'webRefresh',provider:'claude'});
    tab.url='https://claude.ai/login';
    await h.alarm('web-timeout.claude');
    assert.deepEqual(h.removed,touch?[]:[tab.id]);
    assert.equal(h.native[0].status,'unavailable');
  }
});
test('disabling reports disconnection and stops polling; a page cannot toggle',async()=>{
  const h=worker({webEnabled:['claude']});await h.alarm('web-refresh');
  assert.equal((await h.message({kind:'webToggle',provider:'claude',enabled:false},{url:p.URLS.claude})).accepted,false);
  await h.message({kind:'webToggle',provider:'claude',enabled:false});
  await h.alarm('web-refresh');assert.equal(h.tabs.size,0);assert.equal(h.native.at(-1).status,'disabled');
});
test('host failure is explicit and timeout releases the owned background tab',async()=>{
  const h=worker({webEnabled:['codex']});h.failHost();await h.alarm('web-refresh');
  await h.alarm('web-timeout.codex');assert.equal(h.tabs.size,0);
  assert.equal(h.chrome.storage.local.data['webStatus.codex'].state,'host_unavailable');
});
