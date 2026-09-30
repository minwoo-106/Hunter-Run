# Validated PoC — 2026-09-30

Compiled implementation: `2350984cb139853947eb8348612ecc16457b8278`.
Successful [build and UI verification](https://github.com/minwoo-106/Hunter-Run/actions/runs/36685240440).
This branch is a separate prototype; it has not been merged into main.

## Results

| Check | Result |
| --- | --- |
| Existing game engine | 193 tests passed |
| Isolated life sequence | 6 tests passed |
| iPhone 16 Pro, iOS 18.5 simulator | 4 UI tests passed |
| iPhone SE (3rd generation), iOS 18.5 simulator | Same 4 UI tests passed |
| Normal iPhone app with PoC flag disabled | Release compilation passed |
| Separate PoC iPhone app | Release compilation passed |
| Installer | ZIP CRC, manifest SHA-256, bundle/version/executable verified after download |
| Compiled pose assets | All four asset names confirmed in the packaged Assets.car |
| Cue data | Packaged JSON matches the authored data exactly |
| Existing operator voice data | All 177 clip SHA-256 hashes verified in the downloaded IPA |

UI checks cover timed doze/wake/idle, first-tap consumption, repeated reaction
tap, all pose canvases and existing home controls, backgrounding during idle for
longer than the idle duration, returning from settings, Reduce Motion via a
simulator-only override combined with the actual system setting, and ordinary
conversation opening with operator motion disabled. The ordinary conversation
was verified with its existing `operator.continue` identifier; its navigation
title is intentionally empty.

Manual screenshot inspection: stretch, settled doze, surprised and embarrassed
poses render over the existing office with the existing header, greeting card,
story button and tab bar. Both device sizes keep the existing control regions
separate; no extra full-screen touch layer was added. The settled doze fixture
shows closed eyes/lowered chin. A natural-sequence screenshot taken immediately
on entering doze can still show open eyes, because the eye close settles over
3.5 seconds. Wait about 14 seconds from launch to see a fully settled doze.

The illustrated head, belt and sleeve details vary slightly between generated
poses. Pose crossfades are therefore perceptible, especially around the arm.
This verifies interaction/life flow; it does not establish final rigging quality.

## Performance observations and limits

Five large-device samples: Timeline callback schedule **29.80–30.00 Hz**,
simulator app-process physical footprint **26.71–26.84 MiB**.
Four compact-device samples: schedule **30.00 Hz**, process footprint
**26.38–26.40 MiB**. Logged simulator thermal state was nominal (0).

These are brief simulator diagnostics, not GPU-presented FPS or a whole-system
GPU/texture memory total. Simulator rendering services and shared resources can
be accounted outside the app process. They do not demonstrate physical iPhone
peak memory, temperature, energy use or long-session stability. Those physical
device measurements remain unverified; no real iPhone was remotely controlled.

## Downloads

- [PoC installer artifact](https://github.com/minwoo-106/Hunter-Run/actions/runs/36685240440/artifacts/11084875235)
- [Screenshots and diagnostics artifact](https://github.com/minwoo-106/Hunter-Run/actions/runs/36685240440/artifacts/11083809575)

GitHub artifacts expire on 2026-10-07; the downloaded files are also retained in
the local workspace's `outputs/operator-life-poc` folder. Artifact access uses
the repository's existing access permissions. Extract the installer ZIP and use
the `.ipa`; the manifest is a verification record.

Installer: `HunterRun-OperatorLife-PoC-build50-unsigned.ipa` (246,569,536 bytes).
Bundle: `com.hunterrun.operatorpoc`, display name **Hunter Run PoC**,
version 1.6.0 / build 50. Install alongside the normal game.

SHA-256:
`256ac836eefeb7172efdf206b2519ff19b313509b9432032aecdc32bcc033617`.

Assets and normalized generation prompts are recorded in `asset-prompts.md`;
the rendering/rigging boundaries and future asset requirements are in `README.md`.
Only documentation is added after the successful compiled implementation.
