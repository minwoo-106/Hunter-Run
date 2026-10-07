"""Render the campaign with our existing synthetic operator reference; resumable, local-only."""
import argparse, hashlib, json, time
from pathlib import Path
import numpy as np
import soundfile as sf
import torch
from qwen_tts import Qwen3TTSModel

p=argparse.ArgumentParser()
p.add_argument('--model',required=True); p.add_argument('--reference',required=True)
p.add_argument('--reference-manifest',required=True); p.add_argument('--keys',nargs='*')
a=p.parse_args(); root=Path(__file__).resolve().parents[1]
out=root/'Resources/DefenseAudio'; out.mkdir(exist_ok=True)
lines=json.loads((root/'Resources/defense-lines.json').read_text(encoding='utf-8'))
ref=json.loads(Path(a.reference_manifest).read_text(encoding='utf-8'))
assert hashlib.sha256(Path(a.reference).read_bytes()).hexdigest()==ref['sha256']
manifest_path=root/'Resources/defense-voice.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else dict(version=1,reference_sha256=ref['sha256'],clips=[])
existing={x['key']:x for x in manifest['clips']}
torch.set_num_threads(4)
print('Loading existing operator voice model',flush=True)
model=Qwen3TTSModel.from_pretrained(a.model,device_map='cuda:0',dtype=torch.bfloat16,attn_implementation='sdpa')
prompt=model.create_voice_clone_prompt(ref_audio=a.reference,ref_text=ref['text'],x_vector_only_mode=False)
for key,text in lines.items():
    if a.keys and key not in a.keys: continue
    path=out/(key+'.wav')
    if key in existing and existing[key]['text']==text and path.exists() and hashlib.sha256(path.read_bytes()).hexdigest()==existing[key]['sha256']: continue
    started=time.monotonic(); torch.manual_seed(int(hashlib.sha256(('defense-v1:'+key).encode()).hexdigest()[:8],16))
    waves,rate=model.generate_voice_clone(text=text,language='Korean',voice_clone_prompt=prompt,non_streaming_mode=True,max_new_tokens=900,temperature=.55)
    audio=np.asarray(waves[0],dtype=np.float32); active=np.flatnonzero(np.abs(audio)>.002)
    if not len(active): raise ValueError('silent '+key)
    audio=audio[max(0,active[0]-int(rate*.08)):min(len(audio),active[-1]+int(rate*.15))]
    seconds=len(audio)/rate
    if not .3<seconds<35: raise ValueError((key,seconds))
    rms=float(np.sqrt(np.mean(audio**2))); peak=float(np.max(np.abs(audio)))
    audio*=min(.1/max(rms,.001),.89/max(peak,.001))
    sf.write(path,audio,rate,subtype='PCM_16')
    existing[key]=dict(key=key,text=text,file=path.name,duration=round(seconds,3),sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    manifest['clips']=list(existing.values())
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'{key}: {seconds:.2f}s generated in {time.monotonic()-started:.1f}s',flush=True)
