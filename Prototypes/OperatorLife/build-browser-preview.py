"""Build a single-file, double-clickable preview of the approved raster poses."""
from pathlib import Path
import base64
import json

proto=Path(__file__).resolve().parent
repo=proto.parent.parent
html=(proto/'BrowserPreview/template.html').read_text(encoding='utf-8')
paths={'office':repo/'Resources/Assets.xcassets/AssociationOffice.imageset/association-office.png'}
for key,name in {'stretching':'Stretch','idle':'Idle','dozing':'Doze','surprised':'Surprised','embarrassed':'Embarrassed','blink':'Blink','coffee':'Coffee','tablet':'Tablet','spacingOut':'SpacingOut','hairSweep':'HairSweep','burger':'Burger','burgerChew':'BurgerChew','burgerSurprised':'BurgerSurprised','cola':'Cola','burgerFlustered':'ChestPat','chestPatAway':'ChestPatAway'}.items():
    paths[key]=repo/'Resources/Assets.xcassets'/('OperatorLife'+name+'.imageset')/'art.png'
for key,path in paths.items():
    html=html.replace('@@'+key+'@@','data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode('ascii'))
html=html.replace('@@sequence@@',json.dumps(json.loads((repo/'Resources/operator-life-cues.json').read_text(encoding='utf-8')),ensure_ascii=False))
assert '@@' not in html
out=repo/'build/operator-life-browser-preview.html'
out.parent.mkdir(exist_ok=True)
out.write_text(html,encoding='utf-8')
print(out)
