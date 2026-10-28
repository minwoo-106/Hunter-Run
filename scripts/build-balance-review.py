"""실제 Swift 전투 계산 결과에서 전체 표와 오프라인 검토 화면을 생성한다."""
import html
import json
import pathlib
import sys

folder = pathlib.Path(sys.argv[1])
data = json.loads((folder / 'balance-report.json').read_text(encoding='utf-8'))
assert len(data['targets']) == 37 and data['verifiedBoundaries'] == 2664
root = pathlib.Path(__file__).resolve().parents[1]
old = json.loads((root / 'Tests/HunterCoreTests/Fixtures/combat-v3-legacy-1.9.1.json').read_text(encoding='utf-8'))
old_hp = {m['id']: m['maximumHP'] for m in old['monsters']}
old_hp.update(dict(zip(['exam-D', 'exam-C', 'exam-B', 'exam-A', 'exam-S'], [200, 420, 650, 900, 1400])))
for target in data['targets']:
    if target['kind'] == '변이 재전':
        parent = 'boundary-lord' if 'boundary-lord' in target['id'] else 'void-librarian'
        old_hp[target['id']] = old_hp[parent] * 1.15
    elif target['kind'] == '일반 재전':
        old_hp[target['id']] = old_hp[target['id'].removesuffix('-replay')]
    target['oldHP'] = old_hp.get(target['id'], target['hp'])

notes = '''Hunter Run 1.9.2 — 전체 몬스터·보스 HP와 장비별 교전 거리

거리 단위: m. 인정된 공격 거리 75m마다 1회 공격하며, 처치까지 필요한 공격 횟수×75m입니다.
이동 총거리와 다릅니다. 조우 전 이동·음성 안내·걷기·GPS 보류 구간은 별도입니다.
최종전의 기존 안전 걷기 대안은 유지됩니다. 그 대안의 소요 시간은 이 거리표로 환산하지 않습니다.
신발은 공격 간격을 줄이지 않습니다. 장비 공격력으로 필요한 공격 횟수가 줄어듭니다.
레벨과 장비를 독립 비교한 표이며, 레벨로 등급·스토리 해금을 추정하지 않습니다.
귀환 장비는 최종 보스 첫 공략 이후 보상입니다. 첫 공략용 최상위 비교는 철갑 조합입니다.
기존 보스 공략은 저장된 최대·남은 HP 그대로 유지합니다. 표의 새 HP는 새 공략 기준입니다.
일반 몬스터도 업데이트 당시 진행 중인 활동의 스냅샷은 보존하고, 다음 활동부터 새 HP를 씁니다.
보스는 여러 활동에 걸쳐 누적 공략할 수 있습니다. 아래 거리를 한 번에 달려야 하는 것은 아닙니다.
이전 공격력 하한이 높은 구세이브는 실제 공격력이 표보다 클 수 있습니다.
EXP·방어력·장비 계수·75m 공격 간격·해금 조건은 이번 패치에서 바꾸지 않았습니다.
심사 표의 EXP=0은 몬스터 추가 EXP가 없다는 뜻입니다. 기존 심사·의뢰 보상은 유지됩니다.
재전의 실제 보상은 별도 재전 보상 규칙을 따릅니다.
'''
equipment = ['장비 조합 (무기 / 신발 / 유물)'] + [g['name'] + ': ' + (' / '.join(g['names']) or '없음') for g in data['equipment']]
index = {(r['level'], r['target'], r['gear']): r for r in data['rows']}
lines = [notes, '\n'.join(equipment)]
for level in [30, 15, 1, 10, 20, 45, 60, 100]:
    lines.extend(['', f'Lv.{level} — 교전 거리 (m)', '몬스터·보스 | 이전HP → 새HP | 방어 | ' + ' | '.join(g['name'] for g in data['equipment'])])
    for t in data['targets']:
        distances = [f"{index[level, t['id'], g['name']]['meters']:,.0f}" for g in data['equipment']]
        lines.append(f"{t['name']} | {t['oldHP']:,.0f} → {t['hp']:,.0f} | {t['defense']:.0f} | " + ' | '.join(distances))
    lines.append('장비별 실제 ATK: ' + ' / '.join(f"{g['name']} {index[level, data['targets'][0]['id'], g['name']]['attack']:.4f}" for g in data['equipment']))
(folder / '전체-몬스터-보스-거리표.txt').write_text('\n'.join(lines), encoding='utf-8')
(folder / 'balance-report.json').write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
page = r'''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>헌터런 1.9.2 전투 거리표</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#080f16;color:#e7edef;font:15px/1.65 system-ui,sans-serif}main{max-width:1600px;margin:auto;padding:32px 24px}h1{font-size:32px;letter-spacing:-1px}h2{font-size:21px;margin-top:30px}p{color:#aec0ca}.tag{color:#4edbd1;font-weight:700}.cards{display:flex;gap:16px;flex-wrap:wrap}.card{flex:1;min-width:230px;border:1px solid #2c434c;padding:20px;background:#111e27;border-radius:14px}.card strong{display:block;color:#5ee2d4;font-size:29px}.controls{position:sticky;top:0;z-index:2;background:#0d1823;padding:14px 0;display:flex;gap:10px;align-items:center;flex-wrap:wrap}select,input,button,a.btn{border:1px solid #41616b;background:#132936;color:#fff;border-radius:8px;padding:10px;font:inherit;text-decoration:none}button{cursor:pointer}button:hover{background:#275462}input{min-width:200px}.scroll{overflow:auto;max-height:72vh;border:1px solid #30414f;border-radius:10px}table{border-collapse:separate;border-spacing:0;width:100%;white-space:nowrap;font-variant-numeric:tabular-nums}th,td{text-align:right;padding:12px;border-bottom:1px solid #263741}thead th{position:sticky;top:0;background:#15303b;z-index:1}td:first-child,th:first-child{position:sticky;left:0;text-align:left;background:#111e28}th:first-child{z-index:2}tbody tr:hover td{background:#1b3543}td small{display:block;color:#9badb7;font-size:11px}td.final{color:#62e0ca}details{margin:22px 0;padding:18px;background:#111e28;border-radius:12px}pre{white-space:pre-wrap;font:inherit;color:#bfd0d8}.muted{font-size:13px;color:#9badb7}#status{color:#61dcca}.gear{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:10px}.gear div{background:#152632;padding:12px;border-radius:8px}
</style><main><span class="tag">HUNTER RUN · 1.9.2</span><h1>장비를 갖출수록, 보스까지의 거리는 짧게.</h1><p>전체 37종 · 장비 조합 9개 · 레벨 8구간. 실제 앱의 전투 계산으로 생성하고 2,664개 조합의 마지막 1m 경계와 중복 공격을 확인했습니다.</p>
<div class="cards"><div class="card">경계의 군주 · Lv.30 첫 코어<strong>1,050m</strong>HP 2,200 · 첫 주요 보스</div><div class="card">공허의 사서 · Lv.30 거울결<strong>2,400m</strong>HP 10,000 · 중반 주요 보스</div><div class="card">강해솔 · Lv.30 철갑<strong>5,025m</strong>HP 21,900 · 첫 공략 이전 장비</div></div>
<p>기존 공략의 최대·남은 HP는 그대로 보존합니다. 이 표는 새 공략 기준이며, 보스 피해는 여러 활동에 걸쳐 누적할 수 있습니다.</p>
<div class="controls"><label>레벨 <select id="level"></select></label><label>표시 <select id="metric"><option value="meters">교전 거리 (m)</option><option value="hits">공격 횟수</option><option value="damage">1회 피해</option></select></label><input id="search" aria-label="몬스터 검색" placeholder="이름 검색"><button id="copy">현재 표 복사</button><button id="copyAll">전체 8레벨 복사</button><a class="btn" download href="전체-몬스터-보스-거리표.txt">텍스트 저장</a><span id="status" aria-live="polite"></span></div>
<div class="scroll"><table><thead id="head"></thead><tbody id="body"></tbody></table></div><p class="muted">현재 표는 같은 레벨에서 장비만 바꾼 비교입니다. 귀환은 최종전 이후 장비입니다. 거리에는 조우·안내·GPS 보류 구간을 포함하지 않습니다.</p>
<h2>장비 조합과 공격력</h2><div class="gear" id="gear"></div><details><summary>계산 기준과 기존 진행 보호</summary><pre>NOTES</pre></details><details><summary>개편 의도와 실제 활동에서의 차이</summary><p>잔향 늑대·균열 살쾡이·철각 파수병의 초반 기준은 유지했습니다. 게이트 핵과 정예·선발대의 체력을 늘려 강한 장비가 필요한 이유를 구분했습니다. 주요 보스는 첫 공략 전에 얻을 수 있는 장비로 검산했습니다.</p><p>같은 장비로 적의 HP가 늘어난 만큼 토벌당 보상은 그대로여도 시간당 토벌 EXP는 낮아질 수 있습니다. 이번 패치는 HP와 심사 체력만 변경하며 별도의 성장경제 변경은 포함하지 않습니다. 화면의 거리는 예상 교전 거리이며 실제 야외 GPS 체감 검증을 대신하지 않습니다.</p></details></main>
<script id="data" type="application/json">DATA</script><script id="fulltext" type="application/json">TEXT</script><script>
const d=JSON.parse(document.querySelector('#data').textContent),all=JSON.parse(document.querySelector('#fulltext').textContent),el=id=>document.getElementById(id),fmt=n=>Number(n).toLocaleString('ko-KR'),esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
el('level').innerHTML=d.levels.map(n=>`<option ${n===30?'selected':''}>${n}</option>`).join('');
let current='';function render(){const level=+el('level').value,metric=el('metric').value,q=el('search').value.trim(),targets=d.targets.filter(t=>t.name.includes(q)),rows=d.rows.filter(r=>r.level===level),get=(id,g)=>rows.find(r=>r.target===id&&r.gear===g),unit={meters:'m',hits:'회',damage:'피해'}[metric];el('head').innerHTML='<tr><th>몬스터·보스</th><th>이전 → 새 HP</th><th>방어</th>'+d.equipment.map(g=>'<th>'+esc(g.name)+'</th>').join('')+'</tr>';el('body').innerHTML=targets.map(t=>'<tr><td>'+esc(t.name)+'<small>'+esc(t.kind)+'</small></td><td>'+fmt(t.oldHP)+' → '+fmt(t.hp)+'</td><td>'+t.defense+'</td>'+d.equipment.map(g=>{let r=get(t.id,g.name);return '<td title="ATK '+r.attack.toFixed(4)+' / 1회 '+r.damage+'피해 / '+r.hits+'회" class="'+(g.name==='철갑'?'final':'')+'">'+fmt(r[metric])+'</td>'}).join('')+'</tr>').join('');el('gear').innerHTML=d.equipment.map(g=>'<div><b>'+esc(g.name)+' · ATK '+get(d.targets[0].id,g.name).attack.toFixed(4)+'</b><br>'+esc(g.names.join(' / ')||'무장 없음')+'</div>').join('');current='Lv.'+level+' · '+unit+' · 새 공략 / 유효 교전 기준\n몬스터 | HP | '+d.equipment.map(g=>g.name).join(' | ')+'\n'+targets.map(t=>t.name+' | '+t.hp+' | '+d.equipment.map(g=>fmt(get(t.id,g.name)[metric])).join(' | ')).join('\n')}
async function copy(text){try{if(navigator.clipboard)await navigator.clipboard.writeText(text);else throw Error();el('status').textContent='복사했습니다.'}catch{const t=document.createElement('textarea');t.value=text;document.body.append(t);t.select();let ok=document.execCommand('copy');t.remove();el('status').textContent=ok?'복사했습니다.':'텍스트 저장 버튼을 이용해주세요.'}}
['level','metric','search'].forEach(id=>el(id).addEventListener(id==='search'?'input':'change',render));el('copy').onclick=()=>copy(current);el('copyAll').onclick=()=>copy(all);render();
</script></html>'''
page = page.replace('NOTES', html.escape(notes)).replace('DATA', json.dumps(data, ensure_ascii=False).replace('<', '\\u003c')).replace('TEXT', json.dumps('\n'.join(lines), ensure_ascii=False).replace('<', '\\u003c'))
(folder / 'index.html').write_text(page, encoding='utf-8')
print('전체 HP·장비 거리표와 복사 가능한 검토 화면 생성 완료')
