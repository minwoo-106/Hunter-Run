"""Validate shipped campaign content/media, without Apple SDKs or subjective quality claims."""
import hashlib, json, pathlib, struct, wave
root = pathlib.Path(__file__).resolve().parents[1]
read = lambda path: json.loads((root/path).read_text(encoding='utf-8-sig'))
catalog = read('Resources/defense-campaign.json')
lines = read('Resources/defense-lines.json')
manifest = read('Resources/defense-voice.json')
assert catalog['version'] == 1 and len(catalog['acts']) == 6
assert [e['number'] for e in catalog['episodes']] == list(range(1,31))
assert [a['episode'] for a in catalog['illustrations']] == [1,5,10,15,20,25,30]
exercises = {'march','step','knee','squat','wallPush','heel','boxing'}
for e in catalog['episodes']:
    assert e['act'] == (e['number']-1)//5+1
    assert len(e['exercises']) == 15 and set(e['exercises']) <= exercises
    assert e['operation'] in {'hold','repair','rescue','stabilize'}
    assert len(e['intermissions']) == 2
    prefix = f"defense_{e['number']:02}"
    assert [lines[prefix+s] for s in ['_brief','_rest1','_rest2','_outro']] == [e['briefing'],*e['intermissions'],e['outro']]
assert len(lines) == len(manifest['clips']) == 151
assert len({c['key'] for c in manifest['clips']}) == 151
assert {c['key'] for c in manifest['clips']} == set(lines)
assert {p.stem for p in (root/'Resources/DefenseAudio').glob('*.wav')} == set(lines)
total_audio = 0
for c in manifest['clips']:
    assert c['text'] == lines[c['key']], c['key']
    path = root/'Resources/DefenseAudio'/c['file']
    assert path.parent == root/'Resources/DefenseAudio'
    assert path.name == c['key']+'.wav'
    assert hashlib.sha256(path.read_bytes()).hexdigest() == c['sha256'], c['key']
    with wave.open(str(path)) as f:
        assert (f.getnchannels(),f.getsampwidth(),f.getframerate()) == (1,2,24000)
        duration = f.getnframes()/f.getframerate()
        assert .3 < duration < 35 and abs(duration-c['duration']) < .002
        if c['key'].startswith('defense_move_'): assert duration < 18, c['key']
        samples = struct.unpack('<'+'h'*f.getnframes(), f.readframes(f.getnframes()))
        assert 100 < max(abs(s) for s in samples) < 32700
    total_audio += path.stat().st_size
assets = ['DefenseAnnex']+[a['asset'] for a in catalog['illustrations']]+[catalog['illustrations'][-1]['behind']]
assert len(assets) == len(set(assets)) == 9
total_images = 0
for name in assets:
    folder = root/f'Resources/Assets.xcassets/{name}.imageset'
    spec = json.loads((folder/'Contents.json').read_text(encoding='utf-8-sig'))
    image = folder/spec['images'][0]['filename']
    content = image.read_bytes()
    assert content[:8] == b'\x89PNG\r\n\x1a\n'
    w,h = struct.unpack('>II', content[16:24])
    assert w >= 768 and h >= 1024, (name,w,h)
    total_images += len(content)
print(f'Validated 30 episodes, 151 voice mappings/PCM/hashes/timing and 9 image references. Audio {total_audio/1024**2:.1f} MiB, art {total_images/1024**2:.1f} MiB. Subjective media approval is still required.')
