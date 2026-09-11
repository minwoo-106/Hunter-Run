# 0.7.0 UI 배포 준비 완료 · 오퍼레이터 음색 조율 중

## 빌드
- 소스 53e28a9, Codemagic 17번 무료 개인 M2, 9분 51초 완료.
- 로직 68개 / iPhone UI 8개 모두 통과, Release 컴파일 및 ZIP 내부 IPA 무결성 검증 완료.
- HunterRun-install.zip 43.69 MB. https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa432a01c8c285ff0061c1a
- 추가 빌드 진행 없음. 자동 잠금과 오디오 실기기 후속 확인 필요.

## 구현 완료
- 하단 홈/헌터/중앙 큰 헌터 활동/협회 관리/도감.
- 홈 큰 활동 카드 제거, 이름·등급 아래 설정 톱니바퀴.
- 활동 중(일시정지 포함)에만 자동 잠금 방지, 결과/홈/앱 비활성에서는 정상 동작.
- 설정 닫기와 첫 이용 안내 재표시 경로 수정.

## 음성 피드백과 다음 작업
- Supertonic3 기본 F1~F5(A~E) 모두 거절. WAV는 outputs/voice-audition-round1, round2에 보존하며 앱에서 제외.
- Qwen3-TTS VoiceDesign 새 음색은 훨씬 좋다는 피드백. clear의 자연스러운 숨소리 선호, velvet은 힘없어 제외.
- clear 기반 밝은 조정 1번 bright_gentle을 매우 선호. 파일: outputs/voice-designed-brighter/operator_bright_gentle.wav (13.67초).
- 사용자 최신 질문: 목소리를 더 성숙하게 vs 캐릭터 외형을 더 귀엽게. 답변/제안: 1번 목소리 유지, 기존 성인 캐릭터 복장·정체성을 유지하고 눈매·미소를 조금 밝게. 아직 이미지 편집 요청 확정/실행 없음.
- 앱에는 기존 임시 음성 14개 유지. 새 음색으로 핵심 안내팩 생성과 적용은 아직 미완료.
- 다음: 디자인 방향 합의 후 선호 자체 생성 참조 음색을 Base 모델로 일관되게 14문장에 적용, 실제 청취/문장 길이 확인, 이후 v1 대사 확장.

## 재현 환경
- Python work/qwen-voice-env (torch2.11+cu128, qwen-tts0.1.1), RTX3070 8GB.
- VoiceDesign work/qwen-voice-design revision 5ecdb67327fd37bb2e042aab12ff7391903235d3.
- Base work/qwen-voice-base revision fd4b254389122332181a7c3db7f27e918eec64e3 다운로드 완료.
- scripts/design-operator-voice.py --round initial / brighter. 출력 manifest에 지시문·시드·대사·체크섬.
- 생성은 GPU 오프라인, 유료 API/결제 없음. 파일 PCM 검사와 청취 평가는 구분.
- 상세 방향: docs/operator-voice-direction.md.

## 브라우저
Codemagic 버튼 오류 시 Applications 목록 AX Start new build → main → ios-demo를 선택합니다. 동일 버전을 중복 빌드하지 않습니다.
