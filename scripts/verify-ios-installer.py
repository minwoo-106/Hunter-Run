"""Verify a downloaded release IPA against source, including approved campaign media."""
from pathlib import Path
import hashlib
import json
import plistlib
import re
import sys
import zipfile

root = Path(__file__).resolve().parents[1]
ipa = Path(sys.argv[1]).resolve()
settings = (root/'project.yml').read_text(encoding='utf-8')
version = re.search(r'MARKETING_VERSION: "([\d.]+)"', settings).group(1)
build = re.search(r'CURRENT_PROJECT_VERSION: (\d+)', settings).group(1)
source = lambda name: json.loads((root/'Resources'/name).read_text(encoding='utf-8'))
with zipfile.ZipFile(ipa) as archive:
    assert archive.testzip() is None
    prefix = 'Payload/HunterRun.app/'
    def resource(name):
        matches = [n for n in archive.namelist() if n.startswith(prefix) and n.rsplit('/', 1)[-1] == name]
        assert len(matches) == 1, (name, matches)
        return archive.read(matches[0])
    info = plistlib.loads(resource('Info.plist'))
    assert info['CFBundleIdentifier'] == 'com.hunterrun.demo'
    assert info['CFBundleShortVersionString'] == version and info['CFBundleVersion'] == build
    executable = resource(info['CFBundleExecutable'])
    assert executable[:4] in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe')
    for flag in ['--ui-testing-progress-guidance', '--ui-testing-defense-final', '--ui-testing-save', '--ui-testing-operator-gifts',
                 '--ui-testing-operator-relationship', '--life-inspect-phase', '--life-start-phase']:
        assert flag.encode() not in executable, flag
    for name in ['operator-chat.json', 'operator-life-cues.json', 'narrative.json', 'progression.json',
                 'mission.json', 'encounters.json', 'operator-voice.json', 'character-audio.json',
                 'defense-campaign.json', 'defense-lines.json', 'defense-voice.json']:
        assert json.loads(resource(name)) == source(name), name
    voice_counts = {}
    for name, count in [('operator-voice.json', 177), ('character-audio.json', 39), ('defense-voice.json', 151)]:
        manifest = source(name)
        assert len(manifest['clips']) == count
        for clip in manifest['clips']:
            assert hashlib.sha256(resource(clip['file'])).hexdigest() == clip['sha256'], clip['file']
        voice_counts[name] = count
    catalog = source('defense-campaign.json')
    defense_assets = ['DefenseAnnex']+[a['asset'] for a in catalog['illustrations']]+[catalog['illustrations'][-1]['behind']]
    life = json.loads((root/'Prototypes/OperatorLife/asset-manifest.json').read_text(encoding='utf-8'))
    asset_catalog = resource('Assets.car')
    assert all(name.encode() in asset_catalog for name in defense_assets+[a['asset'] for a in life])
report = dict(version=version, build=build, bundle=info['CFBundleIdentifier'],
    bytes=ipa.stat().st_size, sha256=hashlib.sha256(ipa.read_bytes()).hexdigest(),
    verifiedVoices=voice_counts, verifiedDefenseAssets=len(defense_assets), verifiedLifeAssets=len(life),
    simulatorFixturesExcluded=True, bundledGameDataMatchesSource=True)
ipa.with_name('local-verification.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report, ensure_ascii=False))
