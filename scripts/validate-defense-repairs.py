"""Technical checks for a review-only voice batch; no subjective approval implied."""
import argparse
import hashlib
import json
import re
import struct
import wave
from collections import Counter
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--repair-dir', type=Path, required=True)
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
folder = a.repair_dir.resolve()
feedback = json.loads((folder/'review-original.json').read_text(encoding='utf-8'))['entries']
repairs = json.loads((folder/'repairs.json').read_text(encoding='utf-8'))['clips']
review = {e['key']:e for e in feedback}
lines = json.loads((root/'Resources/defense-lines.json').read_text(encoding='utf-8'))
assert len(review) == len(feedback) == len(lines) == 151
expected = {e['key'] for e in feedback if e['status'] in ['voice', 'delivery']}
assert len(repairs) == len(expected) == 47
assert {r['key'] for r in repairs} == expected
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()

def pcm(path):
    with wave.open(str(path)) as f:
        assert (f.getframerate(), f.getsampwidth(), f.getnchannels()) == (24000, 2, 1)
        return f.readframes(f.getnframes())

# All app audio stays byte-identical, including every one of the 104 approved takes.
for e in feedback:
    assert sha(root/'Resources/DefenseAudio'/f"{e['key']}.wav") == e['sha256'], e['key']
    assert lines[e['key']] == e['text']

for r in repairs:
    e = review[r['key']]
    assert r['previous_sha256'] == e['sha256'] and r['text'] == e['text']
    assert r['note'] == e['note'] and r['status'] == 'awaiting-user-review'
    before = folder/'before'/f"{r['key']}.wav"
    after = folder/'after'/f"{r['key']}.wav"
    assert sha(before) == e['sha256']
    assert sha(after) == r['sha256'] != e['sha256']
    data = pcm(after)
    duration = len(data)/2/24000
    assert abs(duration-r['duration']) < .002
    assert .3 < duration < (18 if r['key'].startswith('defense_move_') else 35)
    samples = struct.unpack('<'+'h'*(len(data)//2), data)
    assert 100 < max(abs(s) for s in samples) < 32700
    if r['method'] == 'trailing-artifact-only':
        original = pcm(before)
        # Only the final 10 ms fade and removed suffix may differ.
        assert data[:-480] == original[:len(data)-480]
    if 'revoice' in r['method']:
        sentences = re.split(r'(?<=[.!?])\s+', e['text'])
        preserved = next((s for s in r['segments'] if 'preserved_prefix_seconds' in s), None)
        skip = preserved['sentences'] if preserved else 0
        assert [s['text'] for s in r['segments'] if 'text' in s] == sentences[skip:]
        if preserved:
            lo = int(.15*24000)*2
            hi = int((preserved['preserved_prefix_seconds']-.25)*24000)*2
            assert pcm(before)[lo:hi] in data, r['key']
print('PASS: 47 complete candidates; 104 approved takes and all app files unchanged;')
print('hashes, PCM, duration, clipping, exact trailing-noise-only edits, retained prefixes and sentence coverage.')
print(dict(Counter(r['method'] for r in repairs)))
print('Voice identity, prosody and naturalness still require the user to listen.')
