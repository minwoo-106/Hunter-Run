"""Measure speaker drift between the start/end of operator clips and the approved voice."""
import argparse
import json
from pathlib import Path

import numpy as np
import soundfile as sf
import torch
from qwen_tts import Qwen3TTSModel

p = argparse.ArgumentParser()
p.add_argument('--model', required=True)
p.add_argument('--reference', required=True)
p.add_argument('--audio-dir', required=True)
p.add_argument('--assert-consistent', action='store_true')
p.add_argument('keys', nargs='+')
a = p.parse_args()

torch.set_num_threads(4)
model = Qwen3TTSModel.from_pretrained(a.model, device_map='cuda:0', dtype=torch.bfloat16, attn_implementation='sdpa')

def embedding(samples):
    x = model.model.extract_speaker_embedding(np.asarray(samples, dtype=np.float32), 24000)
    return torch.nn.functional.normalize(x.float(), dim=-1)

def load(path):
    samples, rate = sf.read(path, dtype='float32')
    assert rate == 24000, (path, rate)
    if samples.ndim == 2:
        samples = samples.mean(axis=1)
    active = np.flatnonzero(np.abs(samples) > 0.004)
    return samples[active[0]:active[-1]+1]

reference = embedding(load(a.reference))
rows = []
for key in a.keys:
    samples = load(Path(a.audio_dir) / (key + '.wav'))
    cut = min(2 * 24000, len(samples) // 2)
    head = embedding(samples[:cut])
    tail = embedding(samples[-cut:])
    whole = embedding(samples)
    cos = lambda x, y: round(float((x * y).sum()), 4)
    rows.append(dict(key=key, duration=round(len(samples)/24000, 2),
                     head_ref=cos(head, reference), tail_ref=cos(tail, reference),
                     head_tail=cos(head, tail), whole_ref=cos(whole, reference)))
print(json.dumps(rows, ensure_ascii=False, indent=2))
if a.assert_consistent:
    bad = [row['key'] for row in rows if min(row['head_ref'], row['tail_ref'], row['head_tail']) < 0.975]
    if bad:
        raise SystemExit('Speaker drift detected: ' + ', '.join(bad))
