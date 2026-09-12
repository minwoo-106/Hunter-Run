# 0.11.0 build13 · 배포 검증 완료

- 소스: b5e45291be7c782f983d41413699bd30c8663386. 비공개 main에 push 완료.
- Codemagic23: https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa51cfe6d07de75e140b03f
- 개인 무료 M2. main과 소스커밋 확인. 로컬101개 core 테스트와80개 음성 SHA/콘텐츠 검증 통과. iPhone Release 컴파일 완료, UI10개 검사 진행 중.
- 신규 다크엘프 정찰자/월영대장, 서큐버스 환영술사/몽환경비관. 일반2/엘리트2. 장비8종·총20. 부서4개 각각Lv.3 추가.
- 실제 발견 기록에 연결한 장비 해금. 모의·중립 결과는 실제 해금 제외. 출현후보를 missionSnapshot에 저장, directorVersion2로 순환 선택. 과거nil/1복구 유지.
- builtin image_gen 개별12개 이미지, prompts/source는 expansion-011-*-art.json. PNG를각Assets.xcassets에복사,원본보존.
- 새음성16개 outputs/operator-expansion-011. 같은 승인reference(run_start)·whole Qwen 로컬 생성. 기존64개해시유지. 총80개청취 http://127.0.0.1:8769/0.11/ (신규65~80).
- 이번사용자는 더큰작업묶음+서큐버스/다크엘프추가 요청. 무결성검사완료후 다운로드와체험경로 안내할것. PC종료요청없음.
- 다음: UI완료→설치ZIP/IPA해시확인→buildmanifest/README/시작안내완료표시→문서commit/push/sourcearchive.

- Build22: UI9/10, 신규모의테스트가 세션을 종료하지않아 뒤 통신테스트 잠금. 정상종료처리 수정후 Build23 전체검사중. docs/0.11-ui-regression.md.

## 최종 결과
- Codemagic23/source b5e4529: 7분48초, 개인 무료M2. Core101/UI10/Release/ZIP·IPA/80개음성SHA 모두 통과.
- 앞서 실패한 통신 테스트도 통과. 새로운 모의 테스트 종료 누락이 원인. 제품의 저장/활동잠금 로직은 유지.
- HunterRun-0.11.0-build13-install.zip 82,949,105bytes(79.11MB). 내부IPA82,936,232bytes. 체크섬 build-0.11-manifest.json.
- 다운로드 페이지는 위Codemagic23. 기존 앱 삭제 없이 같은 Apple 계정으로 업데이트. 헌터 활동→신규개체·월영과몽환→모의준비로 체험.
- v1공수추정 약65%, 콘텐츠 목표와 장시간 실기기 검증은 남음. 다음은 효과음·연출/추가개체·장비/현장밸런스.
