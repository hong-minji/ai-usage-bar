const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const tick=()=>new Promise(resolve=>setImmediate(resolve));

function contentHarness(file,accepted=true) {
  let now=0,sent=0,cleared=0,disconnected=0,interval;
  const body={innerText:'Usage\nCurrent session\n20% used'};
  const heading={textContent:'Usage',getClientRects:()=>[1],parentElement:{innerText:body.innerText,parentElement:body}};
  const value={status:'ok',provider:'claude',used:[20],labels:['5시간']};
  const parser={isUsageURL:()=>true,providerForURL:()=> 'claude',snapshot:()=>value,syncAccount:async()=>{},setExpectedAccount(){}};
  const chrome={storage:{local:{get:async()=>({webEnabled:['claude']})},onChanged:{addListener(){}}},runtime:{sendMessage:async()=>{sent++;return {accepted:await accepted}}}};
  vm.runInNewContext(fs.readFileSync(__dirname+'/'+file,'utf8'),{
    chrome,WebUsageParser:parser,GeminiUsageParser:parser,location:{href:'https://claude.ai/settings/usage'},
    Date:{now:()=>now},document:{body,documentElement:{},querySelectorAll:()=>file==='web-content.js'?[heading]:[]},
    getComputedStyle:()=>({visibility:'visible'}),MutationObserver:class{observe(){}disconnect(){disconnected++}},
    setInterval:f=>{interval=f;return 1},clearInterval:()=>{cleared++},setTimeout,clearTimeout
  });
  return {run:()=>interval(),advance:()=>{now=100000},get sent(){return sent},get cleared(){return cleared},get disconnected(){return disconnected}};
}
for(const file of ['content.js','web-content.js']) {
  test(file+' stops polling after accepted report in a user-retained tab',async()=>{
    const h=contentHarness(file);await tick();await tick();
    assert.equal(h.sent,1);assert.ok(h.cleared>0);
    if(file==='content.js')assert.ok(h.disconnected>0);
    h.run();await tick();assert.equal(h.sent,1);
  });
  test(file+' bounds unsuccessful polling lifetime',async()=>{
    const h=contentHarness(file,false);await tick();h.advance();h.run();await tick();
    assert.ok(h.cleared>0);assert.equal(h.sent,1);
  });
}

for(const file of ['content.js','web-content.js']) {
  test(file+' coalesces timer callbacks while the host is responding',async()=>{
    let finish;const pending=new Promise(resolve=>finish=resolve);
    const h=contentHarness(file,pending);await tick();
    h.run();h.run();await tick();assert.equal(h.sent,1);
    finish(true);await tick();assert.ok(h.cleared>0);
  });
}
