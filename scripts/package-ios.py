"""Package the compiled iPhone app with versioned filenames and verify bundled voice assets."""
import hashlib, io, json, pathlib, plistlib, sys, zipfile
app=pathlib.Path(sys.argv[1]); out=pathlib.Path(sys.argv[2]); out.mkdir(parents=True,exist_ok=True)
info=plistlib.loads((app/'Info.plist').read_bytes())
version=info['CFBundleShortVersionString']; build=info['CFBundleVersion']
assert all(c.isdigit() or c=='.' for c in version) and str(build).isdigit()
assert info['CFBundleIdentifier']=='com.hunterrun.demo'
manifest_paths=list(app.rglob('operator-voice.json')); assert len(manifest_paths)==1
voice=json.loads(manifest_paths[0].read_text())
assert len(voice['clips'])==56
for clip in voice['clips']:
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
report=dict(version=version,build=build,voice=voice['voice'],clips=len(voice['clips']),files=[dict(name=p.name,bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in [ipa,install]])
(out/(stem+'-manifest.json')).write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
print('Verified versioned installer, inner IPA, executable and all 56 designed voice hashes.')
