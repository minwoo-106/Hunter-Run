"""Install the user-approved final review batch, preserving its exact audio bytes."""
import argparse
import hashlib
import json
import pathlib
import subprocess
import sys
import wave

root = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('batch', type=pathlib.Path)
a = p.parse_args()
read = lambda path: json.loads(path.read_text(encoding='utf-8-sig'))
digest = lambda data: hashlib.sha256(data).hexdigest()
review = read(root/'docs/indoor-defense/reviews/2026-10-07-voice-review-pass2.json')['entries']
repairs = {c['key']: c for c in read(root/'docs/indoor-defense/reviews/2026-10-07-repairs-pass2.json')['clips']}
manifest = read(root/'Resources/defense-voice.json')
assert {c['key'] for c in manifest['clips']} == {e['key'] for e in review}
assert len(review) == 151 and len(repairs) == 10
assert set(repairs) == {e['key'] for e in review if e['status'] != 'ok'}
approved = {}
for entry in review:
    key = entry['key']
    correction = repairs.get(key)
    source = a.batch/('after' if correction else 'baseline')/(key+'.wav')
    data = source.read_bytes()
    expected = correction or entry
    assert digest(data) == expected['sha256'], key
    with wave.open(str(source)) as wav:
        assert (wav.getframerate(), wav.getnchannels(), wav.getsampwidth()) == (24000, 1, 2)
        duration = wav.getnframes()/wav.getframerate()
    approved[key] = dict(data=data, text=expected['text'], duration=round(duration, 3), sha256=digest(data))

# Keep the authoring source and generated in-app captions in agreement.
source = root/'scripts/build-defense-content.py'
text = source.read_text(encoding='utf-8')
for correction in repairs.values():
    before, after = correction['previous_text'], correction['text']
    if before != after and before in text:
        text = text.replace(before, after)
source.write_text(text, encoding='utf-8')
subprocess.run([sys.executable, str(source)], check=True)
lines = read(root/'Resources/defense-lines.json')
assert all(lines[key] == clip['text'] for key, clip in approved.items())
changed = 0
for clip in manifest['clips']:
    final = approved[clip['key']]
    target = root/'Resources/DefenseAudio'/clip['file']
    if target.read_bytes() != final['data']:
        target.write_bytes(final['data']); changed += 1
    clip.update({k: v for k, v in final.items() if k != 'data'})
(root/'Resources/defense-voice.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

catalog = read(root/'Resources/defense-campaign.json')
assets = ['DefenseAnnex']+[c['asset'] for c in catalog['illustrations']]+[catalog['illustrations'][-1]['behind']]
images = {}
for name in assets:
    folder = root/f'Resources/Assets.xcassets/{name}.imageset'
    image = folder/read(folder/'Contents.json')['images'][0]['filename']
    images[name] = dict(file=image.relative_to(root).as_posix(), sha256=digest(image.read_bytes()))
approval = dict(version=1, approvedOn='2026-10-07',
    evidence='User approved the final ten corrections verbally, then confirmed: 그럼 일단 지금 기준 이미지랑 음성은 통과니까 나머지 지금 쭉 해주세요',
    voices={k: c['sha256'] for k,c in approved.items()}, images=images)
(root/'docs/indoor-defense/reviews/2026-10-07-final-approval.json').write_text(json.dumps(approval, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(f'Installed {changed} corrected clips; locked 151 approved voices and 9 approved images.')
