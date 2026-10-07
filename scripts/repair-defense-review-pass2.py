"""Second review: retain 141 approvals; repair only the ten marked clips.

Review-only output. New wording is carried as an overlay until media approval.
"""
import argparse
import hashlib
import json
import shutil
import time
from pathlib import Path
import numpy as np
import soundfile as sf
import torch
from qwen_tts import Qwen3TTSModel

p=argparse.ArgumentParser()
p.add_argument('--review',type=Path,required=True)
p.add_argument('--first-batch',type=Path,required=True)
p.add_argument('--review-page',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--model',required=True)
p.add_argument('--reference',type=Path,required=True)
p.add_argument('--reference-manifest',type=Path,required=True)
a=p.parse_args()
out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
for folder in ['baseline','before','after','segments']:(out/folder).mkdir(exist_ok=True)
feedback=json.loads(a.review.read_text(encoding='utf-8-sig'))
rows={e['key']:e for e in feedback['entries']}
assert len(rows)==len(feedback['entries'])==151
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for key,e in rows.items():
    src=a.review_page/'audio'/f'{key}.wav';target=out/'baseline'/src.name
    if not target.exists():
        assert sha(src)==e['sha256'],key
        shutil.copy2(src,target)
    assert sha(target)==e['sha256'],key
(out/'review-original.json').write_text(json.dumps(feedback,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
issues=[e for e in rows.values() if e['status']!='ok']
assert len(issues)==10 and sum(e['status']=='ok' for e in rows.values())==141
for e in issues:shutil.copy2(out/'baseline'/f"{e['key']}.wav",out/'before'/f"{e['key']}.wav")
RATE=24000
def load(path):
    audio,rate=sf.read(path,dtype='float32');assert rate==RATE and audio.ndim==1
    return audio
def old(key,i):return load(a.first_batch/'segments'/f'{key}-{i}-0.wav')
def stitch(parts):
    # Keep entire existing sentence PCM; only the inter-sentence silence is inserted.
    return np.concatenate([x for i,part in enumerate(parts) for x in ([np.zeros(4560,dtype='float32'),part] if i else [part])])
def cut_noise(x,end):
    x=x[:int(end*RATE)].copy();x[-120:]*=np.linspace(1,0,120);return x

reference=json.loads(a.reference_manifest.read_text(encoding='utf-8'))
assert sha(a.reference)==reference['sha256']
ref_audio=load(a.reference)
model=None
def synth(key,index,text,anchor=None,anchor_text=None):
    global model
    path=out/'segments'/f'{key}-{index}.wav'
    if path.exists():return load(path)
    if model is None:
        torch.set_num_threads(4)
        model=Qwen3TTSModel.from_pretrained(a.model,device_map='cuda:0',dtype=torch.bfloat16,attn_implementation='sdpa')
    if anchor is not None:
        ref=stitch([ref_audio,anchor]);rtext=reference['text']+' '+anchor_text
    else:ref=ref_audio;rtext=reference['text']
    prompt=model.create_voice_clone_prompt(ref_audio=(ref,RATE),ref_text=rtext,x_vector_only_mode=False)
    seed=int(hashlib.sha256(f'defense-review-pass2:{key}:{index}'.encode()).hexdigest()[:8],16)
    torch.manual_seed(seed)
    waves,rate=model.generate_voice_clone(text=text,language='Korean',voice_clone_prompt=prompt,
        non_streaming_mode=True,max_new_tokens=600,temperature=.58,subtalker_temperature=.45)
    assert rate==RATE
    x=np.asarray(waves[0],dtype='float32')
    n=120;rms=np.sqrt(np.mean(x[:len(x)//n*n].reshape(-1,n)**2,axis=1))
    # Reject isolated sub-100ms terminal clicks after >=200ms of silence.
    mask=rms>.004;spans=[];start=None
    for i,v in enumerate(np.r_[mask,False]):
        if v and start is None:start=i
        elif not v and start is not None:spans.append((start,i));start=None
    while len(spans)>1 and spans[-1][1]-spans[-1][0]<20 and spans[-1][0]-spans[-2][1]>40:spans.pop()
    assert spans
    x=x[max(0,spans[0][0]*n-1200):min(len(x),spans[-1][1]*n+2160)].copy()
    assert .3<len(x)/RATE<20
    x*=min(.1/max(float(np.sqrt(np.mean(x*x))),.001),.89/max(float(np.max(np.abs(x))),.001))
    x[:120]*=np.linspace(0,1,120);x[-120:]*=np.linspace(1,0,120)
    sf.write(path,x,RATE,subtype='PCM_16')
    return load(path)

manifest={'version':2,'status':'awaiting-user-review','clips':[]}
for e in issues:
    start=time.monotonic();k=e['key'];text=e['text'];segments=[]
    if e['id'] in ['V032','V036','V059']:
        index,end={'V032':(0,2.16),'V036':(1,2.87),'V059':(0,1.76)}[e['id']]
        parts=[old(k,0),old(k,1)];parts[index]=cut_noise(parts[index],end)
        audio=stitch(parts);method='remove-isolated-artifact'
        segments=[{'sentence_index':index,'cut_after_seconds':end,'speech_preserved':True}]
    elif e['id'] in ['V018','V106','V116']:
        index=1;count=3 if e['id']=='V116' else 2
        sentences=e['text'].split('. ');sentences=[s if s.endswith('.') else s+'.' for s in sentences]
        parts=[old(k,i) for i in range(count)]
        parts[index]=synth(k,index,sentences[index],parts[0],sentences[0])
        audio=stitch(parts);method='replace-flagged-sentence'
        segments=[{'sentence_index':index,'text':sentences[index],'anchor':'approved opening sentence + existing operator reference'}]
    elif e['id']=='V100':
        sentence='거창한 건 없고, 치약 하나 사 오려고요.'
        text=e['text'].replace('거창한 건 없고, 치약 사기요.',sentence)
        audio=stitch([old(k,0),synth(k,1,sentence,old(k,0),'내일 할 일을 적었어요.'),old(k,2)])
        method='clarify-wording';segments=[{'sentence_index':1,'text':sentence}]
    elif e['id']=='V060':
        delivery='기념으로 매운 음식을 시켰는데... 매운맛 단계는, 한 걸음 덜 나아갈걸 그랬어요...'
        audio=stitch([old(k,0),synth(k,1,delivery)])
        method='expressive-delivery';segments=[{'sentence_index':1,'spoken_text':delivery,'direction':'매운맛을 뒤늦게 후회하는 머쓱함, 쉼표와 말끝 여운'}]
    elif e['id']=='V080':
        delivery='편한 옷에 안경까지 썼으니... 오늘은 지나쳐도 못 알아보실걸요?'
        text=e['text'].replace('못 알아보실걸요.','못 알아보실걸요?')
        audio=stitch([old(k,0),old(k,1),synth(k,2,delivery)])
        method='expressive-delivery';segments=[{'sentence_index':2,'spoken_text':delivery,'direction':'가볍게 장난치는 의문형 말끝'}]
    elif e['id']=='V120':
        deliveries=['작전 종료예요! 서른 번, 함께 지켜냈네요!',
            '지부 불은 이제 당직팀에 맡겨둘게요. 오늘은 저도 천천히 걸어서 저녁 먹으러 갈래요!',
            '정말, 수고하셨어요!']
        audio=stitch([synth(k,i,s) for i,s in enumerate(deliveries)])
        method='expressive-delivery';segments=[{'spoken_text':s,'direction':'작전 완료의 안도와 밝은 퇴근 인사'} for s in deliveries]
    else:raise ValueError(k)
    path=out/'after'/f'{k}.wav';sf.write(path,audio,RATE,subtype='PCM_16')
    assert .3<len(audio)/RATE<35 and sha(path)!=e['sha256']
    manifest['clips'].append({'key':k,'id':e['id'],'previous_text':e['text'],'text':text,'note':e['note'],
        'previous_status':e['status'],'previous_sha256':e['sha256'],'sha256':sha(path),
        'duration':round(len(audio)/RATE,3),'method':method,'segments':segments,'status':'awaiting-user-review'})
    (out/'repairs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f"{len(manifest['clips'])}/10 {e['id']} {method} {len(audio)/RATE:.2f}s ({time.monotonic()-start:.1f}s)",flush=True)
print('Ten candidates ready. All 141 approvals remain in baseline unchanged.',flush=True)
