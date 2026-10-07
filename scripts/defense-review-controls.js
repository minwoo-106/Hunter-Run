// Offline, user-owned review marks. Replacing an audio file invalidates its old verdict.
const reviewStorageKey = 'hunter-defense-voice-review-v1';
const reviewStates = {pending:'아직 확인 전', ok:'좋아요', voice:'목소리 다름', delivery:'억양 / 발음 수정'};
let reviews = {}, storageAvailable = true;
try {
    const saved = JSON.parse(localStorage.getItem(reviewStorageKey) || '{}');
    if (saved && typeof saved === 'object' && !Array.isArray(saved)) reviews = saved;
} catch (_) { storageAvailable = false; }
function verdict(key) {
    const r = reviews[key];
    return r && r.sha256 === DATA.hashes[key] && Object.hasOwn(reviewStates,r.status)
        ? {status:r.status, note:typeof r.note === 'string' ? r.note : ''}
        : {status:'pending', note:''};
}
const issue = r => r.status === 'voice' || r.status === 'delivery' || (r.note.trim() && r.status !== 'ok');
const panel = document.createElement('div'); panel.className = 'card';
panel.innerHTML = '<h3>듣고 바로 체크해주세요</h3><p>각 음성 아래에서 상태를 고르고, 달라지는 부분을 메모해주세요. 예: “마지막 문장부터 다른 목소리”, “03초 이후 발음 어색함”.</p><p id="reviewStats" aria-live="polite"></p><div class="filters"><label>확인 상태 <select id="reviewFilter"><option value="all">전체 상태</option><option value="pending">아직 확인 전</option><option value="issues">수정할 음성만</option><option value="ok">좋아요</option></select></label><button id="exportReview" type="button">체크 목록 다운로드</button><button id="showReview" type="button">복사할 목록 보기</button></div><p id="saveNotice" class="muted"></p><textarea id="reviewText" class="hidden" rows="7" readonly aria-label="복사할 수정 목록" style="width:100%;font:inherit;background:#09131a;color:#edf3f1;padding:12px"></textarea>';
$('#voiceCount').before(panel);
$('#reviewFilter').onchange = renderVoices;
function reviewRows() {
    return keys.flatMap((key,i) => {
        const r = verdict(key);
        return r.status !== 'pending' || r.note.trim() ? [{id:'V'+String(i+1).padStart(3,'0'),key,text:DATA.lines[key],sha256:DATA.hashes[key],...r}] : [];
    });
}
function updateReviewStats() {
    const rows = keys.map(verdict);
    $('#reviewStats').textContent = '확인 '+rows.filter(r=>r.status!=='pending').length+'/151 · 좋아요 '+rows.filter(r=>r.status==='ok').length+' · 수정 요청 '+rows.filter(issue).length;
    $('#saveNotice').textContent = storageAvailable
        ? '체크는 현재 브라우저에 저장돼요. 다른 PC와 자동 공유되지는 않습니다. 다 확인하면 목록을 다운로드해 이 대화에 첨부하거나 복사해 보내주세요.'
        : '이 브라우저에서는 저장할 수 없어 창을 닫으면 체크가 사라질 수 있어요. 체크 목록을 다운로드하거나 복사해 보관해주세요.';
    if (!$('#reviewText').classList.contains('hidden')) fillReviewText();
}
function saveReview(key,status,note) {
    reviews[key] = {status,note,sha256:DATA.hashes[key]};
    try { localStorage.setItem(reviewStorageKey,JSON.stringify(reviews)); storageAvailable = true; }
    catch (_) { storageAvailable = false; }
    updateReviewStats();
}
function fillReviewText() {
    const rows = reviewRows();
    $('#reviewText').value = rows.length ? rows.map(r=>`${r.id} · ${reviewStates[r.status]}\n${r.text}${r.note ? '\n메모: '+r.note : ''}`).join('\n\n') : '아직 체크한 음성이 없습니다.';
}
$('#showReview').onclick = () => { $('#reviewText').classList.remove('hidden'); fillReviewText(); $('#reviewText').focus(); $('#reviewText').select(); };
$('#exportReview').onclick = () => {
    const blob = new Blob([JSON.stringify({version:1,exportedAt:new Date().toISOString(),total:keys.length,entries:reviewRows()},null,2)],{type:'application/json;charset=utf-8'});
    const url = URL.createObjectURL(blob), link = document.createElement('a');
    link.href = url; link.download = 'HunterRun-voice-review.json'; document.body.append(link); link.click(); link.remove();
    setTimeout(()=>URL.revokeObjectURL(url),1000);
};
function renderVoices() {
    const q=$('#search').value.trim().toLowerCase(), f=$('#filter').value, state=$('#reviewFilter').value;
    $('#voices').replaceChildren(); let count=0;
    keys.forEach((key,i)=>{
        const id='V'+String(i+1).padStart(3,'0'), text=DATA.lines[key], r=verdict(key);
        const matches=f==='all'||f==='exercise'&&key.startsWith('defense_move_')||f==='shared'&&!/^defense_\d\d_|^defense_move_/.test(key)||/^\d+$/.test(f)&&key.startsWith('defense_'+f.padStart(2,'0')+'_');
        if ((!q&&!matches)||(q&&!(id+' '+key+' '+text).toLowerCase().includes(q))) return;
        if (state==='issues'&&!issue(r)||state==='pending'&&r.status!=='pending'||state==='ok'&&r.status!=='ok') return;
        count++;
        const a=document.createElement('article'); a.className='card voice'; a.dataset.voiceId=id;
        const code=document.createElement('code');code.textContent=id+' · '+key;
        const p=document.createElement('p');p.textContent=text;a.append(code,p);
        if (DATA.ready.includes(key)) {
            const audio=document.createElement('audio');audio.controls=true;audio.preload='none';audio.src='audio/'+key+'.wav';a.append(audio);
            const compare=document.createElement('button');compare.type='button';compare.textContent='기존 목소리 다시 듣기';
            compare.onclick=()=>{const ref=$('#voice > .card audio');ref.currentTime=0;ref.play().catch(()=>{$('#saveNotice').textContent='상단 비교 기준의 재생 버튼을 눌러주세요.';});};a.append(compare);
        }
        const controls=document.createElement('div');controls.className='filters';
        const select=document.createElement('select');select.setAttribute('aria-label',id+' 확인 상태');
        for(const [value,label] of Object.entries(reviewStates)){const o=document.createElement('option');o.value=value;o.textContent=label;select.append(o);}select.value=r.status;
        const note=document.createElement('input');note.type='text';note.maxLength=1000;note.placeholder='어느 부분이 다른가요? (선택)';note.setAttribute('aria-label',id+' 수정 메모');note.value=r.note;
        select.onchange=()=>{saveReview(key,select.value,note.value);a.style.borderColor=issue(verdict(key))?'#d5b778':'';};
        note.oninput=()=>saveReview(key,select.value,note.value);
        if(issue(r))a.style.borderColor='#d5b778';
        controls.append(select,note);a.append(controls);$('#voices').append(a);
    });
    $('#voiceCount').textContent=count+'개 표시 · '+DATA.ready.length+'/151개 음성 파일 준비';
    if (!count) {const empty=document.createElement('p');empty.textContent='이 범위에 해당하는 음성이 없어요. 음성 범위를 전체로 바꾸거나 확인 상태 필터를 바꿔주세요.';$('#voices').append(empty);}
    updateReviewStats();
}
