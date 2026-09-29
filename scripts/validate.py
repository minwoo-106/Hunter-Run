"""Validate project inputs without requiring Apple SDKs."""
import hashlib, json, pathlib, plistlib, struct, wave
root = pathlib.Path(__file__).resolve().parents[1]
mission = json.loads((root / "Resources/mission.json").read_text(encoding="utf-8"))
assert mission["schema"] == 1
ids = [e["id"] for e in mission["events"]]
assert len(ids) == len(set(ids))
keys = {"run_start", "run_end", "pause", "resume", "signal", "pursuit_started", "investigate", "success", "partial", "audio_test"}
keys.update(e["audio"] for e in mission["events"])
for e in mission["events"]:
    assert 0 < e["startFraction"] < .9 and e["duration"] > 0
for key in keys:
    path = root / "Resources/Audio" / (key + ".wav")
    assert path.is_file(), path
    with wave.open(str(path)) as f:
        assert 0 < f.getnframes() / f.getframerate() < 15, key
voice = json.loads((root / "Resources/operator-voice.json").read_text(encoding="utf-8"))
lines = json.loads((root / "Resources/audio-lines.json").read_text(encoding="utf-8"))
keys.update(lines)
assert voice["voice"] == "adult-warm-operator" and len(voice["clips"]) == len(keys) == 177
assert {c["key"] for c in voice["clips"]} == keys == set(lines)
assert {p.stem for p in (root / "Resources/Audio").glob("*.wav")} == keys, "Unexpected or missing operator WAV"
for clip in voice["clips"]:
    path = root / "Resources/Audio" / clip["file"]
    assert clip["text"] == lines[clip["key"]]
    assert hashlib.sha256(path.read_bytes()).hexdigest() == clip["sha256"]
    with wave.open(str(path)) as f:
        assert f.getnchannels() == 1 and f.getsampwidth() == 2 and f.getframerate() == 24000
        duration = f.getnframes() / f.getframerate()
        assert .3 < duration < 15 and abs(duration - clip["duration"]) < .002
        samples = struct.unpack("<" + "h" * f.getnframes(), f.readframes(f.getnframes()))
        assert 100 < max(abs(s) for s in samples) < 32700
print(f"Validated {len(voice['clips'])} designed operator clips: transcript mapping, PCM format, duration, peak and SHA256.")
character = json.loads((root / 'Resources/character-audio.json').read_text(encoding='utf-8'))
assert character['schema'] == 1 and character['voice'] == 'season-one-approved'
assert {clip['key'] for clip in character['clips']} == (
    {f'haesol_h{i:02}' for i in range(1, 17)} | {f'operator_o{i:02}' for i in range(1, 24)}
)
assert {p.stem for p in (root / 'Resources/CharacterAudio').glob('*.wav')} == {clip['key'] for clip in character['clips']}
for clip in character['clips']:
    path = root / 'Resources/CharacterAudio' / clip['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == clip['sha256']
    with wave.open(str(path)) as f:
        assert (f.getnchannels(), f.getsampwidth(), f.getframerate()) == (1, 2, 24000)
        assert abs(f.getnframes() / f.getframerate() - clip['duration']) < .002
print('Validated 16 Haesol and 23 operator clips; startled H17 is excluded.')
with (root / "Config/Info.plist").open("rb") as f:
    info = plistlib.load(f)
assert set(info["UIBackgroundModes"]) == {"location", "audio"}
assert "NSMicrophoneUsageDescription" not in info
catalog = root / "Resources/Assets.xcassets"
for manifest in catalog.rglob("Contents.json"):
    for image in json.loads(manifest.read_text(encoding="utf-8")).get("images", []):
        if "filename" in image:
            assert (manifest.parent / image["filename"]).is_file(), manifest
icon_set = catalog / "AppIcon.appiconset"
icon_manifest = json.loads((icon_set / "Contents.json").read_text(encoding="utf-8"))
icon = (icon_set / icon_manifest["images"][0]["filename"]).read_bytes()
assert icon[:8] == b"\x89PNG\r\n\x1a\n"
assert struct.unpack(">II", icon[16:24]) == (1024, 1024), "App icon must be 1024 square"
assert icon[25] == 2, "App icon must use opaque RGB"
print(f"Validated {len(ids)} events, {len(keys)} audio clips, permissions, artwork and app icon.")
progression = json.loads((root / "Resources/progression.json").read_text(encoding="utf-8"))
missions = json.loads((root / "Resources/missions.json").read_text(encoding="utf-8"))
gate_balance = json.loads((root / "Resources/gate-balance.json").read_text(encoding="utf-8"))
assert gate_balance['eligibleSessionsToGuarantee'] == 2
assert 0 <= gate_balance['firstEncounterChance'] <= 1
assert .5 <= gate_balance['encounterFraction'] <= .8
assert 1 <= gate_balance['coreHP'] <= 1000
assert (root / 'Resources/Audio/watcher_intro.wav').is_file()
assert progression['schema'] == missions['schema'] == 1
assert len(progression['equipment']) == len({e['id'] for e in progression['equipment']}) == 36
assert {u['department'] for u in progression['upgrades']} == {'observation', 'research', 'equipment', 'contracts'}
assert set(missions['modes']) == {'exploration', 'contract', 'gate'}
for mission in missions['modes'].values():
    events = mission['events']
    assert len(events) == len({e['id'] for e in events})
    assert all(0 < e['startFraction'] < .9 and e['duration'] > 0 and e['hp'] >= 0 for e in events)
    assert all((root / 'Resources/Audio' / (e['audio'] + '.wav')).is_file() for e in events)
print('Validated 36 equipment items, eight department upgrades, and three mission modes.')

for item in progression['equipment']:
    folder = catalog / ('Gear-' + item['id'] + '.imageset')
    manifest = json.loads((folder / 'Contents.json').read_text(encoding='utf-8'))
    data = (folder / manifest['images'][0]['filename']).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", item['id']
    width, height = struct.unpack('>II', data[16:24])
    assert width == height and width >= 512, item['id']
print('Validated 36 individual equipment illustrations.')

world = json.loads((root / 'Resources/world.json').read_text(encoding='utf-8'))
assert world['schema'] == 1 and len(world['bosses']) == 3 and len(world['monsters']) == 26
for boss in world['bosses']:
    assert len(boss['phases']) == 3 and 100 <= boss['maximumHP'] <= 100000
    for phase in boss['phases']:
        assert any(e['id'].startswith('major-strike') and e['kind'] == 'boss' for e in phase['events'])
        assert all((root / 'Resources/Audio' / (e['audio'] + '.wav')).is_file() for e in phase['events'])
for asset in ['Monster-' + m['id'] for m in world['monsters']] + ['AssociationOffice', 'AssociationOperational', 'AssociationAdvanced', 'AssociationResearch', 'AssociationBeacon']:
    assert (catalog / (asset + '.imageset') / 'Contents.json').is_file(), asset
with wave.open(str(root / 'Resources/Music/association-theme.wav')) as music:
    assert music.getnchannels() == 2 and music.getsampwidth() == 2 and music.getframerate() == 44100
    assert music.getnframes() == 32 * 44100
print('Validated three major bosses, 26 monster illustrations, five association stages and lobby music.')

for asset in ['HaesolBefore', 'HaesolHairTie', 'HaesolCurious', 'HaesolBeetle']:
    art = catalog / (asset + '.imageset') / 'art.png'
    data = art.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', asset
    width, height = struct.unpack('>II', data[16:24])
    assert height > width and width >= 800, asset
print('Validated four late-story Haesol portraits.')

transition_art = [
    'TransitionHomeWork', 'TransitionHomeCoffee', 'TransitionHomeBurger',
    'TransitionHomeClose', 'TransitionHomeNap', 'TransitionHunterArmory',
    'TransitionAssociationHall', 'TransitionAssociationGate',
    'TransitionCodexArchive', 'TransitionCodexScroll',
]
for asset in transition_art:
    art = catalog / (asset + '.imageset') / 'art.png'
    data = art.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', asset
    width, height = struct.unpack('>II', data[16:24])
    assert width >= 800 and height >= 800, asset
print('Validated ten navigation transition illustrations.')

launch_art = catalog / 'LaunchPortal.imageset' / 'art.png'
launch_data = launch_art.read_bytes()
assert launch_data[:8] == b'\x89PNG\r\n\x1a\n', 'LaunchPortal'
launch_width, launch_height = struct.unpack('>II', launch_data[16:24])
assert launch_height > launch_width and launch_width >= 800, 'LaunchPortal'
print('Validated the animated entrance background.')

variants = json.loads((root / 'Resources/audio-variants.json').read_text(encoding='utf-8'))
assert set(variants) == {'discovery', 'success', 'partial', 'survey_done'}
for key, clips in variants.items():
    assert key in clips and len(clips) >= 2 and len(clips) == len(set(clips))
    assert all(clip in lines for clip in clips)
events = [e for mode in missions['modes'].values() for e in mode['events']]
assert {'endurance', 'ambush'} <= {e['kind'] for e in events}
for event in events:
    if event['kind'] == 'endurance': assert 400 <= event['targetDistance'] <= 800
print('Validated distance encounters and non-repeating voice variant mappings.')

narration = json.loads((root / 'Resources/narration.json').read_text(encoding='utf-8'))
assert narration['schema'] == 1 and len(narration['encounters']) == 26
assert {rule['id'] for rule in narration['encounters']} == {monster['id'] for monster in world['monsters']}
for rule in narration['encounters']:
    monster = next(m for m in world['monsters'] if m['id'] == rule['id'])
    assert rule['eventIDs'] == monster['eventIDs'] and rule['bossID'] == monster.get('bossID')
    assert rule['defeated'] in lines and rule['hit'] in lines
for mode in missions['modes'].values():
    for event in mode['events']:
        if event.get('shortAudio'): assert event['shortAudio'] in lines
assert all('dispatch_' + key in lines for key in ['arrival','signal','pattern','branch','boundary','network'])
assert not any(ending in text for text in lines.values() for ending in ['습니다', '입니다', '합니다', '겠습니다'])
print('Validated encounter outcome mappings, named short instructions, six dispatches and consistent polite speech.')

feedback = json.loads((root / 'docs/voice-review-0.9.json').read_text(encoding='utf-8'))
for clip in feedback['clips']:
    assert hashlib.sha256((root/'Resources/Audio'/clip['file']).read_bytes()).hexdigest() != clip['sha256'], 'Still contains rejected recording: '+clip['key']
assert all('우와' not in line for line in lines.values())
for boss in world['bosses']:
    for phase in boss['phases']:
        strikes = [e for e in phase['events'] if e['id'].startswith('major-strike')]
        assert any(e.get('burstSeconds') == 10 for e in strikes)
        assert any(e.get('burstSeconds') is None for e in strikes)
        for event in strikes:
            if event.get('burstSeconds'):
                assert event['duration'] == 10 and event['steadyAudio'] in lines
print('Verified replacement of 14 user-rejected WAVs, no 우와, and mixed 10-second/steady boss attacks.')

encounters = json.loads((root/'Resources/encounters.json').read_text(encoding='utf-8'))
assert len(encounters['encounters']) == 18
for entry in encounters['encounters']:
    assert entry['monsterID'] in {m['id'] for m in world['monsters']}
    if entry.get('requiredAction'): assert any(entry['requiredAction'] in u['unlockActions'] for u in progression['upgrades'])
    for mode, slot in entry['slots'].items(): assert slot in {e['id'] for e in missions['modes'][mode]['events']}
    for event in [entry['event']] + ([entry['survey']] if entry.get('survey') else []):
        for key in ['audio','shortAudio','steadyAudio']:
            if event.get(key): assert event[key] in lines
for item in progression['equipment']:
    if item.get('requiredEvent'): assert item['requiredEvent'] in {e['event']['id'] for e in encounters['encounters']}
    if item.get('requiredDefeat'): assert item['requiredDefeat'] in {e['event']['id'] for e in encounters['encounters']} | {b['id'] for b in world['bosses']}
assert world['bosses'][-1]['requiredDefeats'] == [f'corrupted-vanguard-{role}' for role in ['warrior','mage','archer','cleric']]
print('Validated eighteen encounter pools, boss defeat unlocks and four-vanguard final route.')

narrative = json.loads((root/'Resources/narrative.json').read_text(encoding='utf-8'))
scenes = narrative['scenes']
assert len(scenes) == len({s['id'] for s in scenes}) == 33
expressions = {'calm', 'smile', 'playful', 'thoughtful', 'worried', 'relieved'}
for scene in scenes:
    assert (catalog / (scene['artwork'] + '.imageset') / 'Contents.json').is_file()
    nodes = {n['id']: n for n in scene['nodes']}
    assert len(nodes) == len(scene['nodes']) and scene['start'] in nodes
    for node in nodes.values():
        assert node['expression'] in expressions and node['text'].strip()
        if node.get('voiceKey'):
            assert node['voiceKey'] in {clip['key'] for clip in character['clips']}
        if node.get('next'): assert node['next'] in nodes
        for choice in node.get('choices', []): assert choice['next'] in nodes and choice['text'].strip()
for expression in expressions - {'calm'}:
    assert (catalog / ('Operator-' + expression + '.imageset') / 'Contents.json').is_file()
for key in ['ui-select', 'ui-reward', 'ui-gate']:
    with wave.open(str(root/'Resources/Effects'/(key + '.wav'))) as effect:
        assert effect.getnframes() > 0 and effect.getsampwidth() == 2
print('Validated 33 story scenes, expression/background references and three effect resources.')
assert next(s for s in scenes if s['id'] == 'M21')['artwork'] == 'PurificationRoom'
assert all(len([n for n in s['nodes'] if n.get('choices')]) == 1 for s in scenes if s['id'] in ('M10', 'M13'))
