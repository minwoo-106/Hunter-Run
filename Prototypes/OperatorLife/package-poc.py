"""Package the isolated unsigned PoC; never overwrite the normal Hunter Run app."""
import hashlib
import json
import pathlib
import plistlib
import sys
import zipfile

app = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'com.hunterrun.operatorpoc'
assert info['CFBundleShortVersionString'] == '1.6.0' and info['CFBundleVersion'] == '51'
assert (app / 'Assets.car').is_file()
assert (app / info['CFBundleExecutable']).read_bytes()[:4] in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe')
cues = list(app.rglob('operator-life-cues.json'))
assert len(cues) == 1
assert json.loads(cues[0].read_text()) == json.loads(pathlib.Path('Prototypes/OperatorLife/Resources/operator-life-cues.json').read_text())
catalogs = list(app.rglob('operator-voice.json'))
assert len(catalogs) == 1
voice = json.loads(catalogs[0].read_text())
assert len(voice['clips']) == 177
for clip in voice['clips']:
    files = list(app.rglob(clip['file']))
    assert len(files) == 1 and hashlib.sha256(files[0].read_bytes()).hexdigest() == clip['sha256'], clip['file']
stem = 'HunterRun-OperatorLife-PoC-build51'
ipa = out / (stem + '-unsigned.ipa')
with zipfile.ZipFile(ipa, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(app.rglob('*')):
        archive.write(path, 'Payload/HunterRun.app/' + path.relative_to(app).as_posix())
with zipfile.ZipFile(ipa) as archive:
    assert archive.testzip() is None
    packed = plistlib.loads(archive.read('Payload/HunterRun.app/Info.plist'))
    assert packed['CFBundleIdentifier'] == 'com.hunterrun.operatorpoc'
report = dict(bundle=info['CFBundleIdentifier'], displayName=info['CFBundleDisplayName'], version='1.6.0', build='51',
              prototype=True, originalVoiceClipsVerified=len(voice['clips']),
              file=ipa.name, bytes=ipa.stat().st_size, sha256=hashlib.sha256(ipa.read_bytes()).hexdigest())
(out / (stem + '-manifest.json')).write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
