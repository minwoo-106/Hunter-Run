const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const root=require('path').resolve(__dirname,'..');
const source=fs.readFileSync(root+'/scripts/defense-review-controls.js','utf8');
const lines=JSON.parse(fs.readFileSync(root+'/Resources/defense-lines.json','utf8'));
const clips=JSON.parse(fs.readFileSync(root+'/Resources/defense-voice.json','utf8')).clips;
const DATA={lines,hashes:Object.fromEntries(clips.map(c=>[c.key,c.sha256])),ready:clips.map(c=>c.key)};
function boot(saved={},data=DATA) {
 const nodes=new Map(),verdictButtons=[],events={};let disk=JSON.stringify(saved),fail=false;
 class El {
  constructor(tag='div'){this.tagName=tag.toUpperCase();this.children=[];this.dataset={};this.style={};this.value='';this.paused=true;this.currentTime=0;this.attrs={};this.checked=false;const set=new Set();this.classList={add:c=>set.add(c),remove:c=>set.delete(c),contains:c=>set.has(c),toggle:(c,f)=>{if(f===undefined)f=!set.has(c);if(f)set.add(c);else set.delete(c);}};}
  set id(v){this._id=v;nodes.set(v,this)} get id(){return this._id}
  set innerHTML(s){this.children=[];for(const m of s.matchAll(/<(\w+)\b([^>]*)>/g)){const tag=m[1],attrs=m[2],el=new El(tag),id=/\bid="([^"]+)"/.exec(attrs),verdict=/data-verdict="([^"]+)"/.exec(attrs);if(id)el.id=id[1];if(verdict){el.dataset.verdict=verdict[1];verdictButtons.push(el);}if(/\bchecked\b/.test(attrs))el.checked=true;if(id?.[1]==='reviewFilter')el.value='all';this.children.push(el);}}
  append(...els){for(const el of els){this.children.push(el);if(this.tagName==='SELECT'&&this.children.length===1)this.value=el.value;}}
  get options(){return this.children}before(){}replaceChildren(){this.children=[]}setAttribute(k,v){this.attrs[k]=v}removeAttribute(k){delete this[k]}pause(){this.paused=true}play(){this.paused=false;return Promise.resolve()}focus(){this.focused=true}select(){}click(){if(!this.disabled&&this.onclick)this.onclick()}remove(){}showModal(){this.open=true}close(){this.open=false}
 }
 const document={head:new El(),body:new El(),createElement:t=>new El(t),querySelector:s=>s[0]==='#'?nodes.get(s.slice(1)):verdictButtons.find(b=>s.includes('"'+b.dataset.verdict+'"')),querySelectorAll:s=>s==='[data-verdict]'?verdictButtons:[],addEventListener:(n,f)=>events[n]=f};
 const voice=new El();voice.id='voice';
 const context=vm.createContext({console,DATA:structuredClone(data),document,$:document.querySelector,location:{hash:'#voice'},window:{addEventListener(){}},localStorage:{getItem:()=>disk,setItem:(_,v)=>{if(fail)throw Error('full');disk=v;}},Blob,URL,setTimeout});
 vm.runInContext('const keys=Object.keys(DATA.lines);'+source+';renderVoices();',context);
 return {get:s=>document.querySelector(s),run:s=>vm.runInContext(s,context),disk:()=>JSON.parse(disk),fail:()=>fail=true,buttons:verdictButtons};
}
const old={defense_01_brief:{status:'ok',note:'첫 문장 좋음',sha256:DATA.hashes.defense_01_brief},defense_01_rest1:{status:'voice',note:'마지막부터 달라요',sha256:DATA.hashes.defense_01_rest1}};
let b=boot(old);
assert.equal(b.disk().defense_01_rest1.note,'마지막부터 달라요');
assert.equal(b.run('activeKey'),'defense_01_rest2'); // resume first unchecked
b.get('#reviewNote').value='마지막 문장';b.get('#reviewNote').oninput();
const key=b.run('activeKey');b.get('[data-verdict="voice"]').click();assert.equal(b.run('activeKey'),key);assert.equal(b.disk()[key].status,'voice');
b.get('#clipAudio').currentTime=7.8;b.get('#stamp').click();assert.match(b.disk()[key].note,/00:07부터 달라짐/);
b.get('#nextClip').click();assert.equal(b.run('activeKey'),'defense_01_outro');b.get('[data-verdict="ok"]').click();assert.equal(b.get('#filter').value,'exercise');assert.equal(b.run('queue.length'),21);
b.get('#nextCategory').click();assert.equal(b.get('#filter').value,'shared');assert.equal(b.run('queue.length'),10);b.get('#nextCategory').click();assert.equal(b.get('#filter').value,'2');assert.equal(b.run('queue.length'),4);
b.run("DATA.hashes.defense_01_rest1='changed';");assert.equal(b.run("verdict('defense_01_rest1').status"),'pending');assert.equal(b.run("verdict('defense_01_rest1').note"),'마지막부터 달라요');assert.equal(b.run("reviewRows().find(r=>r.key==='defense_01_rest1').sha256"),old.defense_01_rest1.sha256);
b.run("saveReview('defense_01_rest1','ok','수정본 좋음')");assert.equal(b.disk().defense_01_rest1.history[0].note,'마지막부터 달라요');
b.run("importRows({entries:[{key:'defense_01_brief',status:'voice',note:'덮어쓰면 안됨',sha256:'x'}]})");assert.equal(b.disk().defense_01_brief.status,'ok');
b.get('#reviewFilter').value='ok';b.run('renderVoices()');assert.equal(b.run('activeKey'),null);assert.equal(b.get('#playClip').disabled,true);
b.fail();b.run("saveReview('defense_02_brief','voice','보관')");assert.match(b.get('#saveNotice').textContent,/내보내/);assert.equal(b.run("reviewRows().find(r=>r.key==='defense_02_brief').note"),'보관');
const restored=boot(b.disk());assert.equal(restored.run("verdict('defense_01_brief').status"),'ok');
console.log('PASS: original marks, resume, note autosave, timestamp, verdict navigation, category transitions, changed-hash history/export, non-destructive import, empty scope, storage failure, reload. Synthetic data only; no user browser storage accessed.');
const revisionData=structuredClone(DATA);
revisionData.reviewBaseline=Object.entries(old).map(([key,r])=>({key,...r}));
revisionData.hashes.defense_01_rest1='revision-fixture';
revisionData.revisions={defense_01_rest1:{method:'preserve-prefix-and-revoice-tail',note:'마지막부터 달라요'}};
const revised=boot({},revisionData);
assert.equal(revised.get('#filter').value,'all');
assert.equal(revised.get('#reviewFilter').value,'revisionBatch');
assert.equal(revised.run('queue.length'),1);
assert.equal(revised.run('activeKey'),'defense_01_rest1');
assert.equal(revised.run("verdict('defense_01_brief').status"),'ok');
assert.equal(revised.run("verdict('defense_01_rest1').status"),'pending');
assert.match(revised.get('#beforeAudio').src,/audio-before/);
assert.equal(revised.get('#reviewNote').value,'마지막부터 달라요');
revised.get('[data-verdict="ok"]').click();
assert.equal(revised.disk().defense_01_rest1.history[0].note,'마지막부터 달라요');
const reopened=boot(revised.disk(),revisionData);
assert.equal(reopened.run("verdict('defense_01_rest1').status"),'ok');
console.log('PASS: supplied feedback baseline, revision-only queue, before/after source, retained notes/history, latest local verdict wins.');
