"""Validate iterative review packages without treating synthesized audio as approved."""
import argparse
import hashlib
import json
import re
import struct
import wave
import zipfile
from pathlib import Path

p=argparse.ArgumentParser()
p.add_argument('--repair-dir',type=Path,required=True)
p.add_argument('--package',type=Path,required=True)
a=p.parse_args()
root=Path(__file__).resolve().parents[1]
batch=a.repair_dir;package=a.package
review=json.loads((batch/'review-original.json').read_text(encoding='utf-8'))['entries']
repairs=json.loads((batch/'repairs.json').read_text(encoding='utf-8'))['clips']
expected={e['key'] for e in review if e['status']!='ok'}
assert len({e['key'] for e in review})==len(review)==151
assert {r['key'] for r in repairs}==expected and len(repairs)==len(expected)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
page=(package/'index.html').read_text(encoding='utf-8')
data=json.loads(re.search(r'const DATA=(.*?);\s*const \$=',page,re.S).group(1))
assert set(data['revisions'])==expected
bykey={r['key']:r for r in repairs}
for e in review:
    key=e['key'];r=bykey.get(key)
    assert sha(batch/'baseline'/f'{key}.wav')==e['sha256']
    expected_hash=r['sha256'] if r else e['sha256']
    expected_text=r['text'] if r else e['text']
    assert data['hashes'][key]==expected_hash
    assert data['lines'][key]==expected_text
    assert sha(package/'audio'/f'{key}.wav')==expected_hash
    if r:
        assert r['previous_text']==e['text'] and r['previous_sha256']==e['sha256']
        assert r['note']==e['note'] and r['status']=='awaiting-user-review'
        assert sha(package/'audio-before'/f'{key}.wav')==e['sha256']
        with wave.open(str(batch/'after'/f'{key}.wav')) as f:
            assert (f.getframerate(),f.getnchannels(),f.getsampwidth())==(24000,1,2)
            duration=f.getnframes()/24000
            assert .3<duration<35 and abs(duration-r['duration'])<.002
            samples=struct.unpack('<'+'h'*f.getnframes(),f.readframes(f.getnframes()))
            assert 100<max(abs(s) for s in samples)<32700
with zipfile.ZipFile(package.with_suffix('.zip')) as z:
    assert z.testzip() is None
    assert z.read(package.name+'/index.html')==(package/'index.html').read_bytes()
    for key,expected_hash in data['hashes'].items():
        assert hashlib.sha256(z.read(f'{package.name}/audio/{key}.wav')).hexdigest()==expected_hash
    assert len([name for name in z.namelist() if '/audio-before/' in name])==len(expected)
# Preview changes must not silently modify installed app resources.
manifest=json.loads((root/'Resources/defense-voice.json').read_text(encoding='utf-8'))
for c in manifest['clips']:
    assert sha(root/'Resources/DefenseAudio'/c['file'])==c['sha256']
print(f'PASS: {151-len(expected)} approvals preserved byte-for-byte; {len(expected)} candidates and originals;')
print('baseline, notes, revised wording, wave format/duration/peak, HTML hashes, ZIP integrity and app source isolation.')
