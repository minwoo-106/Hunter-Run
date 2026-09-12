# Hunter Run — 0.9.0 helpful operator

iPhone audio running RPG. SwiftUI + Core Location + Core Motion + AVFoundation.
Primary field device: user-reported iPhone 17 Pro / iOS 26.6.2.
Minimum deployment target: iOS 17.0 (compatibility target, not a claim of device verification).

## Verified build (0.8.0)
Codemagic demo build 18 completed on 2026-09-12 KST from commit `05a54ce` on Mac mini M2 in 8m 21s.
All 77 core tests and 9 iPhone simulator UI tests passed. The physical-iPhone Release target compiled successfully.
`HunterRun-0.8.0-build9-install.zip` (44.67 MB) contains `HunterRun-0.8.0-build9-unsigned.ipa`.
Packaging verified the outer ZIP, inner IPA, executable, version/build and all 19 designed voice hashes.
[Build and artifacts](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa43fff31f87700ac95bea8). [한국어 설치·첫 테스트 안내](docs/아이폰-첫테스트.md).

## Added in 0.9
- 56 offline voice clips in consistent friendly Korean speech, using the user-approved adult voice reference.
- Named encounter results distinguish real defeats, damage, investigation, withdrawal and recovery.
- Phase-specific guidance for both major bosses and six unlock-gated dispatch summaries.
- Activity captions use the exact selected voice variant; short endurance substitutions use a short hold instruction.
- Local game engine: 84 passing tests. Apple compilation, UI tests and packaging pending for this source revision.
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
- Fifty-six pre-generated designed Korean WAV clips; no runtime TTS or server.
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
