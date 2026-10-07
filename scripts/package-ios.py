"""Package the compiled iPhone app with versioned filenames and verify bundled voice assets."""
import hashlib, io, json, pathlib, plistlib, sys, zipfile
app=pathlib.Path(sys.argv[1]); out=pathlib.Path(sys.argv[2]); out.mkdir(parents=True,exist_ok=True)
info=plistlib.loads((app/'Info.plist').read_bytes())
version=info['CFBundleShortVersionString']; build=info['CFBundleVersion']
assert all(c.isdigit() or c=='.' for c in version) and str(build).isdigit()
assert info['CFBundleIdentifier']=='com.hunterrun.demo'
assert (app/info['CFBundleExecutable']).read_bytes()[:4] in (b'\xcf\xfa\xed\xfe',b'\xca\xfe\xba\xbe')
assert (app/'Assets.car').is_file()
cue_paths=list(app.rglob('operator-life-cues.json')); assert len(cue_paths)==1
root=pathlib.Path(__file__).resolve().parent.parent
assert json.loads(cue_paths[0].read_text(encoding='utf-8'))==json.loads((root/'Resources/operator-life-cues.json').read_text(encoding='utf-8'))
chat_paths=list(app.rglob('operator-chat.json')); assert len(chat_paths)==1
assert json.loads(chat_paths[0].read_text(encoding='utf-8'))==json.loads((root/'Resources/operator-chat.json').read_text(encoding='utf-8'))
life_assets=json.loads((root/'Prototypes/OperatorLife/asset-manifest.json').read_text(encoding='utf-8'))
assert len(life_assets)==16
manifest_paths=list(app.rglob('operator-voice.json')); assert len(manifest_paths)==1
voice=json.loads(manifest_paths[0].read_text())
assert len(voice['clips'])==177
for clip in voice['clips']:
    files=list(app.rglob(clip['file'])); assert len(files)==1,clip['file']
    assert hashlib.sha256(files[0].read_bytes()).hexdigest()==clip['sha256'],clip['file']
# Release must contain the exact campaign and voice revisions the user reviewed.
for name in ['defense-campaign', 'defense-lines', 'defense-voice']:
    paths=list(app.rglob(name+'.json')); assert len(paths)==1,name
    assert json.loads(paths[0].read_text(encoding='utf-8'))==json.loads((root/'Resources'/(name+'.json')).read_text(encoding='utf-8')),name
defense=json.loads((root/'Resources/defense-voice.json').read_text(encoding='utf-8'))
approval=json.loads((root/'docs/indoor-defense/reviews/2026-10-07-final-approval.json').read_text(encoding='utf-8'))
assert len(defense['clips'])==151
assert approval['voices']=={c['key']:c['sha256'] for c in defense['clips']}
for clip in defense['clips']:
    files=list(app.rglob(clip['file'])); assert len(files)==1,clip['file']
    assert hashlib.sha256(files[0].read_bytes()).hexdigest()==clip['sha256'],clip['file']
stem=f'HunterRun-{version}-build{build}'
ipa=out/(stem+'-unsigned.ipa'); install=out/(stem+'-install.zip')
with zipfile.ZipFile(ipa,'w',zipfile.ZIP_DEFLATED) as z:
    z.writestr('Payload/',''); z.writestr('Payload/HunterRun.app/','')
    for path in sorted(app.rglob('*')):
        z.write(path,'Payload/HunterRun.app/'+path.relative_to(app).as_posix())
with zipfile.ZipFile(install,'w',zipfile.ZIP_DEFLATED) as z: z.write(ipa,ipa.name)
with zipfile.ZipFile(install) as z:
    assert z.namelist()==[ipa.name] and z.testzip() is None
    with zipfile.ZipFile(io.BytesIO(z.read(ipa.name))) as inner:
        assert inner.testzip() is None
        packed=plistlib.loads(inner.read('Payload/HunterRun.app/Info.plist'))
        assert packed['CFBundleShortVersionString']==version and packed['CFBundleVersion']==build
        assert 'Payload/HunterRun.app/'+info['CFBundleExecutable'] in inner.namelist()
report=dict(version=version,build=build,bundle=info['CFBundleIdentifier'],voice=voice['voice'],clips=len(voice['clips']),lifePoses=len(life_assets),lifeCuesSHA256=hashlib.sha256(cue_paths[0].read_bytes()).hexdigest(),files=[dict(name=p.name,bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in [ipa,install]])
report.update(defenseClips=len(defense['clips']),defenseApprovalSHA256=hashlib.sha256((root/'docs/indoor-defense/reviews/2026-10-07-final-approval.json').read_bytes()).hexdigest())
(out/(stem+'-manifest.json')).write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
print(f"Verified versioned installer, inner IPA, executable, {len(voice['clips'])} operator and {len(defense['clips'])} approved defense voice hashes.")
