# Hunter Run 변경 기록

버전별 구현·검증·설치 기록입니다. 게임 소개와 현재 기능은 [README](README.md)에서 확인할 수 있습니다.

## 1.5.0 — 현장 게이트 추적과 보스 재현

일반 게이트를 현장 사냥의 추적 사건으로 옮기고, 추적한 야외 활동 두 번 안에 출현하도록 했습니다. 일반 게이트는 한 활동에서 해결하며 철수 시 재접근할 수 있지만 핵심 개체 HP는 새로 시작합니다. 고위험 게이트는 대상이 확인된 주요 보스 공략과 전투 재현에 사용합니다.

과거 게이트 실적은 그대로 보존하고, 새 활동에서는 일반 게이트 해결과 주요 보스 첫 토벌만 승급용 실적을 줍니다. 승급 심사·잔향 재현·변이 재현의 보상과 스토리 판정을 분리했습니다. 강해솔과 선발대는 반복 전투 대상에서 제외했습니다. 기존 진행 중인 활동은 구버전 규칙으로 마무리합니다.

[1.5.0 설치·확인 안내](docs/1.5.0-release.md) · [게이트 진행량 예상](docs/gate-progression-estimate.md)

## 1.4.4 — 이후 토벌 기회 보존

첫 늑대뿐 아니라 이후 야외 사냥의 몬스터·보스도 등장 예정 순간에 잠깐 걷거나 GPS가 약해졌다는 이유만으로 조사로 소모되지 않습니다. 일반 조우는 최대 90초 동안 달리기와 양호한 신호를 기다리고, 계속 걷는 경우 조사로 전환합니다. 진행 중인 일반 전투는 잠깐의 GPS 저하에서 판정을 멈췄다가 회복되면 이어가며, 장시간 신호가 없으면 피해 없이 종료합니다. 가속 판정은 신호가 약해지는 즉시 안전하게 취소합니다. 선택한 일반 의뢰는 계속 평소 활동과 함께 진행되고, 승급 심사만 별도 보스전으로 진행됩니다.

[1.4.4 설치·확인 안내](docs/1.4.4-release.md)

## 1.4.3 — 야외 운동시간과 첫 토벌 수정

야외 활동의 시간 목표와 평균 페이스를 일시정지를 제외한 운동시간으로 계산합니다. 20분 목표는 잠깐 정지한 구간이 있어도 일시정지를 제외한 20분에 자동 종료하며, 실제 움직인 시간은 보상 판정용으로 따로 유지합니다. 위치 속도가 여러 초 동안 안정적으로 달리기를 가리키면 iPhone의 늦은 걷기 판정을 보정합니다. 잔향 늑대 의뢰를 추적 중인 현장 사냥에서는 첫 토벌 기회를 보장하고, 일시적인 걷기·GPS 저하가 그 기회를 흔적 조사로 소모하지 않도록 했습니다. 기존 저장 데이터와 과거 활동 기록은 유지합니다.

[1.4.3 설치·확인 안내](docs/1.4.3-release.md)

## 1.4.2 — 시작 화면과 전환 연결 수정

승인된 공명문 시작 화면을 실제 iPhone 앱에 연결했습니다. 화면을 터치하면 안개와 공명원이 움직이며 게이트 안으로 진입하고 홈 화면으로 이어집니다. 화면 이동 연출이 상단 안전 영역과 하단 메뉴까지 덮도록 수정하고, 홈 전환 때 이전 화면이 잠깐 보이던 타이밍을 고쳤습니다. 운동 측정, 보상, 저장 데이터는 변경하지 않았습니다.

[1.4.2 설치 안내](docs/1.4.2-release.md)

## 1.4.1 — 화면별 배경과 이동 연출

홈으로 돌아올 때 미니 오퍼레이터가 업무, 커피, 햄버거, 노트북 닫기, 짧은 졸음을 순서대로 보여줍니다. 헌터 기록은 장비실의 빛과 카메라 이동, 헌터 활동은 미궁 게이트, 협회 관리는 무거운 문 개방, 도감은 야수와 서큐버스가 그려진 두루마리 전환을 적용했습니다. 헌터·협회·도감의 기본 배경도 해당 공간으로 바꿨습니다. iPhone의 동작 줄이기 설정을 켜면 화면 전환을 즉시 마칩니다. 운동 측정과 저장 데이터 구조는 바꾸지 않았습니다.

[1.4.1 설치 안내](docs/1.4.1-release.md)

## 1.4.0 — 시즌 1 이야기와 인물 연출

확정된 시즌 1 원고를 M01~M21 장면에 반영하고, 초기 선택이 후반 대사에 다시 나타나도록 했습니다. 이야기의 세부 내용은 공개하지 않습니다. 강해솔의 승인된 음성 16개와 오퍼레이터의 새 음성 23개를 해당 장면과 활동에 연결했으며, 두 인물의 새 초상과 후반 시설 이미지를 적용했습니다. 사용자 요청에 따라 놀라는 음성 H17은 포함하지 않았습니다.

마지막 작전에서 GPS가 일시적으로 불안정하면 확인된 걸음 데이터로 안전한 유지 구간을 진행하고, 움직임도 확인되지 않으면 사건 상태를 보존한 채 일시정지합니다. 기존 활동 기록·선택·보상은 유지하며, 이전 버전에서 진행 중이던 대화만 해당 장면의 처음부터 다시 보여줍니다. 거리·평균 페이스의 일반 측정 방식은 변경하지 않았습니다.

[1.4.0 설치 안내](docs/1.4.0-release.md)

## 1.3.11 — 인물과 선택의 회수

초반에 등장하는 인물의 일상과 지부의 오래된 공간에 관한 장면을 추가했습니다. 초기 미스터리와 후반 사건의 연결도 강화했습니다. 몇몇 선택은 결말을 바꾸지 않으면서 후반 대화에 다시 등장합니다. 기록 속 인물의 발화는 출처와 화면 이미지를 구분해 보여줍니다. 1.3.10 이전의 저장 데이터에 선택 기억이 없어도 기본 대사로 자연스럽게 이어집니다. 구체적인 전개는 스포일러 방지를 위해 공개하지 않습니다. 운동 측정 로직은 그대로입니다.

[1.3.11 설치 안내](docs/1.3.11-release.md) · [Codemagic 빌드 #52](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aba129d3f90aeed966c4538?open-setting=build-artifacts)

## 1.3.10 — 초중반 이야기 연결

초기 관제실부터 상위 게이트 조사까지 협회 1위 헌터와 미귀환 원정에 관한 단서를 단계적으로 추가했습니다. 후반 작전은 대상의 정체를 알고 준비하는 흐름으로 다듬었습니다. 이야기의 구체적인 전개는 해금 전까지 공개하지 않습니다. 기존 장면의 대화 노드 ID와 저장 진행도를 유지하며, 운동 거리·시간·페이스 계산은 1.3.9와 동일합니다.

[1.3.10 설치 안내](docs/1.3.10-release.md) · [Codemagic 빌드 #51](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aba0bfb3f90aeed966c17e1?open-setting=build-artifacts)

## 1.3.9 — 강해솔 캐릭터 아트

후반 인물의 이름과 빛의 이미지에 맞춰 관련 대사를 다듬었습니다. 새로운 평상시 초상과 머리 묶기·호기심·벌레에 놀란 모습 네 장을 추가했습니다. 모든 일상 이미지는 해당 이야기의 진행 뒤에만 보이며, 전투 중 모습은 유지했습니다. 기존 1.3.8 저장 데이터의 이야기 진행도와 시설 완료 상태도 유지합니다.

[1.3.9 설치 안내](docs/1.3.9-release.md) · [Codemagic 빌드 #50](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aba00e53f90aeed966bd739?open-setting=build-artifacts)

## 1.3.8 — 홈·권한 정리와 새 이야기

홈에서 새 귀환 보고를 한 번 열면 읽음으로 저장하고 버튼을 숨깁니다. 위치 권한 확인은 설정으로 옮겼으며 야외 활동 시작 때 권한이 없으면 다시 안내합니다. 기존 1.3.7의 페이스·시간 수정은 유지합니다.

기존 본편 이후 새로운 이야기 다섯 장을 추가했습니다. 각 장은 실제 선발대 전투, 주요 토벌, 협회 시설의 진행도에 맞춰 열립니다. 마지막 시설은 일회성으로 가동하며 보상·자원을 반복 지급하지 않습니다. 등장 인물의 별도 초상은 장면이 열릴 때만 나타납니다. 줄거리는 여기서 공개하지 않습니다.

[1.3.8 설치 안내](docs/1.3.8-release.md) · [Codemagic 빌드 #49](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6ab9f69d3f90aeed966b9db3?open-setting=build-artifacts)

## 1.3.7 — 야외 페이스와 경과시간 표시

애플워치와 함께 측정한 실외 걷기에서 헌터런의 이동시간 57:58과 전체 경과 1:01:34가 혼동되는 문제를 확인했습니다. 야외 활동 화면과 기록에 **경과시간**과 **움직인 시간**을 분리해 표시하고, 전체 평균 페이스를 경과시간 기준으로 계산합니다. 기존 기록은 경과시간이 저장되지 않았으므로 이동시간 기준 평균임을 명시합니다. 보상·사건 판정에 쓰는 움직인 시간은 그대로 유지합니다.

현재 페이스는 흔들리는 순간 GPS 속도 대신 최근 약 40초의 인정된 이동 거리로 계산합니다. 일정한 거리를 걷지만 GPS 속도가 8~20분/km로 진동하는 재현 테스트를 추가했습니다. 수신된 좌표 거리와 위치 속도 적분을 비교할 수 있는 **좌표 없는 집계 진단**도 추가했습니다. 5.38km 대 5.11km 거리 차이는 현재 자료만으로 어느 기기의 오차인지 특정할 수 없어 거리 수치를 임의 보정하지 않았습니다. 실기기 재측정이 필요합니다.

**build37 걷기 판정 수정:** 동작 센서가 걷기라고 분류한 구간을 순간 GPS 속도 때문에 달리기로 바꾸지 않습니다. 1시간 걷기 기록에 ‘학습 가능 달리기 8:02’가 표시된 문제를 재현해 수정했습니다. 이전 활동에서 잘못 학습된 참고 페이스는 자동 삭제하지 않으므로, 실제로 달리지 않았는데 참고값이 생겼다면 헌터 → 나의 활동 기준에서 한 번 초기화할 수 있습니다.

[1.3.7 설치·재측정 안내](docs/1.3.7-release.md) · [Codemagic 빌드 #48](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6ab9e3e33f90aeed966b3851?open-setting=build-artifacts)

## 1.3.6 — 선발대·상위 장비 성장

**build34 음성 수정:** 사용자가 지적한 7개 조우·조사·보스 대사를 같은 오퍼레이터 참조 목소리로 다시 합성했습니다. 각 파일의 시작·끝 음색 유사도를 비교해 일관된 후보를 골랐고, 거울마녀의 유지 공격 안내를 더 자연스럽게 다듬었습니다. 42개 새 대사의 번호별 미리듣기를 갱신했습니다.

신규 개체 9종과 장비 4종, 오퍼레이터 음성 42개를 추가했습니다. 일반 개체의 흔적 조사, 고유 강적의 실제 토벌, 선발대 네 사람의 정화가 상위 장비와 마지막 장기 토벌로 이어집니다. 월영·몽환 준비 장비는 유지하고 각 보스 토벌 뒤 여는 방어구·신발을 별도로 배치했습니다. 장비 목록에 성능 단계를, 상세 화면에 현재 장비와의 능력치 차이를 표시합니다. 오퍼레이터 초상에는 작은 시선 이동과 고개 기울임을 더했습니다.

[1.3.6 설치·음성 미리듣기 안내](docs/1.3.6-release.md) · [새 음성 42개 미리듣기](docs/voice-review-1.3.6/index.html)

버전 1.3.6/build34은 기존 1.3.5의 야외 거리·페이스 센서 판정 코드를 유지합니다. 코어 테스트 161개와 콘텐츠·음성 177개 검증을 통과했으며, iPhone 실기기에서 새 전투 동선과 음색은 확인이 필요합니다.

## 1.3.5 — 야외 거리·평균 페이스 수정

정상적인 Core Location 묶음 좌표를 최대 30초까지 보존하고, 거리 상한을 콜백 도착 간격이 아니라 실제 GPS 구간 시간으로 계산합니다. 비정상적인 순간이동·차량 속도·긴 전달 공백은 계속 제외하며, 활동 평균 페이스는 복구된 누적 거리로 계산합니다.

[Codemagic build 43에서 1.3.5 받기](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6ab344fe50d35310b24e5777?open-setting=build-artifacts) · [한국어 변경·설치 안내](docs/1.3.5-release.md) · [검증 기록](docs/release-135-verification.json)

`ea5597f` 소스에서 만든 1.3.5/build32를 검증했습니다. 코어 테스트 158개와 두 화면 크기에서 각각 4개의 UI 테스트가 통과했고, 설치 ZIP·IPA·arm64 실행 파일 및 음성 135개의 해시도 확인했습니다. 기존 앱 위에 설치하면 진행 데이터는 유지됩니다.

## 1.3.4 release record

Kilometer voice repair: 2 km and 9 km hunt calls retain their original first sentence and remove the voice-shifting ending. The 3 km exploration call now asks players to move comfortably.

[Download 1.3.4 from build42](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6ab0fa9fdcbe25a2513d6bed?open-setting=build-artifacts) · [한국어 변경·설치 안내](docs/1.3.4-release.md) · [Verification](docs/release-134-verification.json)

Verified 1.3.4/build31 from `48a1d1c`: 154 core tests and four focused UI checks on each screen size passed. The ZIP/IPA, executable and all 135 voice hashes passed package verification. Install over the existing app to retain progress.

## 1.3.3 release record

Outdoor activities show a smoothed current pace and whole-activity average pace. The operator announces each confirmed kilometer: distinct exploration and hunting lines for 1–10 km, then a repeatable extra-kilometer line. Indoor running does not claim GPS distance or pace.

[Download 1.3.3 from build41](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6ab0f340688764aa17d9a534?open-setting=build-artifacts) · [한국어 변경·설치 안내](docs/1.3.3-release.md) · [Verification](docs/release-133-verification.json)

Verified 1.3.3/build30 from `0d88e3c`: 154 core tests and four focused UI checks on each screen size passed. The installer ZIP/IPA, executable, and all 135 voice hashes passed package verification. Physical outdoor pace and voice timing still require an iPhone field test. Install over the existing app to retain progress.

## 1.3.2 release record

Ordinary assignments accompany the chosen activity mode. Focused navigation separates preparation, quests, weekly outdoor surveys and facilities. Adds contextual return briefings, three weekly beacons and four post-clear boss patterns.

[Download 1.3.2 from build40](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6ab0dd26688764aa17d95f80?open-setting=build-artifacts) · [한국어 변경·설치 안내](docs/1.3.2-release.md) · [Verification](docs/release-132-verification.json) · [1.3.0 design](docs/1.3.0-expedition-design.md)

Verified 1.3.2/build29 from `b435ff6`: 153 core tests and three focused UI checks on each screen size passed. The build validated the ZIP/IPA, executable, and all 113 voice hashes. Activities shorter than three active minutes no longer persist records, rewards or progression. Outdoor signal classification uses position quality independently of velocity quality; physical iPhone field validation remains necessary. Update over the existing app to retain progress. Indoor 50% recurring rewards and daily 60-minute quota are preserved.

## 1.2.2 release record

Unified indoor running with 50% activity rewards and a shared daily 60-minute active-time limit. The day resets at Korean midnight; outdoor free activity remains unrestricted.

[Download 1.2.2 from build34](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa6b0b5688764aa17be873e?open-setting=build-artifacts) · [한국어 변경·설치 안내](docs/1.2.2-release.md) · [Policy](docs/1.2.2-policy.md) · [Verification](docs/release-122-verification.json) · [후속 확장 제안](docs/outdoor-next-direction.md)

Verified 1.2.2/build23 from source `83b5369`: Codemagic build34 succeeded in 13 minutes. 140 core tests, five iPhone 17 Pro UI checks and three compact-screen checks passed. The downloaded installer passed ZIP/IPA, arm64, launch-image and 113 audio hash verification. Install over the existing app to retain progress. Physical movement sensitivity uses the existing indoor sensor implementation.

## 1.2.0 release record

Phone-only indoor activity and contextual operator conversations. Built as 1.2.0/build21 by Codemagic build32 from `8dcbfd3` on 2026-09-13.

[Download 1.2.0 from build32](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa69ff5c12cd81c2be0fe8c?open-setting=build-artifacts) · [한국어 변경·설치 안내](docs/1.2-release.md) · [Verification record](docs/release-120-verification.json)

- Activity environment offers outdoor and unified indoor running (stationary exercise or treadmill). Indoor progress uses detected movement and active time without GPS distance or pace; Apple Watch is not required.
- Existing quests, boss campaigns, rewards and rank progression continue indoors. Outdoor pace learning remains separate.
- Real movement preflight, permission checks and explicit pause on background/lock prevent unattended timer-only activity. Phone must be carried; physical grip/gait sensitivity needs device feedback.
- Operator dialogue uses a portrait scene, one current line and two or three contextual replies. Relationship records move to the book control. Title subtitle contrast is improved.
- 128 core tests, 11 focused iPhone 17 Pro UI tests and six compact-screen tests passed. ZIP/IPA, arm64, launch-image and all 113 approved voice hashes were verified in the downloaded installer. UI motion activity is exercised through an isolated Debug harness; no simulated activity entry exists in Release.

Install `HunterRun-1.2.0-build21-unsigned.ipa` through AltStore over the existing app to retain progress. This remains personal installation, not App Store publication.

## 1.1 release record

Labyrinth interface release, built as 1.1.0/build19 by Codemagic build30 from `2097d25` on 2026-09-13. Adds a tap-to-enter title screen, portrait dialogue stages, and a shared dungeon visual treatment for non-home screens while preserving the home composition and game data.

[Download 1.1.0 from build30](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa68faa688764aa17be37ce?open-setting=build-artifacts) · [한국어 변경·설치 안내](docs/1.1-release.md) · [Verification record](docs/release-110-verification.json)

119 core tests, content validation, seven focused iPhone 17 Pro UI tests and five 375×667 compact UI tests passed. The downloaded installer passed ZIP/IPA, arm64, launch-image and all 113 voice hash checks. Install `HunterRun-1.1.0-build19-unsigned.ipa` through AltStore; updating the existing app preserves progress. UI testing here is simulator-based.

## 1.0 release record

Native iPhone walking/running RPG. Version 1.0.0/build14 was compiled and packaged by Codemagic build25 from `edf84fc` on 2026-09-13. The downloaded installer passed archive, arm64 executable, story/content and all 113 voice hash checks.

[Download 1.0.0 from build25](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa66847c12cd81c2be084ae?open-setting=build-artifacts) · [Spoiler-free release guide](docs/1.0-release.md) · [Verification record](docs/release-100-verification.json)

119 core tests, 13 iPhone 17 Pro UI tests, three iPhone 17 checks and three additional 375×667 compact-screen checks passed. Portrait expression, closed-eye and breathing renders were inspected. Physical outdoor pace, interruptions and the new voice clips still need user-device feedback; this is not an App Store publication claim.

- Offline main story and operator conversations, custom partner names, remembered choices and relationship progression.
- Persistent quests, rank exams and time-based qualifications; existing saves retain their equipment and history.
- Animated operator breathing/blinking and six dialogue expressions; five association growth backgrounds.
- 17 creatures, 32 equipment items, 113 offline voice cues, original UI sound effects.
- Exploration, contracts and gate combat with optional short accelerations, accumulated boss damage and neutral walking alternatives.
- Production has no simulated activity entry. Dedicated Debug simulator tests retain an isolated harness.
- Collections, backup/import/reset and on-device data guidance.

Distribution remains the existing private Codemagic/AltStore route. Version 1.0 does not imply App Store publication.

## Previous release record

# Hunter Run — 0.11 field encounters and discovery gear

iPhone audio running RPG. SwiftUI + Core Location + Core Motion + AVFoundation.
Primary field device: user-reported iPhone 17 Pro / iOS 26.6.2.
Minimum deployment target: iOS 17.0 (compatibility target, not a claim of device verification).

## 0.11 expansion
- Four illustrated creatures: dark-elf scout/captain and succubus weaver/warden.
- Eight discovery-linked equipment items, with individual artwork; all four departments can reach Lv.3.
- Saved encounter alternatives rotate across patrols while retaining gate objectives and investigation-only exploration.
- A public field board and targeted mock activities let players preview locked creatures without unlocking real rewards.
- Sixteen new operator recordings; the 64 previously approved WAVs remain byte-for-byte unchanged.
- 101 portable core tests and content/80-audio hash validation passed locally. Apple build23 also passed all101 core and10 UI checks.
[0.11 field guide](docs/0.11-월영과-몽환.md).

## Verified build (0.11.0)
Codemagic demo build23 completed on2026-09-12 KST from commit `b5e4529` on Mac mini M2 in7m48s.
All101 core tests and10 iPhone simulator UI tests passed, including field mock completion and subsequent story playback controls. Physical-iPhone Release compilation succeeded.
`HunterRun-0.11.0-build13-install.zip` (79.11MB) contains `HunterRun-0.11.0-build13-unsigned.ipa`.
Packaging verified ZIP/IPA integrity, version/build, executable and all80 voice hashes.
[Build and artifacts](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa51cfe6d07de75e140b03f). [한국어 설치 안내](docs/시작안내.md).

## Added in 0.10.1
- User-approved replacements for clips 28, 57, 61 and 64; the other 60 files are unchanged.
- Clip 28 has its last 0.5 seconds removed at a quiet boundary, eliminating the reported trailing sound.
- Verified installer: build21,93 core and9 UI checks passed.

## Added in 0.10
- User-selected A narration method for the 14 flagged recordings and revised/new lines; no “우와” in current dialogue.
- Optional ten-second pursuits and boss barrier attacks, with four-second intent confirmation included in those ten seconds.
- Thirty-second steady boss alternatives, two bursts per activity, 180-second intervals and 60-second easy investigation periods.
- Mixed burst/steady attacks in every phase of both bosses, remaining-effort/recovery UI and a 20-minute boss mock activity.
- Pause and save recovery preserve the remaining effort and intensity budget. All 93 core and 9 Apple UI tests passed in build20. The four follow-up recordings were approved and applied in0.10.1.
[0.10 field guide](docs/0.10-가속과-음성.md), [v1 progress estimate](docs/v1-progress-estimate.md).

## Added in 0.9
- 56 offline voice clips in consistent friendly Korean speech, using the user-approved adult voice reference.
- Named encounter results distinguish real defeats, damage, investigation, withdrawal and recovery.
- Phase-specific guidance for both major bosses and six unlock-gated dispatch summaries.
- Activity captions use the exact selected voice variant; short endurance substitutions use a short hold instruction.
- Local and Apple game engine: 84 passing tests; 9 simulator UI tests, Release compilation and all bundled voice hashes verified.
[0.9 dialogue and test guide](docs/0.9-오퍼레이터-대사.md).

## Added in 0.8
- Approved original operator voice: 19 local WAVs, including three pairs of alternating equivalent lines.
- Large-eyed young adult operator with navy hair streaks and true transparent cutout.
- 400m endurance battles and 25-second ambush responses; short goals use a brief hold.
- Deterministic patrol timing variation with recovery stability and canonical codex identities.
- Recovery-period combat suppression, encounter guide and 20-minute mock contract.
- Versioned installer filenames and verification of all bundled voice hashes.
- Local validation: 77 core tests and content/audio checks passed.
[0.8 test guide](docs/0.8-현장-테스트.md).

## Added in 0.7
- Bottom navigation: home / hunter / large central hunter activity / association / codex.
- Removed the large activity card on home; settings are a 44pt gear below the profile/rank.
- Disable automatic screen lock only during foreground unfinished activities, including pause; normal locking resumes on results/home/background. Physical-device lock behavior still needs testing.
- Existing temporary voice remains in the app. Rejected stock presets A–E were excluded. Original VoiceDesign auditions were generated locally; the user prefers the brighter gentle revision and is discussing character presentation.
[0.7 테스트](docs/0.7-음성과-메뉴.md), [오퍼레이터 방향](docs/operator-voice-direction.md).

## Added in 0.6
- Lobby BGM continues through activity preparation and stops on actual/mock activity start.
- Hunter activity entry with exploration, contract, gate investigation and boss-hunt start labels.
- Personal pace reference from eligible real sessions: at least five minutes of good-GPS stable running, excluding events and post-combat recovery. Last-five median with a 5% per-session change limit; today's slower baseline takes priority.
- Reference/reset screen and per-activity observation reports; legacy saves retained, simulations excluded from learning.
- Recent pace display uses a time-weighted 12-second window with bounded changes, clears on stops/pause/unreliable GPS and restarts from fresh data. Raw gameplay, distance and time values are unchanged.
Validation: 68 core tests, 8 iPhone UI tests, Release compilation, resource validation and installer integrity passed in verified build 16. Physical-device pace/audio follow-up remains necessary.
[한국어 0.6 테스트](docs/0.6-활동-테스트.md), [pace display regression](docs/pace-display-regression.md).

## Added in 0.5
- Continuous lobby BGM across home, hunter/equipment, archive, menu and association. RUN setup and active/result screens stay silent for BGM.
- Four skippable welcome pages with optional permission/audio actions; existing saves are not forced through onboarding.
- Six readable operator dispatches unlocked in order by real activities, facilities and the boundary boss.
- Saved read markers, unread count on home, and the next story requirement in the archive.
- No reading rewards; simulations cannot unlock real story progress. Original operator/room artwork reused.
Validation: all 51 core tests and seven UI tests passed in the verified Apple build.
[한국어 0.5 테스트](docs/0.5-통신-테스트.md), [BGM regression](docs/bgm-navigation-regression.md).

## Added in 0.4
- Large home RUN CTA and a slightly larger central association-management control.
- Two persistent bosses with three HP phases, per-run settlement and manually opened new rounds.
- Seven monster illustrations, discovery-gated archive and research-based combat analysis.
- Three association backgrounds based on 0/2/4 upgraded departments.
- Original 32-second synthesized lobby BGM sketch; foreground home/association only, with saved controls.
- Boss mock preparation before unlock; real HP and rewards remain unchanged in simulation.
Validation: 43 core tests and 6 simulator UI tests passed in the verified Apple build.
[한국어 0.4 테스트](docs/0.4-토벌-테스트.md).

## Added in 0.3
- Association management home CTA and an emphasized central RUN control.
- Twelve individually generated equipment illustrations, details, owned filter and loadout view.
- Time, distance (1/3/5/10 km), and manually ended free activities.
- Recurring 20-active-minute patrols for distance/free goals, stable archive identities and per-run core caps.
- Activity journal with filters, total distance/count and per-run goal/event/reward details.
- In-app field guide and old-save goal fallback.
[한국어 0.3 테스트](docs/0.3-현장-테스트.md), [goal rules](docs/activity-goals.md), [art direction](docs/equipment-art-direction.md).

## Included now
- Native association home based on the approved earpiece operator concept.
- Exploration, contract and progression-gated high-risk gate mission profiles.
- 5/20/30-minute real runs, unlockable 45-minute goals, and a 3-minute simulated run.
- GPS + motion + pedometer inputs; uncertainty suspends precision scoring.
- Foreground-started background location session; intermittent local voice playback.
- Sixty-four pre-generated designed Korean WAV clips; no runtime TTS or server.
- Pause/resume, goal completion, local progress, recovery, import/export, basic field archive.
- Mock speed/movement/GPS controls and a non-destructive recovery drill.
- Pure Swift engine tests including stop protection, replay, gap, and settlement invariants.

## Progression in 0.2
- Twelve equipment items across weapon, armor, shoes and relic slots; purchases and loadouts.
- Four departments with one functional upgrade each: gate access, analysis, advanced equipment, extended contracts.
- Rank evaluation using level, completed goals and boss records; no XP-only automatic promotion.
- Mode-specific research/crystal rewards and boss cores; simulation cannot award progression.
- Legacy save decoding and saved run loadout/mission snapshots.
[한국어 성장 테스트](docs/0.2-성장-테스트.md), [design and persistence](docs/progression-design.md).

## Not yet implemented
Expanded voiced story/content, further operator performance polish,
polished audio production and production balancing.
This is a playable progression milestone, not content-complete v1. See [remaining work](docs/v1-remaining.md).

## Build (macOS / Codemagic)
1. Place this folder's contents at the ROOT of the linked repository.
2. Run the `ios-demo` workflow in `codemagic.yaml`.
3. It validates resources, runs Swift tests, generates the Xcode project, compiles
   the actual iPhone target, and packages a versioned `HunterRun-0.8.0-build9-unsigned.ipa`.
4. The IPA is UNSIGNED and cannot be installed by tapping a download link.
   Use personal signing via AltStore Classic / AltServer on Windows.
5. No Apple developer credentials are needed by this build workflow.
   Do not enable paid billing to run this demo; use available personal M2 minutes.

The cloud workflow has a 30-minute cap and no automatic triggers.
No TestFlight upload, App Store publication, analytics, or payment integration is configured.
An uploaded build still needs a real-device install and field test.

## Local logic tests (Linux/macOS with Swift 5.9+)
```sh
swift test
python3 scripts/validate.py
```
Linux tests do not validate Apple framework compilation or real sensor behavior.

## First iPhone test
See [docs/TESTING.md](docs/TESTING.md). Start with 5 minutes and pursuit OFF.
Audio files are locally generated Korean operator speech from the user-approved synthetic reference. No runtime TTS or paid API is used.

## Design
Approved operator: original earpiece pose, white shirt, dark tie, calm office atmosphere.
Home uses separate transparent operator and office layers. Additional expressions are a later pass.
SwiftUI renders text/buttons; the UI is not a stretched screenshot.

## Data
Saves are local, with atomic writes and a previous valid snapshot.
Mock sessions cannot grant real rewards. Exact raw coordinates are not saved.
Save import replaces progress and requires confirmation in the UI.
Do not place personal saves, signing credentials, or tokens in this repository.
