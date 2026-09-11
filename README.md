# Hunter Run — 0.1 technical demo

iPhone audio running RPG. SwiftUI + Core Location + Core Motion + AVFoundation.
Primary field device: user-reported iPhone 17 Pro / iOS 26.6.2.
Minimum deployment target: iOS 17.0 (compatibility target, not a claim of device verification).

## Included now
- Native association home based on the approved earpiece operator concept.
- One assignment with discovery, maintain, optional pursuit, and gate stabilization.
- 5/20/30-minute real runs and a 3-minute simulated run.
- GPS + motion + pedometer inputs; uncertainty suspends precision scoring.
- Foreground-started background location session; intermittent local voice playback.
- Fourteen pre-generated temporary Korean WAV clips; no runtime TTS or server.
- Pause/resume, goal completion, local progress, recovery, import/export, basic field archive.
- Mock speed/movement/GPS controls and a non-destructive recovery drill.
- Pure Swift engine tests including stop protection, replay, gap, and settlement invariants.

## Not yet implemented
Full v1 equipment, four association departments, three modes, persistent major bosses,
long-term pace learning, distance/free goals, full art/audio library and production balancing.
The 5-minute real run is for technical checks, not a completed v1 experience.

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
