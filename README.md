# Hunter Run — 0.2.0 progression demo

iPhone audio running RPG. SwiftUI + Core Location + Core Motion + AVFoundation.
Primary field device: user-reported iPhone 17 Pro / iOS 26.6.2.
Minimum deployment target: iOS 17.0 (compatibility target, not a claim of device verification).

## Verified build
Codemagic demo build 6 completed on 2026-09-11 from commit `d503224` on Mac mini M2 in 4m 30s.
All 23 core tests and 2 iPhone UI tests passed. The iPhone app compiled and packaged successfully.
`HunterRun-install.zip` (7.10 MB) contains the unsigned IPA; archive integrity and the inner app executable/Info.plist were verified during the build.
[Build and artifacts](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa38c51d8c577d2313b50c1).
UI tests used an iPhone 17 Pro simulator on iOS 26.5. [Earlier overflow regression](docs/layout-regression.md).
The user confirmed 0.1.1 installation, corrected home layout, and voice playback through speaker and AirPods.
0.2.0 installation and field behavior still require device testing.
[한국어 설치·첫 테스트 안내](docs/아이폰-첫테스트.md).

## Included now
- Native association home based on the approved earpiece operator concept.
- Exploration, contract and progression-gated high-risk gate mission profiles.
- 5/20/30-minute real runs, unlockable 45-minute goals, and a 3-minute simulated run.
- GPS + motion + pedometer inputs; uncertainty suspends precision scoring.
- Foreground-started background location session; intermittent local voice playback.
- Fourteen pre-generated temporary Korean WAV clips; no runtime TTS or server.
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
Persistent major bosses, onboarding, long-term pace learning, distance/free goals,
full monster/equipment art, association visual stages, final voice/BGM and production balancing.
This is a playable progression milestone, not content-complete v1.

## Build (macOS / Codemagic)
1. Place this folder's contents at the ROOT of the linked repository.
2. Run the `ios-demo` workflow in `codemagic.yaml`.
3. It validates resources, runs Swift tests, generates the Xcode project, compiles
   the actual iPhone target, and packages `HunterRun-unsigned.ipa`.
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
Audio files are temporary Windows-generated Korean speech for personal demo evaluation;
replace with an approved operator voice and review distribution rights before public release.

## Design
Approved operator: original earpiece pose, white shirt, dark tie, calm office atmosphere.
Home uses separate transparent operator and office layers. Additional expressions are a later pass.
SwiftUI renders text/buttons; the UI is not a stretched screenshot.

## Data
Saves are local, with atomic writes and a previous valid snapshot.
Mock sessions cannot grant real rewards. Exact raw coordinates are not saved.
Save import replaces progress and requires confirmation in the UI.
Do not place personal saves, signing credentials, or tokens in this repository.
