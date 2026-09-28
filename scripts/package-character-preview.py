"""Package the approved season-one character audio for optional review."""
import html
import json
import pathlib
import sys
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
output = pathlib.Path(sys.argv[1])
output.mkdir(parents=True, exist_ok=True)
catalog = json.loads((root / "Resources/character-audio.json").read_text(encoding="utf-8"))
clips = catalog["clips"]
assert len(clips) == 39 and not any(clip["key"] == "haesol_h17" for clip in clips)

cards = []
for clip in clips:
    key = html.escape(clip["key"])
    label = "강해솔" if key.startswith("haesol") else "오퍼레이터"
    cards.append(f'<article><strong>{label} · {key}</strong><p>{html.escape(clip["text"])}</p>'
                 f'<audio controls preload="none" src="audio/{html.escape(clip["file"])}"></audio></article>')
page = ('<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>Hunter Run 1.4.0 음성</title><style>body{background:#07111b;color:#f2eee6;font:16px system-ui,sans-serif;'
        'max-width:800px;margin:auto;padding:24px}article{background:#12222e;border:1px solid #416077;border-radius:12px;'
        'padding:18px;margin:14px 0}strong{color:#66e0db}audio{width:100%}p{line-height:1.6}</style>'
        '<h1>Hunter Run 1.4.0 · 인물 음성</h1><p>승인된 음성 39개를 별도로 들을 수 있습니다.</p>'
        + "\n".join(cards) + "</html>\n")

target = output / "HunterRun-1.4.0-build42-voice-preview.zip"
with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
    archive.writestr("index.html", page)
    archive.writestr("manifest.json", json.dumps(catalog, ensure_ascii=False, indent=2))
    for clip in clips:
        archive.write(root / "Resources/CharacterAudio" / clip["file"], "audio/" + clip["file"])
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
print(target)
