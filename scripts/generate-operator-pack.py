"""Render Korean activity cues from our own user-preferred synthetic voice reference."""
import argparse, hashlib, json, time
from pathlib import Path
import numpy as np
import soundfile as sf
import torch
from qwen_tts import Qwen3TTSModel

p=argparse.ArgumentParser()
p.add_argument('--model', required=True)
p.add_argument('--output', required=True)
p.add_argument('--reference', required=True, help='Our own synthetic reference WAV')
p.add_argument('--reference-manifest', required=True)
p.add_argument('--seed-tag', default='hunter-operator-v2:')
p.add_argument('--keys', nargs='*', help='Optional small calibration subset')
a=p.parse_args()
root=Path(__file__).resolve().parents[1]
out=Path(a.output); out.mkdir(parents=True, exist_ok=True)
ref=Path(a.reference)
ref_record=json.loads(Path(a.reference_manifest).read_text(encoding='utf-8'))
if 'clips' in ref_record: ref_record=ref_record['clips'][0]
assert hashlib.sha256(ref.read_bytes()).hexdigest()==ref_record['sha256']
lines=json.loads((root/'Resources/audio-lines.json').read_text(encoding='utf-8'))
if a.keys: lines={key:lines[key] for key in a.keys}
torch.set_num_threads(4)
print('Loading Base model',flush=True)
model=Qwen3TTSModel.from_pretrained(a.model, device_map='cuda:0', dtype=torch.bfloat16, attn_implementation='sdpa')
prompt=model.create_voice_clone_prompt(ref_audio=str(ref),ref_text=ref_record['text'],x_vector_only_mode=False)
manifest=dict(schema=1,voice='adult-warm-operator',model='Qwen/Qwen3-TTS-12Hz-1.7B-Base',revision='fd4b254389122332181a7c3db7f27e918eec64e3',reference_sha256=ref_record['sha256'],seed_tag=a.seed_tag,clips=[])
for key,text in lines.items():
    seed=int(hashlib.sha256((a.seed_tag+key).encode()).hexdigest()[:8],16)
    torch.manual_seed(seed); np.random.seed(seed)
    print('Generating '+key,flush=True); start=time.time()
    wavs,sr=model.generate_voice_clone(text=text,language='Korean',voice_clone_prompt=prompt,non_streaming_mode=True,max_new_tokens=450,temperature=.55)
    audio=np.asarray(wavs[0],dtype=np.float32)
    active=np.flatnonzero(np.abs(audio)>.002)
    assert len(active),key+' silence'
    audio=audio[max(0,active[0]-int(sr*.1)):min(len(audio),active[-1]+int(sr*.18))]
    duration=len(audio)/sr
    assert .3<duration<15,(key,duration)
    rms=float(np.sqrt(np.mean(audio**2))); peak=float(np.max(np.abs(audio)))
    assert rms>.001 and peak>.01,key
    audio*=min(.1/rms,.89/peak)
    file=out/(key+'.wav'); sf.write(file,audio,sr,subtype='PCM_16')
    manifest['clips'].append(dict(key=key,file=file.name,text=text,seed=seed,sample_rate=sr,duration=round(duration,3),sha256=hashlib.sha256(file.read_bytes()).hexdigest()))
    (out/'operator-voice.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'{key}: {duration:.2f}s, generated in {time.time()-start:.1f}s',flush=True)
