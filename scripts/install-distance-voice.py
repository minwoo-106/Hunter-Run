"""Add locally generated kilometer calls to the operator voice manifest."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("source", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
lines = json.loads((root / "Resources/audio-lines.json").read_text(encoding="utf-8"))
target = root / "Resources/operator-voice.json"
manifest = json.loads(target.read_text(encoding="utf-8"))
generated = json.loads((args.source / "operator-voice.json").read_text(encoding="utf-8"))
existing = {clip["key"] for clip in manifest["clips"]}
for clip in generated["clips"]:
    key = clip["key"]
    assert (key.startswith("distance_km_") or key.startswith("distance_walk_km_")) and key not in existing
    assert clip["text"] == lines[key]
    source = args.source / clip["file"]
    assert hashlib.sha256(source.read_bytes()).hexdigest() == clip["sha256"]
    shutil.copy2(source, root / "Resources/Audio" / clip["file"])
    manifest["clips"].append(clip)
    existing.add(key)
target.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Installed {len(generated['clips'])} distance clips; total {len(manifest['clips'])}.")
