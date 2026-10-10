"""승인된 합성 오퍼레이터 기준으로 신규 운동 안내만 검토 폴더에 출력한다."""
import argparse, hashlib, json, time
from pathlib import Path
import numpy as np
import soundfile as sf
import torch
from qwen_tts import Qwen3TTSModel

p=argparse.ArgumentParser()
p.add_argument('--model',type=Path,required=True); p.add_argument('--reference',type=Path,required=True)
p.add_argument('--reference-manifest',type=Path,required=True); p.add_argument('--output',type=Path,required=True)
p.add_argument('--keys',nargs='*'); a=p.parse_args()
root=Path(__file__).resolve().parents[1]; out=a.output.resolve(); (out/'audio').mkdir(parents=True,exist_ok=True)
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
ref=json.loads(a.reference_manifest.read_text(encoding='utf-8')); assert sha(a.reference)==ref['sha256']
lines=json.loads((root/'Resources/defense-workout-lines.json').read_text(encoding='utf-8'))
mp=out/'voice-review.json'
manifest=json.loads(mp.read_text(encoding='utf-8')) if mp.exists() else dict(version=2,status='awaiting-user-review',reference_sha256=ref['sha256'],clips=[])
existing={c['key']:c for c in manifest['clips']}
torch.set_num_threads(4)
model=Qwen3TTSModel.from_pretrained(str(a.model),device_map='cuda:0',dtype=torch.bfloat16,attn_implementation='sdpa')
prompt=model.create_voice_clone_prompt(ref_audio=str(a.reference),ref_text=ref['text'],x_vector_only_mode=False)
for key,text in lines.items():
    if a.keys and key not in a.keys: continue
    target=out/'audio'/f'{key}.wav'
    if key in existing and target.exists() and existing[key]['text']==text and existing[key]['sha256']==sha(target): continue
    started=time.monotonic(); candidates=[]
    # 짧은 준비 구간에 들어가지 않거나 무음인 음성은 다시 생성한다.
    for take in range(3):
        seed=int(hashlib.sha256(f'defense-workout-v2:{key}:{take}'.encode()).hexdigest()[:8],16)
        torch.manual_seed(seed)
        waves,rate=model.generate_voice_clone(text=text,language='Korean',voice_clone_prompt=prompt,
            non_streaming_mode=True,max_new_tokens=500,temperature=.55,subtalker_temperature=.45)
        assert rate==24000
        x=np.asarray(waves[0],dtype=np.float32); n=len(x)//240
        active=np.flatnonzero(np.sqrt(np.mean(x[:n*240].reshape(-1,240)**2,axis=1))>.004)
        if not len(active): continue
        x=x[max(0,int(active[0]*240-1200)):min(len(x),int((active[-1]+1)*240+2400))].copy()
        x[:120]*=np.linspace(0,1,120); x[-120:]*=np.linspace(1,0,120)
        seconds=len(x)/rate
        limit=7.2 if '_move_' in key else 2.8 if '_seconds_' in key else 20
        if not .3<seconds<limit: continue
        rms=float(np.sqrt(np.mean(x*x))); peak=float(np.max(np.abs(x)))
        x*=min(.1/max(rms,.001),.89/max(peak,.001))
        sf.write(target,x,rate,subtype='PCM_16')
        existing[key]=dict(key=key,text=text,file=target.name,duration=round(seconds,3),sha256=sha(target),seed=seed)
        break
    else: raise ValueError(f'준비 시간에 맞는 음성 재검토 필요: {key}')
    manifest['clips']=list(existing.values()); mp.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'{key}: {seconds:.2f}초 / 생성 {time.monotonic()-started:.1f}초',flush=True)
