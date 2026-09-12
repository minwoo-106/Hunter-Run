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
assert voice["voice"] == "adult-warm-operator" and len(voice["clips"]) == len(keys) == 56
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
print("Validated 56 designed operator clips: transcript mapping, PCM format, duration, peak and SHA256.")
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
assert progression['schema'] == missions['schema'] == 1
assert len(progression['equipment']) == len({e['id'] for e in progression['equipment']}) == 12
assert {u['department'] for u in progression['upgrades']} == {'observation', 'research', 'equipment', 'contracts'}
assert set(missions['modes']) == {'exploration', 'contract', 'gate'}
for mission in missions['modes'].values():
    events = mission['events']
    assert len(events) == len({e['id'] for e in events})
    assert all(0 < e['startFraction'] < .9 and e['duration'] > 0 and e['hp'] >= 0 for e in events)
    assert all((root / 'Resources/Audio' / (e['audio'] + '.wav')).is_file() for e in events)
print('Validated 12 equipment items, four department upgrades, and three mission modes.')

for item in progression['equipment']:
    folder = catalog / ('Gear-' + item['id'] + '.imageset')
    manifest = json.loads((folder / 'Contents.json').read_text(encoding='utf-8'))
    data = (folder / manifest['images'][0]['filename']).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", item['id']
    width, height = struct.unpack('>II', data[16:24])
    assert width == height and width >= 512, item['id']
print('Validated twelve individual equipment illustrations.')

world = json.loads((root / 'Resources/world.json').read_text(encoding='utf-8'))
assert world['schema'] == 1 and len(world['bosses']) == 2 and len(world['monsters']) == 7
for boss in world['bosses']:
    assert len(boss['phases']) == 3 and 100 <= boss['maximumHP'] <= 100000
    for phase in boss['phases']:
        assert any(e['id'].startswith('major-strike') and e['kind'] == 'boss' for e in phase['events'])
        assert all((root / 'Resources/Audio' / (e['audio'] + '.wav')).is_file() for e in phase['events'])
for asset in ['Monster-' + m['id'] for m in world['monsters']] + ['AssociationOffice', 'AssociationOperational', 'AssociationAdvanced']:
    assert (catalog / (asset + '.imageset') / 'Contents.json').is_file(), asset
with wave.open(str(root / 'Resources/Music/association-theme.wav')) as music:
    assert music.getnchannels() == 2 and music.getsampwidth() == 2 and music.getframerate() == 44100
    assert music.getnframes() == 32 * 44100
print('Validated two major bosses, seven monster illustrations, three association stages and lobby music.')

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
assert narration['schema'] == 1 and len(narration['encounters']) == 7
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
