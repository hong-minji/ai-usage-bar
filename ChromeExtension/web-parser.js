/* Usage-page text only. No cookies, tokens, account identity or conversation data. */
(function(scope) {
  'use strict';
  const URLS = {claude:'https://claude.ai/settings/usage',codex:'https://chatgpt.com/settings/usage?tab=overview'};
  function providerForURL(value) {
    try {
      if(typeof value !== 'string' || value.length > 2048) return null;
      const u=new URL(value);
      if(u.protocol!=='https:' || u.username || u.password || u.port) return null;
      if(u.hostname==='claude.ai' && (u.pathname==='/settings/usage' || (u.pathname==='/new' && u.hash==='#settings/usage'))) return 'claude';
      if(u.hostname==='chatgpt.com' && u.pathname==='/settings/usage') return 'codex';
    } catch (_) {}
    return null;
  }
  function parse(provider,text) {
    if(!Object.hasOwn(URLS,provider) || typeof text!=='string' || text.length>100000) return null;
    let block=text;
    if(provider==='codex') {
      const start=block.search(/플랜 사용 한도|Plan usage limits/i);
      if(start<0) return null;
      block=block.slice(start);
      // A future shared Chat allowance must not silently be named Codex-only.
      if(/Chat(?:GPT)?(?:\s+conversations?)?\s+(?:is|are)\s+included|Chat\s*대화.*(?:포함됩니다)/i.test(block)) return null;
      block=block.split(/최근 플랜 사용량|Recent plan usage|사용 한도 초기화|Usage limit resets|크레딧|Credits/i)[0];
    } else {
      block=block.split(/제한 초기화|Limit resets|사용 크레딧|Usage credits|Extra usage|이번 주 제품별 사용량/i)[0];
    }
    const lines=block.split(/\n/).map(s=>s.trim()).filter(Boolean);
    const used=[],labels=[];
    let label=null;
    for(const line of lines) {
      if(/^(현재 세션|Current session|5[- ]hour(?: usage)? limit|5시간(?: 사용)? 한도)$/i.test(line)) label='5시간';
      else if(/^(이번 주|주간(?: 사용)? 한도|Weekly(?: usage)? limits?|This week|All models|모든 모델)$/i.test(line)) label='주간';
      const unit=provider==='claude'?'(?:사용됨|used)':'(?:남음|remaining)';
      const marker=new RegExp('%\\s*'+unit,'i');
      if(!marker.test(line)) continue;
      const m=line.match(new RegExp('^([0-9]{1,3}(?:[.,][0-9]+)?)\\s*%\\s*'+unit+'(?:\\s|$)','i'));
      if(!m || !label || labels.includes(label)) return null;
      const n=Number(m[1].replace(',','.'));
      if(!Number.isFinite(n) || n<0 || n>100) return null;
      used.push(provider==='codex'?100-n:n); labels.push(label); label=null;
    }
    return used.length && used.length<=2 ? {used,labels} : null;
  }
  function snapshot(provider,text,sourceURL,now=new Date()) {
    if(providerForURL(sourceURL)!==provider) return null;
    const usage=parse(provider,text);
    return {version:2,provider,status:usage?'ok':'unavailable',sourceURL,observedAt:now.toISOString(),used:usage?.used||[],labels:usage?.labels||[]};
  }
  function validate(v,now=Date.now()) {
    return !!v && Object.hasOwn(URLS,v.provider) && v.version===2 && providerForURL(v.sourceURL)===v.provider &&
      ['ok','unavailable','disabled'].includes(v.status) && typeof v.observedAt==='string' &&
      Number.isFinite(Date.parse(v.observedAt)) && Math.abs(Date.parse(v.observedAt)-now)<=120000 &&
      Array.isArray(v.used) && Array.isArray(v.labels) && v.used.length===v.labels.length &&
      (v.status==='ok' ? v.used.length>0 && v.used.length<=2 && new Set(v.labels).size===v.labels.length : v.used.length===0) &&
      v.used.every(n=>typeof n==='number' && Number.isFinite(n) && n>=0 && n<=100) &&
      v.labels.every(s=>['5시간','주간'].includes(s));
  }
  const api={URLS,providerForURL,parse,snapshot,validate};
  scope.WebUsageParser=api;
  if(typeof module!=='undefined' && module.exports) module.exports=api;
})(globalThis);
