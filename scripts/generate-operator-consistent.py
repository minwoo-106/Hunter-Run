"""Compare a shared approved reference with sentence-level regeneration."""
import argparse,hashlib,json,re,time
from pathlib import Path
import numpy as np
import soundfile as sf
import torch
from qwen_tts import Qwen3TTSModel
p=argparse.ArgumentParser()
p.add_argument('--model',required=True);p.add_argument('--output',required=True)
p.add_argument('--reference',required=True);p.add_argument('--reference-manifest',required=True)
p.add_argument('--keys',nargs='+',required=True);p.add_argument('--compare',action='store_true')
p.add_argument('--whole',action='store_true');p.add_argument('--seed-tag',default='hunter-consistent-v1:')
a=p.parse_args();root=Path(__file__).resolve().parents[1];out=Path(a.output);out.mkdir(parents=True,exist_ok=True)
ref=Path(a.reference);rec=json.loads(Path(a.reference_manifest).read_text(encoding='utf-8'))
assert hashlib.sha256(ref.read_bytes()).hexdigest()==rec['sha256']
lines=json.loads((root/'Resources/audio-lines.json').read_text(encoding='utf-8'))
torch.set_num_threads(4)
model=Qwen3TTSModel.from_pretrained(a.model,device_map='cuda:0',dtype=torch.bfloat16,attn_implementation='sdpa')
prompt=model.create_voice_clone_prompt(ref_audio=str(ref),ref_text=rec['text'],x_vector_only_mode=False)
manifest=dict(schema=1,voice='adult-warm-operator',model='Qwen/Qwen3-TTS-12Hz-1.7B-Base',revision='fd4b254389122332181a7c3db7f27e918eec64e3',reference_sha256=rec['sha256'],seed_tag=a.seed_tag,clips=[])
for key in a.keys:
 text=lines[key]
 for segmented in ([False,True] if a.compare else [not a.whole]):
  label=key+('_B' if segmented else '_A') if a.compare else key
  chunks=re.findall(r'[^.!?]+[.!?]?',text) if segmented else [text]
  parts=[];seeds=[];print('Generating '+label,flush=True)
  for idx,chunk in enumerate(chunks):
   seed=int(hashlib.sha256((a.seed_tag+key+':'+str(idx)).encode()).hexdigest()[:8],16)
   seeds.append(seed);torch.manual_seed(seed);np.random.seed(seed)
   wavs,sr=model.generate_voice_clone(text=chunk.strip(),language='Korean',voice_clone_prompt=prompt,non_streaming_mode=True,max_new_tokens=450,temperature=.55)
   audio=np.asarray(wavs[0],dtype=np.float32);active=np.flatnonzero(np.abs(audio)>.002)
   assert len(active),label
   audio=audio[max(0,active[0]-int(sr*.08)):min(len(audio),active[-1]+int(sr*.12))]
   parts.append(audio)
   if idx+1<len(chunks):parts.append(np.zeros(int(sr*.1),dtype=np.float32))
  audio=np.concatenate(parts);duration=len(audio)/sr;assert .3<duration<15,(label,duration)
  rms=float(np.sqrt(np.mean(audio**2)));peak=float(np.max(np.abs(audio)));assert rms>.001 and peak>.01
  audio*=min(.1/rms,.89/peak)
  f=out/(label+'.wav');sf.write(f,audio,sr,subtype='PCM_16')
  manifest['clips'].append(dict(key=key,file=f.name,text=text,seed=seeds[0],seeds=seeds,segmented=segmented,reference_sha256=rec['sha256'],sample_rate=sr,duration=round(duration,3),sha256=hashlib.sha256(f.read_bytes()).hexdigest()))
  (out/'operator-voice.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
  print(label+': '+str(round(duration,2))+'s',flush=True)
