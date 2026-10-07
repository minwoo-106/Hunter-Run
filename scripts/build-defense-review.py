"""Offline approval package. No server, release build, upload, or save-file access."""
from pathlib import Path
import argparse, html, json, shutil, zipfile

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--output', type=Path, default=ROOT.parent / 'HunterRun-defense-review')
args = p.parse_args()
out = args.output.resolve(); out.mkdir(parents=True, exist_ok=True)
for name in ['images', 'audio', 'documents']: (out/name).mkdir(exist_ok=True)
catalog = json.loads((ROOT/'Resources/defense-campaign.json').read_text(encoding='utf-8'))
lines = json.loads((ROOT/'Resources/defense-lines.json').read_text(encoding='utf-8'))
voice = json.loads((ROOT/'Resources/defense-voice.json').read_text(encoding='utf-8'))
clips = {x['key']:x for x in voice['clips']}
images = ['OperatorLifeIdle', 'DefenseAnnex']
images += [x['asset'] for x in catalog['illustrations']] + ['DefenseReward30Behind']
for name in images:
    shutil.copy2(ROOT/f'Resources/Assets.xcassets/{name}.imageset/art.png', out/f'images/{name}.png')
for key, text in lines.items():
    if key in clips and clips[key]['text'] == text:
        shutil.copy2(ROOT/f'Resources/DefenseAudio/{key}.wav', out/f'audio/{key}.wav')
reference = ROOT.parent/'voice-consistency-reference/run_start.wav'
shutil.copy2(reference, out/'audio/operator-reference.wav')

ops={'hold':'방어선 유지','repair':'시설 복구','rescue':'구조팀 지원','stabilize':'봉인 안정화'}
moves={'march':'제자리 걷기','step':'좌우 스텝','knee':'무릎 번갈아 올리기','squat':'스쿼트','wallPush':'벽 푸시업','heel':'뒤꿈치 들기','boxing':'가벼운 섀도복싱'}
document=['# 지부 방어 작전 — 회차별 콘텐츠 초안', '', '> 신규 캠페인의 사건 전개가 포함됩니다. 기존 메인 스토리의 정체와 결말은 포함하지 않습니다.', '', '| 회차 | 막 | 제목 | 작전 | 일러스트 |', '|---|---|---|---|---|']
for e in catalog['episodes']:
    document.append(f"| {e['number']} | {e['act']} | {e['title']} | {ops[e['operation']]} | {'있음' if e['reward'] else '—'} |")
for e in catalog['episodes']:
    document += ['', f"## {e['number']:02} · {e['title']}", '', f"{catalog['acts'][e['act']-1]} / {ops[e['operation']]}", '', f"**준비 중 브리핑**  \n{e['briefing']}", '', f"**첫 재정비**  \n{e['intermissions'][0]}", '', f"**둘째 재정비**  \n{e['intermissions'][1]}", '', f"**정리 중 후일담**  \n{e['outro']}", '']
    for i in range(3): document.append(f"- 교전 {i+1}: " + ' → '.join(moves[m] for m in e['exercises'][5*i:5*i+5]))
docpath=ROOT/'docs/indoor-defense/campaign-content.md'
docpath.write_text('\n'.join(document)+'\n', encoding='utf-8')
for name in ['master-design.md', 'campaign-content.md', 'verification.md']:
    src=ROOT/'docs/indoor-defense'/name
    if src.exists():
        shutil.copy2(src, out/'documents'/name)
        # A plain readable document view also works on PCs without a Markdown app.
        (out/'documents'/name.replace('.md','.html')).write_text('<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Hunter Run 설계 문서</title><style>body{background:#101b23;color:#e2e9e8;font:16px/1.8 system-ui;margin:32px auto;max-width:960px;padding:20px}pre{white-space:pre-wrap;font:inherit}</style><a href="../index.html" style="color:#55d9d0">검토실로</a><pre>'+html.escape(src.read_text(encoding='utf-8'))+'</pre></html>', encoding='utf-8')

data={'catalog':catalog,'lines':lines,'ready':[k for k,t in lines.items() if k in clips and clips[k]['text']==t]}
page=r'''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Hunter Run · 지켜낸 일상 검토실</title>
<style>
:root{color-scheme:dark;--ink:#09131a;--panel:#12232b;--muted:#9eafba;--teal:#55d9d0;--gold:#d5b778}*{box-sizing:border-box}body{margin:0;background:var(--ink);color:#edf3f1;font:16px/1.65 system-ui,-apple-system,sans-serif}header{padding:52px 6vw 34px;border-bottom:1px solid #284049;background:radial-gradient(ellipse at top right,#204d54,transparent 65%)}h1{font-size:clamp(28px,5vw,52px);line-height:1.25;margin:12px 0}h2{font-size:26px;margin:0 0 12px}h3{margin:0 0 8px}p{margin:8px 0}small,.muted{color:var(--muted)}.eyebrow{color:var(--teal);letter-spacing:.18em;font-size:12px}.tag{display:inline-block;border:1px solid #41626b;padding:4px 12px;border-radius:20px;font-size:12px;margin:4px 6px 4px 0}nav{position:sticky;top:0;background:#09131af2;padding:12px 6vw;z-index:4;display:flex;gap:18px;flex-wrap:wrap;border-bottom:1px solid #284049}a{color:var(--teal);text-decoration:none}main{max-width:1180px;margin:auto;padding:30px 24px}section{scroll-margin-top:90px;margin-bottom:54px}.card{background:var(--panel);padding:22px;border:1px solid #2a414b;border-radius:16px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:20px}.art{padding:0;overflow:hidden}.art img{display:block;width:100%;aspect-ratio:2/3;object-fit:cover;cursor:zoom-in}.art .text{padding:18px}.compare{display:grid;grid-template-columns:1fr 1fr;gap:20px;max-width:750px}.compare img{width:100%;border-radius:14px}button,select,input{font:inherit;border-radius:9px;padding:10px 14px;border:1px solid #42606c;background:#1b323b;color:#edf3f1}button{cursor:pointer}button:hover{border-color:var(--teal)}button:focus-visible,a:focus-visible,summary:focus-visible{outline:3px solid var(--teal)}audio{width:100%;margin:12px 0}.filters{display:flex;gap:12px;flex-wrap:wrap;margin:18px 0}.filters input{flex:1;min-width:190px}.voice{margin:12px 0;padding:18px}.voice code{color:var(--teal);font-size:13px}.voice p{font-size:18px}.status{color:var(--gold)}details{margin-top:20px}summary{cursor:pointer;color:var(--gold);padding:12px 0}.actmap{display:grid;grid-template-columns:repeat(5,1fr);gap:8px}.node{text-align:center;background:#18353d;border-radius:8px;padding:12px 4px;color:var(--teal)}.note{border-left:3px solid var(--gold);padding:12px 18px;background:#242923;margin-top:18px}dialog{padding:0;background:#081118;border:1px solid #405c68;max-width:95vw;max-height:95vh}dialog::backdrop{background:#000d}dialog img{display:block;max-height:85vh;max-width:90vw;object-fit:contain}dialog button{display:block;margin:8px auto}.hidden{display:none}@media(max-width:540px){main{padding:24px 16px}.compare{gap:8px}nav{font-size:14px;gap:12px}.card{padding:16px}.art{padding:0}h2{font-size:23px}}@media(prefers-reduced-motion:no-preference){html{scroll-behavior:smooth}}
</style></head><body>
<header><div class="eyebrow">HUNTER RUN / CONTENT REVIEW</div><h1>지켜낸 일상,<br>서른 번의 작전.</h1><p>지부 방어 작전 — 음성·일러스트 검토실</p><span class="tag">출시 전 검토본</span><span class="tag">IPA 제작 전</span><span class="tag">서버 연결 불필요</span><p class="muted">“일러스트 I15 표정 수정”, “V023 끝부분 목소리 변경”처럼 번호로 알려주세요.</p></header>
<nav><a href="#identity">얼굴 기준</a><a href="#art">일러스트</a><a href="#voice">음성</a><a href="#structure">캠페인 구성</a><a href="#docs">설계 문서</a></nav>
<main>
<section id="identity"><h2>지금 게임 속 얼굴이 기준입니다</h2><p class="muted">왼쪽: 현재 홈 원본 · 오른쪽: 1회차 생활 일러스트 초안. 이미지를 누르면 크게 볼 수 있어요.</p><div class="compare"><img src="images/OperatorLifeIdle.png" alt="현재 오퍼레이터 얼굴 기준" loading="lazy"><img src="images/DefenseReward01.png" alt="I01 따뜻한 봉투" loading="lazy"></div></section>
<section id="art"><h2>일러스트 8장 + 전용 배경 1장</h2><p class="muted">얼굴의 일관성, 손·소품, 생활 장면의 자연스러움을 봐주세요. 아직 최종 승인 전입니다.</p><div id="firstArt" class="grid"></div><details><summary>후반 생활 일러스트 5장 보기 · 신규 캠페인 보상 미리보기</summary><div id="laterArt" class="grid"></div></details><details><summary>방어 구역 배경 B01 보기</summary><div class="grid" id="background"></div></details></section>
<section id="voice"><h2>오퍼레이터 안내 음성</h2><div class="card"><h3>비교 기준 · 기존 승인 목소리</h3><p>“좋아요! 헌터 활동을 시작해요. 편안한 페이스로 함께 가요!”</p><audio controls preload="none" src="audio/operator-reference.wav"></audio><small>실제 음성의 톤과 억양은 직접 들으신 판단을 우선합니다. 재생하면 다른 음성은 자동으로 멈춰요.</small></div><div class="filters"><select id="filter" aria-label="음성 범위"><option value="1">1회차</option><option value="exercise">운동 안내</option><option value="shared">공통 안내</option></select><input id="search" placeholder="번호 또는 대사 검색" aria-label="음성 검색"></div><p id="voiceCount" class="muted"></p><div id="voices"></div></section>
<section id="structure"><h2>회차는 이야기, 강도는 오늘의 선택</h2><div class="grid"><div class="card"><h3>24분</h3><p>준비 4 → 교전 5 → 재정비 1 → 교전 5 → 재정비 1 → 교전 5 → 정리 3분</p><small>교전 5분에도 회복·동작 준비 시간이 포함돼요.</small></div><div class="card"><h3>가볍게 / 기본 / 조금 더 도전</h3><p>매분 준비·회복 40/30/20초 + 동작 20/30/40초.</p><small>어떤 강도든 같은 이야기와 그림을 받습니다. 다음 날까지 기다릴 필요도, 연속 출석도 없어요.</small></div></div><div class="card" style="margin-top:20px"><div class="actmap" id="map"></div><p class="muted">7개 주요 지점: 1 · 5 · 10 · 15 · 20 · 25 · 30회차</p></div><div class="note">이 버전은 따라 하는 운동 안내입니다. 실제 자세·횟수·칼로리를 검증했다고 표시하지 않습니다. 앱이 배경으로 가거나 화면을 잠그면 일시정지합니다.</div></section>
<section id="docs"><h2>설계와 확인 범위</h2><div class="card"><p><a href="documents/master-design.html">통합 설계서 13개 항목 열기</a></p><p><a href="documents/verification.html">검증 결과와 남은 확인 항목</a></p><details><summary>신규 캠페인 전체 대사 · 스포일러 포함</summary><a href="documents/campaign-content.html">30회차 콘텐츠 문서 열기</a></details><p class="status">현재 화면은 검토실입니다. iPhone 앱 실행 화면이나 배포 파일이 아닙니다.</p></div></section>
</main><dialog id="lightbox"><img alt="일러스트 확대"><button>닫기</button></dialog>
<script>const DATA=__DATA__;
const $=s=>document.querySelector(s);
function card(id,title,caption,asset){const wrap=document.createElement('article');wrap.className='card art';const img=document.createElement('img');img.src='images/'+asset+'.png';img.alt=id+' '+title;img.loading='lazy';const text=document.createElement('div');text.className='text';const h=document.createElement('h3');h.textContent=id+' · '+title;const p=document.createElement('p');p.className='muted';p.textContent=caption;text.append(h,p);wrap.append(img,text);return wrap;}
for(const a of DATA.catalog.illustrations){$('#'+(a.episode<=10?'firstArt':'laterArt')).append(card('I'+String(a.episode).padStart(2,'0'),a.title,a.caption,a.asset));}
$('#laterArt').append(card('I30-B','조금 다른 마지막 작전','주문은 멋있게. 먹는 건 생각보다 어렵게.','DefenseReward30Behind'));
$('#background').append(card('B01','격리된 지부 통로','현대 협회 장치와 지하 게이트 시설을 잇는 방어 구역.','DefenseAnnex'));
for(let n=2;n<=30;n++){const o=document.createElement('option');o.value=String(n);o.textContent=n+'회차'+([5,10,15,20,25,30].includes(n)?' · 주요 이야기':'');$('#filter').append(o)}
const all=document.createElement('option');all.value='all';all.textContent='전체 151개';$('#filter').append(all);
const keys=Object.keys(DATA.lines);function renderVoices(){const q=$('#search').value.trim().toLowerCase(),f=$('#filter').value;$('#voices').replaceChildren();let count=0;keys.forEach((key,i)=>{const id='V'+String(i+1).padStart(3,'0'),text=DATA.lines[key];const matches=f==='all'||f==='exercise'&&key.startsWith('defense_move_')||f==='shared'&&!/^defense_\d\d_|^defense_move_/.test(key)||/^\d+$/.test(f)&&key.startsWith('defense_'+f.padStart(2,'0')+'_');if((!q&&!matches)||(q&&!(id+' '+key+' '+text).toLowerCase().includes(q)))return;count++;const a=document.createElement('article');a.className='card voice';const code=document.createElement('code');code.textContent=id+' · '+key;const p=document.createElement('p');p.textContent=text;a.append(code,p);if(DATA.ready.includes(key)){const audio=document.createElement('audio');audio.controls=true;audio.preload='none';audio.src='audio/'+key+'.wav';a.append(audio)}else{const status=document.createElement('small');status.textContent='제작 중 — 아직 재생 파일 없음';a.append(status)}$('#voices').append(a)});$('#voiceCount').textContent=count+'개 표시 · '+DATA.ready.length+'/151개 음성 파일 준비';}
$('#filter').onchange=renderVoices;$('#search').oninput=renderVoices;renderVoices();document.addEventListener('play',e=>{if(e.target.tagName==='AUDIO')for(const a of document.querySelectorAll('audio'))if(a!==e.target)a.pause()},true);
for(let i=1;i<=30;i++){const n=document.createElement('div');n.className='node';n.textContent=i+([1,5,10,15,20,25,30].includes(i)?' ✧':'');$('#map').append(n)}
document.addEventListener('click',e=>{if(e.target.tagName==='IMG'&&!e.target.closest('dialog')){const d=$('#lightbox');d.querySelector('img').src=e.target.src;d.querySelector('img').alt=e.target.alt;d.showModal()}});$('#lightbox button').onclick=()=>$('#lightbox').close();
</script></body></html>'''
page=page.replace('__DATA__',json.dumps(data,ensure_ascii=False).replace('</','<\/'))
(out/'index.html').write_text(page,encoding='utf-8')
(out/'읽어주세요.txt').write_text('Hunter Run 신규 캠페인 검토본\n압축을 모두 푼 뒤 index.html을 브라우저로 여세요.\n인터넷이나 로컬 서버는 필요하지 않습니다.\n이 파일은 설치 파일이 아닙니다. 음성·그림 승인 후 iPhone 검증과 IPA 제작을 진행합니다.\n',encoding='utf-8')
archive=out.with_suffix('.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for file in out.rglob('*'):
        if file.is_file():z.write(file,file.relative_to(out.parent))
print(f'{out / "index.html"}\n{archive}\n{len(data["ready"])} / {len(lines)} voice clips included')
