"""Make a self-contained review pack for newly recorded 1.3.6 operator lines."""
import hashlib
import html
import json
import pathlib
import sys
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
voice = json.loads((root / 'Resources/operator-voice.json').read_text(encoding='utf-8'))
clips = [clip for clip in voice['clips'] if clip['key'].startswith((
    'mirror-shard-automata_', 'ironhide-charger_', 'corrupted-vanguard-',
    'mirror-witch_', 'ironclad-rhino_', 'corrupted-hunter_'))]
assert len(clips) == 42
for clip in clips:
    path = root / 'Resources/Audio' / clip['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == clip['sha256']

def page(base):
    items = []
    for number, clip in enumerate(clips, 1):
        items.append(f'<article><div><b>{number:02d}</b> <code>{html.escape(clip["key"])}</code></div>'
                     f'<p>{html.escape(clip["text"])}</p>'
                     f'<audio controls preload="none" src="{base}{html.escape(clip["file"])}"></audio></article>')
    return '''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Hunter Run 1.3.6 새 오퍼레이터 음성</title><style>
body{background:#07111b;color:#f2eee6;font:16px system-ui,sans-serif;max-width:820px;margin:auto;padding:24px}
h1{font-size:1.8rem}small{color:#9cadbc}article{border:1px solid #38566b;background:#10202c;margin:14px 0;padding:18px;border-radius:14px}
b{color:#60e2dc}code{color:#b8cad6;word-break:break-all}p{line-height:1.6}audio{width:100%}
</style><h1>Hunter Run 1.3.6 · 새 음성 42개</h1><small>번호나 파일명을 알려주시면 해당 대사를 다시 조정할 수 있어요. 전체 문장을 한 번에 합성한 승인 목소리 기준입니다.</small>
''' + '\n'.join(items) + '</html>\n'

local = root / 'docs/voice-review-1.3.6'
local.mkdir(exist_ok=True)
(local / 'index.html').write_text(page('../../Resources/Audio/'), encoding='utf-8')
(local / 'manifest.json').write_text(json.dumps({'schema': 1, 'version': '1.3.6', 'clips': clips}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
if len(sys.argv) > 1:
    out = pathlib.Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
    target = out / 'HunterRun-1.3.6-voice-preview.zip'
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('index.html', page('audio/'))
        archive.writestr('manifest.json', json.dumps({'schema': 1, 'version': '1.3.6', 'clips': clips}, ensure_ascii=False, indent=2))
        for clip in clips: archive.write(root / 'Resources/Audio' / clip['file'], 'audio/' + clip['file'])
    with zipfile.ZipFile(target) as archive: assert archive.testzip() is None
    print(f'Packed {len(clips)} voice previews: {target}')
else:
    print(f'Created local preview for {len(clips)} new operator lines: {local / "index.html"}')
