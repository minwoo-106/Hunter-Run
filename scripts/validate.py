"""Validate project inputs without requiring Apple SDKs."""
import json, pathlib, plistlib, struct, wave
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
