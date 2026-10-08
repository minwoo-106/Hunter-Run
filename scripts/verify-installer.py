"""배포 설치 파일의 버전, 실행 파일, 콘텐츠와 승인 음성을 독립 검증한다."""
import argparse
import hashlib
import json
import pathlib
import plistlib
import struct
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=pathlib.Path)
    parser.add_argument('--version', required=True)
    parser.add_argument('--build', required=True)
    parser.add_argument('--output', type=pathlib.Path)
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parent.parent
    with zipfile.ZipFile(args.ipa) as archive:
        names = archive.namelist()
        assert len(names) == len(set(names)), '설치 파일 내부 경로 중복'
        assert archive.testzip() is None, '설치 파일 압축 손상'
        infos = [n for n in names if n.startswith('Payload/') and n.count('/') == 2 and n.endswith('.app/Info.plist')]
        assert len(infos) == 1, '앱 메타데이터 개수 오류'
        info = plistlib.loads(archive.read(infos[0]))
        assert info['CFBundleShortVersionString'] == args.version, '버전 불일치'
        assert str(info['CFBundleVersion']) == args.build, '빌드 번호 불일치'
        assert info['CFBundleIdentifier'] == 'com.hunterrun.demo', '앱 식별자 불일치'
        prefix = infos[0].removesuffix('Info.plist')
        executable = archive.read(prefix + info['CFBundleExecutable'])
        assert executable[:4] == b'\xcf\xfa\xed\xfe', '64비트 실행 파일 형식 오류'
        assert struct.unpack_from('<I', executable, 4)[0] == 0x0100000c, 'iPhone ARM64 실행 파일 아님'
        assert prefix + 'Assets.car' in names, '이미지 자산 누락'
        assert any(n.startswith(prefix) and n.endswith('/default.metallib') for n in names), '셰이더 누락'

        def bundled(filename):
            matches = [n for n in names if n.startswith(prefix) and n.rsplit('/', 1)[-1] == filename]
            assert len(matches) == 1, filename + ' 누락 또는 중복'
            return archive.read(matches[0])

        content_hashes = {}
        for source in sorted((root / 'Resources').glob('*.json')):
            data = bundled(source.name)
            assert json.loads(data) == json.loads(source.read_text(encoding='utf-8')), source.name + ' 내용 불일치'
            content_hashes[source.name] = hashlib.sha256(data).hexdigest()
        voice_counts = {}
        for catalog_name in ['operator-voice', 'character-audio', 'defense-voice']:
            catalog = json.loads(bundled(catalog_name + '.json'))
            for clip in catalog['clips']:
                assert hashlib.sha256(bundled(clip['file'])).hexdigest() == clip['sha256'], clip['file'] + ' 음성 불일치'
            voice_counts[catalog_name] = len(catalog['clips'])
        assert not any(n.endswith(('combat-v3-golden.json', 'haesol_h17.wav')) for n in names), '제외된 자산 혼입'
    report = dict(version=args.version, build=args.build, bundle=info['CFBundleIdentifier'],
                  file=args.ipa.name, bytes=args.ipa.stat().st_size,
                  sha256=hashlib.sha256(args.ipa.read_bytes()).hexdigest(),
                  content=content_hashes, voices=voice_counts)
    result = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(result + '\n', encoding='utf-8')
    print(result)


if __name__ == '__main__':
    main()
