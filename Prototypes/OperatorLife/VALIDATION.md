# Approved posture PoC validation — 2026-09-30

Compiled implementation: `737eb3bd04908854209f5117f4ba154cc3e9f2d7`.
Successful [build and UI verification](https://github.com/minwoo-106/Hunter-Run/actions/runs/36693518471).
Prototype branch only; not merged into main.

## Results

- Existing engine: 193 tests passed; life sequence: 6 tests passed.
- iPhone 16 Pro and iPhone SE (3rd generation), iOS 18.5: four UI tests each passed.
- Normal app with PoC disabled and separate PoC: Release compilation passed.
- Downloaded installer: ZIP CRC, SHA-256, bundle/version/Mach-O checked.
- Six compiled posture/blink assets present; cue JSON matches source.
- All 177 existing voice clip hashes match the catalog.

The UI checks exercise doze/wake/idle, consumed first tap and repeated taps,
background suspension, settings return, Reduce Motion, motion-disabled ordinary
conversation, and non-overlapping existing home controls. The natural capture
waits four seconds after doze begins so eyes/shoulders have settled.

Manual inspection of large/compact screenshots confirms that overhead hands
fit below the header, the operator remains behind the greeting card, and
settings, story and tab controls remain visible. All five body poses differ;
the old pocket/headset posture is not used by this renderer. The native
recording begins at the settled doze and shows waking/reaction/idle; the full
stretch and all five phases also have separate actual-app screenshots.

This remains a raster key-pose illusion: crossfades, small whole-portrait
movement and a masked eyelid drawing. It is not continuous joint animation
or Cubism. Generated face/sleeve/belt details can vary between drawings.

## Simulator metrics and limits

Large device: 8 samples; Timeline callbacks
25.23–30.00 Hz;
app physical footprint 26.77–47.44 MiB.
Compact device: 5 samples;
callbacks 30.00–30.00 Hz;
footprint 26.24–46.54 MiB.

These are simulator callback/process observations, not GPU-presented FPS,
whole-system texture memory, physical-device peak memory, temperature or energy.
Actual iPhone FPS, heating and battery behavior remain unverified.

## Installer and review

Bundle `com.hunterrun.operatorpoc`, display name **Hunter Run PoC**,
version 1.6.0 / build 51. Separate sandbox; install alongside normal Hunter Run.
File: `HunterRun-OperatorLife-PoC-build51-unsigned.ipa`, 248,597,523 bytes.
SHA-256: `fcf6db1e055431127891e6a3f4781f38ed1e5bbf8e914345a6383a12bbd001ed`.

- [Installer ZIP](https://github.com/minwoo-106/Hunter-Run/actions/runs/36693518471/artifacts/11088176543)
- [Native video, screenshots and diagnostics](https://github.com/minwoo-106/Hunter-Run/actions/runs/36693518471/artifacts/11087626702)

Artifacts expire 2026-10-07. Copies are retained in the workspace
`outputs/operator-life-poc/build51`. Extract installer ZIP and use only the IPA.
`README.md` describes implemented controls, raster illusions, required Cubism
parts and the future renderer seam. `pose-prompts-v2.json` and
`asset-manifest.json` record the approved generation/copy provenance.
