# 0.8.0 build9 · 클라우드 검증 준비

- 사용자가 성인 음색의 이전 8.16초 참조 기반 실제 대사와 마지막 큰 눈/남색 브릿지 캐릭터를 승인했습니다.
- Resources/Audio의 거절된 팩을 전부 교체했습니다. 승인 시작/발견 샘플과 해시 동일. 새 19개 안내 및 반복 변형 매핑. Resources/operator-voice.json에 전체 해시.
- 400m 장기전, 25초 기습, 안정적인 사건 시점 변형, 회복 구간 전투 억제, 사건 안내, 긴 모의 활동 추가.
- 로컬 Swift 77개 테스트 통과. 리소스 검증 통과. iOS 클라우드 검증/배포 아직 남음.
- 버전별 설치 파일은 HunterRun-0.8.0-build9-install.zip / -unsigned.ipa. 소스 ZIP은 설치 불가.
- 이전 완료 빌드: 0.7.0, source53e28a9, Codemagic17, https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa432a01c8c285ff0061c1a
- 새 변경은 다음 commit으로 push 후 ios-demo / main / Mac mini M2 무료 개인 workflow를 실행합니다.
- WSL Swift: work/toolchains/swift-runtime/usr/bin/swift, LD_LIBRARY_PATH=work/toolchains/deps/usr/lib/x86_64-linux-gnu. qwen 환경/모델은 work에 보존하며 repo에 포함하지 않습니다.
