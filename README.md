# Hunter Run 1.2.2

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
