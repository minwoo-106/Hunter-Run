# 0.10.1 build12 · 배포 검증 완료

- Codemagic21: https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa4cdaef69d4792da4a8063
- 소스388161b12cdf9470f3fa5873d6a5b812412f6561, 개인 무료 M2,9분37초. 로직93/UI9/Release/ZIP/IPA/64개음성SHA 검증 모두 통과.
- 설치파일 HunterRun-0.10.1-build12-install.zip 57,049,984bytes(54.41MB), 내부 IPA57,043,070bytes. 체크섬 docs/build-0.10.1-manifest.json.
- 사용자28/57/61/64 후보 승인. 28 끝 잡음으로 마지막0.5초 제거 요청 반영:6.359→5.859초. 57/61/64승인 후보 그대로 적용, 나머지60개 SHA 유지.
- 최종 오디오 outputs/operator-consistent-final-010. 원본 후보는 docs/voice-audition/repair-010-candidates. Resources/operator-voice.json에 seed_tag/source_sha256/trim_end_seconds 기록.
- 전체 청취 http://127.0.0.1:8769/0.10.1/ (64개, 앱 리소스SHA동일). 기존0.9/0.10/0.10-repair페이지는 이전비교용으로 보존.
- 선택적10초 가속(첫4초 선택확인 포함),보스30초 유지대체,활동당2회/종료후180초간격/첫60초조사,중단복구 보존 포함.
- 전체v1공수 추정약60%. 다음묶음은엘리트/개체별패턴/장비·협회해금/효과음/현장밸런스. docs/v1-progress-estimate.md, v1-remaining.md 참고.
- 시작안내/아이폰첫테스트/README 업데이트 완료. 다음은 실기기0.10.1청취와가속검증피드백.
- 이번PC종료요청 없음. 전날1회종료요청 이미완료.
