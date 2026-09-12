# 0.10.1 build12 · 네 음성 승인 반영, 빌드 준비

- 사용자 네 후보 승인,28번 마지막0.5초 제거 요청. 적용 완료: cat_ambush 5.859초.
- 57/61/64 승인 후보 적용. 나머지60개 파일 SHA 유지. Resources/operator-voice.json에 길이/체크섬/trim기록.
- 최종파일 outputs/operator-consistent-final-010.
- 0.10.1/build12로 버전 갱신, Apple 빌드 예정.

## 이전 검증 및 작업 기록
# 0.10.0 build11 기술 검증 완료 · 음성4개 청취 대기

- Codemagic20: https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa4c902c8ff44168380fafb
- 소스11a8285, 무료 개인 M2,10분5초. 로직93/UI9/Release/IPA ZIP/64개 음성 해시 검사 모두 통과.
- build-0.10-manifest.json에 크기와 체크섬 기록.
- A 방식으로 기존14개 신고 음성 및 대사수정/신규를 처리했고 총64개 적용. 가속10초/보스유지30초/최대2회/180초간격/첫60초회복 구현.
- 빌드 중 사용자 추가 신고:28 cat_ambush,57 lord_burst2,61 burst_start,64 burst_partial. docs/voice-review-0.10.json에 신고파일 SHA 기록.
- 같은A참조/whole, 새 seed-tag hunter-consistent-repair-v2:로 네 후보 생성 완료. outputs/operator-consistent-repair-010, repo docs/voice-audition/repair-010-candidates. PCM/SHA/길이검사 통과. Resources에는 아직 적용하지 않음.
- 사용자에게 네 후보를 inline오디오로 제공하고 async청취질문 제출. 답변 대기 중. 나머지60개 유지.
- 비교 페이지 http://127.0.0.1:8769/0.10-repair/ (기준1,각번호 새/이전). 전체1~64목록 http://127.0.0.1:8769/0.10/ 은 build11 파일 그대로. 이전 신고번호 선택 보존.
- 다음: 사용자 청취 답변 반영 → 네파일 Resources/Audio와manifest 적용 → 새버전/빌드번호 갱신 →검증/개인M2빌드 → 최종 다운로드 및 설치안내 업데이트.
- 시작안내/아이폰첫테스트는 아직0.9. 최종 음성 빌드 후 갱신할 것.
- 전체 v1 약60% 공수추정. v1-progress-estimate.md 참고.
- 이번 PC종료 요청 없음. 전날1회 종료요청은 이미 완료.
