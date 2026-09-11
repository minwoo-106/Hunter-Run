"""Validate project inputs without requiring Apple SDKs."""
import json, pathlib, plistlib, wave
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
assert (root / "Resources/Assets.xcassets/Operator.imageset/operator.png").is_file()
print(f"Validated {len(ids)} events, {len(keys)} audio clips, permissions and operator asset.")

