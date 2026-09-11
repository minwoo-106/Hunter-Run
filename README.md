# Hunter Run — 0.4.0 world and boss demo

iPhone audio running RPG. SwiftUI + Core Location + Core Motion + AVFoundation.
Primary field device: user-reported iPhone 17 Pro / iOS 26.6.2.
Minimum deployment target: iOS 17.0 (compatibility target, not a claim of device verification).

## Previous verified build (0.3.0)
Codemagic demo build 8 completed on 2026-09-11 from commit `51c061f` on Mac mini M2 in 6m 33s.
All 31 core tests and 4 iPhone UI tests passed. The iPhone app compiled and packaged successfully.
`HunterRun-install.zip` (23.50 MB) contains the unsigned IPA; archive integrity and the inner app executable/Info.plist were verified during the build.
[Build and artifacts](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa3af69107aa975edb5028c).
On the 402 × 874 point iPhone simulator, the association CTA stays within 20-point horizontal margins and the home version label ends at y=742 above the central RUN at y=768. UI tests also cover equipment artwork/details, goal selection, guide access and progression locks.
Earlier device installation, corrected home layout, and voice playback through speaker and AirPods were confirmed by the user. The user confirmed 0.3.0 installation and equipment artwork; further field behavior remains subject to testing.
[한국어 설치·첫 테스트 안내](docs/아이폰-첫테스트.md).

## Added in 0.4
- Large home RUN CTA and a slightly larger central association-management control.
- Two persistent bosses with three HP phases, per-run settlement and manually opened new rounds.
- Seven monster illustrations, discovery-gated archive and research-based combat analysis.
- Three association backgrounds based on 0/2/4 upgraded departments.
- Original 32-second synthesized lobby BGM sketch; foreground home/association only, with saved controls.
- Boss mock preparation before unlock; real HP and rewards remain unchanged in simulation.
Core tests: 41 passed locally. Current iOS build/UI validation pending.
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
Onboarding, long-term pace learning, expanded story/content, final operator voice,
polished audio production and production balancing.
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
