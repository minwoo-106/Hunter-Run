// 브라우저 없이 생성된 보고서의 문법·필터·복사 데이터 계약을 검사한다.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync(process.argv[2], 'utf8');
const json = id => html.match(new RegExp(`<script id="${id}" type="application/json">([\\s\\S]*?)</script>`))[1];
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const nodes = Object.fromEntries(['data', 'fulltext', 'level', 'metric', 'search', 'head', 'body', 'gear', 'copy', 'copyAll', 'status'].map(id => [id, {
    value: id === 'level' ? '30' : id === 'metric' ? 'meters' : '',
    textContent: ['data', 'fulltext'].includes(id) ? json(id) : '', innerHTML: '',
    addEventListener: () => {}
}]));
let copied = '';
const context = vm.createContext({document: {querySelector: id => nodes[id.slice(1)], getElementById: id => nodes[id]},
    navigator: {clipboard: {writeText: async text => { copied = text; }}}});
vm.runInContext(script, context);
assert.equal((nodes.body.innerHTML.match(/<tr>/g) || []).length, 37);
assert.ok(nodes.body.innerHTML.includes('21,900'));
assert.ok(nodes.body.innerHTML.includes('5,025'));
nodes.level.value = '15'; nodes.search.value = '잔향 늑대'; vm.runInContext('render()', context);
assert.equal((nodes.body.innerHTML.match(/<tr>/g) || []).length, 1);
assert.ok(nodes.body.innerHTML.includes('150'));
nodes.metric.value = 'hits'; vm.runInContext('render()', context);
assert.ok(nodes.body.innerHTML.includes('>2</td>'));
(async () => {
    await nodes.copy.onclick(); assert.ok(copied.startsWith('Lv.15')); assert.ok(copied.includes('잔향 늑대'));
    await nodes.copyAll.onclick(); assert.equal(copied, JSON.parse(json('fulltext')));
    assert.equal(nodes.status.textContent, '복사했습니다.');
    console.log('거리표 37행·레벨/검색/공격 횟수 선택·전체 복사 데이터 검사 통과');
})().catch(error => { console.error(error); process.exitCode = 1; });
