# Expanded operator life PoC validation - 2026-09-30

Compiled implementation: `091b179c33f78a86227c3e9939e0c47cce270f62`.
Successful [build and UI verification](https://github.com/minwoo-106/Hunter-Run/actions/runs/36702307649).
Prototype branch only; not merged into main.

## Results

- Existing engine: 193 tests passed; life sequence: 9 tests passed.
- iPhone 16 Pro and iPhone SE (3rd generation), iOS 18.5: five UI tests each passed.
- Normal app with PoC disabled and separate PoC: Release compilation passed.
- Downloaded installer: ZIP CRC, SHA-256, bundle/version/Mach-O checked.
- Fourteen compiled posture/blink assets present; cue JSON matches source.
- All 177 existing voice clip hashes match the catalog.

UI checks exercise doze/wake/idle, consumed first and repeated taps, burger tap
reaction followed by cola and idle, background suspension, settings return,
Reduce Motion, motion-disabled ordinary conversation, and existing home controls.
Static screenshots cover all twelve phases on both screen sizes. Manual review
of coffee, tablet, spacing out, hair sweep, burger, puffed-cheek surprise, cola
and stretch confirms readable controls and character placement behind the card.
Raised stretch hands use space above the old portrait box; only the screen edge
clips. The touch box is unchanged.

The native recording covers doze to wake to embarrassed to idle, not the new lunch
sequence. New actions have actual-app screenshots and an interactive browser demo.
Browser checks exercised all five action buttons, lunch first/repeated taps,
cola to idle and Reduce Motion. Both previews use the shared cue/timing JSON.

This remains a raster key-pose illusion: crossfades, small whole-portrait movement
and a masked eyelid drawing. Burger alternates two drawn poses; independent hands
and jaw joints are not animated. It is not Cubism.

## Simulator metrics and limits

Large device: four samples; Timeline callbacks about 30 Hz; process footprint
26.80-26.88 MiB. Compact device: four samples; callbacks about 30 Hz; footprint
26.19-26.27 MiB.

These short samples do not cover a full rotation through every texture. They are
simulator callback/process observations, not GPU-presented FPS, peak texture
memory, physical-device temperature or energy. Actual iPhone FPS, heating,
battery behavior and peak memory remain unverified. Fourteen decoded RGBA
images alone could occupy about 84 MiB if all resident.

## Installer and review

Bundle `com.hunterrun.operatorpoc`, display name **Hunter Run PoC**,
version 1.6.0 / build 52. Separate sandbox; install alongside normal Hunter Run.
File: `HunterRun-OperatorLife-PoC-build52-unsigned.ipa`, 257,136,738 bytes.
SHA-256: `1219be781390e9a0c46ea0761dd67580c1d2a75850837a74fe62c4aabb503566`.

- [Installer ZIP](https://github.com/minwoo-106/Hunter-Run/actions/runs/36702307649/artifacts/11091282174)
- [Native video, screenshots and diagnostics](https://github.com/minwoo-106/Hunter-Run/actions/runs/36702307649/artifacts/11091152899)

Artifacts expire 2026-10-07. Copies are retained in the workspace
`outputs/operator-life-poc/build52`. Extract installer ZIP and use only the IPA.
`README.md` distinguishes implementation, raster illusions, required Cubism
parts and the future renderer seam. `activity-prompts.json`, `pose-prompts-v2.json`
and `asset-manifest.json` record generation/copy provenance.
