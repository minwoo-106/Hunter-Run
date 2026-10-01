"""Portable asset/configuration and production-isolation checks, not Swift tests."""
from pathlib import Path
import hashlib
import json
import struct

root = Path(__file__).resolve().parent.parent
manifest = json.loads((root/'Prototypes/OperatorLife/asset-manifest.json').read_text(encoding='utf-8'))
assert len(manifest) == 16
for entry in manifest:
    folder = root/'Resources/Assets.xcassets'/(entry['asset']+'.imageset')
    contents = json.loads((folder/'Contents.json').read_text(encoding='utf-8'))
    image = folder/contents['images'][0]['filename']
    data = image.read_bytes()
    assert hashlib.sha256(data).hexdigest() == entry['sha256'], entry['asset']
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    assert list(struct.unpack('>II', data[16:24])) == entry['size'] == [1024, 1536]
    assert data[25] == 6, entry['asset'] # RGBA PNG; alpha retained
config = json.loads((root/'Resources/operator-life-cues.json').read_text(encoding='utf-8'))
assert config['activities'] == ['coffee','tablet','spacingOut','hairSweep','burger','dozing']
assert config['activitySeconds']['burgerFlustered'] == 3.2
assert config['activitySeconds']['cola'] == 4.8
assert len(config['cues']) == 12
project = (root/'project.yml').read_text(encoding='utf-8')
assert 'com.hunterrun.demo' in project and 'MARKETING_VERSION: "1.6.1"' in project
assert 'CURRENT_PROJECT_VERSION: 54' in project and 'OPERATOR_LIFE_POC' not in project
home = (root/'App/HunterRunApp.swift').read_text(encoding='utf-8').split('struct HomeView: View')[1].split('struct ActiveRunView: View')[0]
assert 'OPERATOR_LIFE_POC' not in (root/'App/HunterRunApp.swift').read_text(encoding='utf-8')
assert 'OPERATOR_LIFE_POC' not in (root/'App/AppModel.swift').read_text(encoding='utf-8')
assert 'OperatorPortrait(' not in home
assert 'OperatorLifeStage<OperatorPoseRenderer>' in home
assert 'if life.consumeTap() { return }' in home
assert 'lifeScenePhase == .active' in home and 'transitionCovered' in home
runtime = (root/'App/OperatorLife/OperatorLifeRuntime.swift').read_text(encoding='utf-8')
assert 'try!' not in runtime and 'LifeSequence.decode' in runtime
core = (root/'Sources/OperatorLifeCore/LifeSequence.swift').read_text(encoding='utf-8')
assert 'HunterSave' not in core and 'AppModel' not in core
print('Validated 16 unchanged approved RGBA poses, life cues and normal-app integration; Swift compilation still requires Xcode.')
