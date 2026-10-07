"""Targeted, resumable repair of user-flagged synthetic voices. Never edits approved clips.

Outputs candidates outside app resources; install only after technical validation.
Short sentences share the approved reference. Speaker similarity is a diagnostic,
not a claim of human approval or pronunciation accuracy.
"""
import argparse
import hashlib
import json
import re
import shutil
import time
from pathlib import Path

import numpy as np
import soundfile as sf
import torch
from qwen_tts import Qwen3TTSModel

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--review', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--model', required=True)
p.add_argument('--reference', type=Path, required=True)
p.add_argument('--reference-manifest', type=Path, required=True)
a = p.parse_args()
out = a.output.resolve()
out.mkdir(parents=True, exist_ok=True)
for name in ['before', 'after', 'segments']:
    (out/name).mkdir(exist_ok=True)
feedback = json.loads(a.review.read_text(encoding='utf-8-sig'))
lines = json.loads((ROOT/'Resources/defense-lines.json').read_text(encoding='utf-8'))
assert len(feedback['entries']) == len(lines) == 151
assert len({e['key'] for e in feedback['entries']}) == 151
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
for e in feedback['entries']:
    assert e['key'] in lines and e['text'] == lines[e['key']]
    assert sha(ROOT/'Resources/DefenseAudio'/f"{e['key']}.wav") == e['sha256'], e['key']
(out/'review-original.json').write_text(json.dumps(feedback, ensure_ascii=False, indent=2), encoding='utf-8')
issues = [e for e in feedback['entries'] if e['status'] in ['voice', 'delivery']]
for e in issues:
    backup = out/'before'/f"{e['key']}.wav"
    if not backup.exists():
        shutil.copy2(ROOT/'Resources/DefenseAudio'/backup.name, backup)
    assert sha(backup) == e['sha256']

# Audible sentence boundaries are separated by low-energy pauses at these points.
# Retain complete sentences, not a blind cut at an approximate user timestamp.
prefixes = {
    'defense_02_rest2': (2.95, 1),
    'defense_04_rest2': (2.00, 1),
    'defense_05_brief': (3.20, 1),
    'defense_06_rest1': (2.52, 1),
    'defense_21_outro': (2.32, 1),
    'defense_25_brief': (3.25, 1),
    'defense_30_outro': (6.25, 3),
}
tail_cuts = {'defense_18_rest1': 4.43, 'defense_22_rest2': 4.43}
# Reuse the very same exercise/timing sentences from the user's approved takes.
# (source key, start seconds, end seconds); None means EOF.
splices = {
    'defense_move_step_standard': [('defense_move_step_standard', 0, 3.95), ('defense_move_march_standard', 4.20, None)],
    'defense_move_step_challenge': [('defense_move_step_light', 0, 4.02), ('defense_move_march_challenge', 4.13, None)],
    'defense_move_squat_standard': [('defense_move_squat_light', 0, 3.62), ('defense_move_march_standard', 4.20, None)],
    'defense_move_wallPush_light': [('defense_move_wallPush_light', 0, 4.22), ('defense_move_march_light', 3.97, None)],
    'defense_move_heel_light': [('defense_move_heel_standard', 0, 4.00), ('defense_move_march_light', 3.97, None)],
    'defense_move_boxing_challenge': [('defense_move_boxing_challenge', 0, 5.05), ('defense_move_march_challenge', 4.13, None)],
}
RATE = 24000
def read(key):
    audio, rate = sf.read(ROOT/'Resources/DefenseAudio'/f'{key}.wav', dtype='float32')
    assert rate == RATE and audio.ndim == 1
    return audio

def tidy(audio, lead=.05, tail=.09):
    frame = 240
    n = len(audio)//frame
    rms = np.sqrt(np.mean(audio[:n*frame].reshape(-1, frame)**2, axis=1))
    active = np.flatnonzero(rms > .004)
    assert len(active), 'silent audio'
    lo = max(0, int(active[0]*frame-RATE*lead))
    hi = min(len(audio), int((active[-1]+1)*frame+RATE*tail))
    audio = audio[lo:hi].copy()
    ramp = min(120, len(audio)//4)
    audio[:ramp] *= np.linspace(0, 1, ramp)
    audio[-ramp:] *= np.linspace(1, 0, ramp)
    return audio

def join(parts):
    return np.concatenate([piece for i, part in enumerate(parts)
        for piece in ([np.zeros(int(.19*RATE), dtype='float32'), tidy(part)] if i else [tidy(part)])])

manifest_path = out/'repairs.json'
result = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {'version':1,'status':'awaiting-user-review','clips':[]}
completed = {c['key']:c for c in result['clips']}
model = prompt = ref_embedding = None

def load_model():
    global model, prompt, ref_embedding
    if model is not None:
        return
    reference = json.loads(a.reference_manifest.read_text(encoding='utf-8'))
    assert sha(a.reference) == reference['sha256']
    torch.set_num_threads(4)
    print('Loading approved synthetic operator reference', flush=True)
    model = Qwen3TTSModel.from_pretrained(a.model, device_map='cuda:0', dtype=torch.bfloat16, attn_implementation='sdpa')
    prompt = model.create_voice_clone_prompt(ref_audio=str(a.reference), ref_text=reference['text'], x_vector_only_mode=False)
    ref_embedding = prompt[0].ref_spk_embedding.float().flatten()

def similarity(audio):
    embedding = model.model.extract_speaker_embedding(audio=audio, sr=RATE).float().flatten()
    return float(torch.nn.functional.cosine_similarity(embedding, ref_embedding, dim=0))

def generate(key, index, text):
    load_model()
    candidates = []
    for take in range(2):
        file = out/'segments'/f'{key}-{index}-{take}.wav'
        if file.exists():
            audio, rate = sf.read(file, dtype='float32')
            assert rate == RATE
        else:
            seed = int(hashlib.sha256(f'defense-repair-v2:{key}:{index}:{take}'.encode()).hexdigest()[:8], 16)
            torch.manual_seed(seed)
            waves, rate = model.generate_voice_clone(text=text, language='Korean', voice_clone_prompt=prompt,
                non_streaming_mode=True, max_new_tokens=600, temperature=.55, subtalker_temperature=.45)
            assert rate == RATE
            audio = tidy(np.asarray(waves[0], dtype='float32'))
            rms = float(np.sqrt(np.mean(audio**2)))
            peak = float(np.max(np.abs(audio)))
            audio *= min(.1/max(rms,.001), .89/max(peak,.001))
            assert .3 < len(audio)/RATE < 18
            sf.write(file, audio, RATE, subtype='PCM_16')
        score = similarity(audio)
        candidates.append((score, audio, file.name))
        # Retry only conspicuous speaker mismatch, not an automatic approval threshold.
        if score >= .78:
            break
    score, audio, filename = max(candidates, key=lambda c:c[0])
    return audio, {'text':text,'file':filename,'speaker_similarity':round(score,4),'candidate_count':len(candidates)}

for number, e in enumerate(issues, 1):
    key = e['key']
    target = out/'after'/f'{key}.wav'
    if key in completed and target.exists() and sha(target) == completed[key]['sha256']:
        continue
    started = time.monotonic()
    segments = []
    if key in tail_cuts:
        audio = read(key)[:int(tail_cuts[key]*RATE)].copy()
        audio[-240:] *= np.linspace(1, 0, 240)
        method = 'trailing-artifact-only'
    elif key in splices:
        parts = [read(k)[int(start*RATE):None if end is None else int(end*RATE)] for k,start,end in splices[key]]
        audio = join(parts)
        segments = [{'source':k,'start':start,'end':end} for k,start,end in splices[key]]
        method = 'reuse-approved-exercise-sentences'
    else:
        sentences = re.split(r'(?<=[.!?])\s+', e['text'])
        parts = []
        skip = 0
        if key in prefixes:
            end, skip = prefixes[key]
            parts.append(read(key)[:int(end*RATE)])
            segments.append({'preserved_prefix_seconds':end,'sentences':skip})
        for index, sentence in enumerate(sentences[skip:], skip):
            part, metadata = generate(key, index, sentence)
            parts.append(part)
            segments.append(metadata)
        audio = join(parts)
        method = 'preserve-prefix-and-revoice-tail' if skip else 'sentence-anchored-revoice'
    assert .3 < len(audio)/RATE < (18 if key.startswith('defense_move_') else 35)
    sf.write(target, audio, RATE, subtype='PCM_16')
    assert sha(target) != e['sha256']
    completed[key] = {'key':key,'id':e['id'],'text':e['text'],'note':e['note'],'previous_status':e['status'],
        'previous_sha256':e['sha256'],'sha256':sha(target),'duration':round(len(audio)/RATE,3),
        'method':method,'segments':segments,'status':'awaiting-user-review'}
    result['clips'] = list(completed.values())
    manifest_path.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f"{number}/{len(issues)} {e['id']} {method}: {len(audio)/RATE:.2f}s ({time.monotonic()-started:.1f}s)", flush=True)

for e in feedback['entries']:
    assert sha(ROOT/'Resources/DefenseAudio'/f"{e['key']}.wav") == e['sha256']
print('All candidates saved separately; every app audio file still unchanged.', flush=True)
