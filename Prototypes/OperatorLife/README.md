> **Integration update:** approved life motions now live in the normal 1.6.1 source tree. Runtime/rendering: `App/OperatorLife`; pure state control: `Sources/OperatorLifeCore`; assets/cues: `Resources`; tests: root `swift test` and `UITests/OperatorLifeUITests.swift`. See [current release status](../../docs/1.6.1-release.md). The notes below describe historical isolated PoC builds, not a verified 1.6.1 installer. Legacy PoC scripts are retained as archival material; use the normal project/CI for new builds.

# Operator life motion PoC

Question: does the existing Hunter Run home portrait feel like a person living in the branch?

This is an isolated **raster-pose prototype**, not a Live2D model. Its branch is
`prototype/operator-life-poc`; the normal 1.6.0 app/project remains unchanged.
The installer has bundle `com.hunterrun.operatorpoc`, display name `HunterRun PoC`,
planned version 1.6.0 / build 53. The latest verified installer remains build 52. Install alongside Hunter Run. Its sandbox and preferences
are separate, so it cannot change the installed game's save. Registration is
bypassed only in this PoC. No life state is saved, no affinity/reward/story API is called.

## Coffee and lunch refinement - build 53 source

Coffee now closes the eyes softly, holds the mug below the nose, and savors the
aroma. Lunch runs burger -> puffed-cheek surprise (1.4 s) -> chest pat (3.2 s)
-> hurried cola sip (4.8 s) -> idle. The chest-pat renderer alternates contact
and released fist drawings every 0.65 s; this is raster crossfading, not a rigged
arm. Reduce Motion shows a still contact pose while retaining the reaction.
Repeated taps throughout the reaction are consumed. Dialogue remains text only.

The four assets were generated/edited with the built-in image_gen tool and
copied into the project, preserving their RGBA alpha. Exact prompts:
[lunch-refinement-prompts.json](lunch-refinement-prompts.json).

- [Coffee aroma pose](../../Resources/Assets.xcassets/OperatorLifeCoffee.imageset/art.png)
- [Chest pat contact](../../Resources/Assets.xcassets/OperatorLifeChestPat.imageset/art.png)
- [Chest pat released](../../Resources/Assets.xcassets/OperatorLifeChestPatAway.imageset/art.png)
- [Hurried cola sip](../../Resources/Assets.xcassets/OperatorLifeCola.imageset/art.png)

Browser flow/JavaScript checks, all sixteen asset hashes/alpha/dimensions, normal
game-content validation, and interactive coffee/lunch/Reduce Motion checks pass.
Updated Swift and iOS tests are committed, but have not executed for build 53.

## Expanded life preview — build 52

The resting portrait remains raised. Rendering extends above the old character box;
only the outer screen edge clips naturally. The existing touch box stays unchanged.
After the first doze/wake sequence, idle intervals rotate through coffee, tablet,
spacing out, hair sweep, burger, then doze. Burger waits for a tap; that tap is
consumed by puffed-cheek surprise, then a straw/cola sip, then idle. Repeated taps
cannot restart either wake or lunch reactions. Optional JSON activity data leaves
the old five-state sequence valid when absent.

Eight new transparent key poses were produced using built-in image generation.
Exact prompts: `activity-prompts.json`; file hashes/sizes: `asset-manifest.json`.
Hamburger alternates bite and closed-mouth chewing drawings. These remain raster
crossfades and tiny whole-portrait motion, not articulated limbs or a Cubism model.
There are no new sound effects or TTS. Original 177 voice files are unchanged.

The browser preview has direct action buttons outside the reference phone UI.
The real PoC home has no extra menus; it plays the timed sequence. Build 52 passed native
compilation and ten UI tests on two iPhone sizes. Build 53 source changes are not
yet compiled: GitHub refused to start its runner because of account billing or
spending limits. The interactive browser preview has been verified.

## Try it

Open the app and leave Home visible: overhead full-body stretch (2.6 s), idle (7.5 s),
slow eye close and doze settle (3.5 s), then wait indefinitely for a character tap.
The existing clear character button consumes the first tap to wake up; repeated
taps during surprised/embarrassed cannot open the conversation or restart it.
Surprised lasts 1 s, embarrassment 6.2 s, then idle 14 s before the next lifestyle action.
Ordinary taps during idle/stretch still open the existing conversation.
The three temporary lines replace the existing greeting card, without another panel/menu.
No new TTS clips are played.

Leaving Home, opening a sheet or backgrounding freezes the sequence. Returning
resumes the in-memory phase without adding offscreen time. Relaunch starts fresh.
Reduce Motion uses still poses and skips stretching/continuous movement; wake
interaction and dialogue remain. Turning the existing operator motion option
off resets to idle and restores ordinary conversation taps.

On macOS with Xcode 16.4 and XcodeGen:

```sh
swift test --package-path Prototypes/OperatorLife
xcodegen generate --spec project-operator-poc.yml
bash Prototypes/OperatorLife/check-ios-poc.sh facilities
```

The branch's manually dispatched `ios-install.yml` also compiles the normal
app with the PoC flag disabled, builds the separate installer, checks original
177 voice hashes, and runs the PoC UI checks on large and compact iPhone simulators.

## Boundaries

`Core/LifeSequence.swift` owns the phase/timing/tap contract; it imports only
Foundation and knows no art, SwiftUI or game data. `operator-life-cues.json`
owns dialogue/timing data. `OperatorLifeRuntime` gates uptime according to
visibility/settings, publishing only phase/cue changes. `OperatorLifeStage`
owns one 30 Hz animation schedule. `OperatorLifeRendering` takes a semantic
`LifeRenderFrame`; `OperatorPoseRenderer` is the current raster implementation.

Later a Cubism renderer can map phase/progress to authored motions and parameters
inside a SwiftUI native-view wrapper, replacing just the renderer/asset loading.
It must obey the same availability/Reduce Motion flags and fixed canvas. This
is an integration seam, **not an already implemented Cubism adapter**. New states
still need their own transitions, cues and visual assets.

## What is genuinely implemented versus an illusion

Implemented: real timed state transitions, wake-only first tap, three independent
text cues, no repeated-tap restart, lifecycle suspension, static Reduce Motion,
existing breath shader/blink in idle, and bounded rendering/touch geometry.

Illusion: fifteen transparent full-character body drawings are crossfaded;
a sixteenth drawing supplies closed eyelids for the idle face.
Tiny rotation/translation applies to the whole portrait. Eyelids are a mask from
the matching newly generated idle blink illustration; closing is an opacity fade, not an articulated
eyelid rig. Shoulder stretching and head nod are alternate drawn poses, not
independent body joints. Idle gaze comes from a tiny whole-portrait drift; pupils
do not independently track the user. Small differences between generated faces/
silhouettes can remain visible in a crossfade. The canvas is the existing home
portrait background, under the unchanged header/greeting/navigation UI.

## Assets needed for real Cubism

The current flattened image cannot supply clean independent deformation parts.
Prepare a layered PSD with torso/clothes/neck/head, front/back/side hair, both
eyes (sclera/iris/pupil/highlight/lids/lashes), brows, mouth components, arms/hands,
and hidden areas painted beneath overlapping parts. A rigger must build meshes,
deformers and angle/body/breath/eye/mouth/arm parameters, then author idle,
stretch, doze, surprised and embarrassed motions, transitions and expressions.
Export `.moc3`, `.model3.json`, texture atlases, `.motion3.json`, expression files,
and any rigged physics/pose data; retain the editable `.cmo3` project.

The official [embedded data manual](https://docs.live2d.com/en/cubism-editor-manual/export-moc3-motion3-files/)
describes model/runtime exports; the [Native framework manual](https://docs.live2d.com/en/cubism-sdk-manual/cubismnativeframework/)
describes loading model, motion, expression, physics and pose settings.
Actual SDK integration and compatible runtime assets are a separate next step.

Raster poses are quick to prepare and retain illustration detail, but motion is
limited to a few drawings and transitions. Cubism can deform head/eyes/hair/body
continuously with consistent identity; rigging and renderer integration cost
more work. Cubism is not automatically faster or lower-memory: atlas sizes,
mesh/mask counts and draw frequency determine its device cost.

## Performance evidence limits

The animation target is 30 Hz, not a promise of measured 30 GPU FPS. Diagnostic
logs explicitly report **Timeline callback cadence**, process physical footprint,
and system thermal state. Sixteen 1024×1536 RGBA drawings amount to roughly 96 MiB of
decoded pixels if all are resident, plus existing textures/offscreen buffers;
the PNG files total 29.4 MiB in the source assets. Those estimates are not
measured app memory. No real iPhone is controlled from this Windows workspace;
simulator cadence/memory cannot prove iPhone GPU performance or temperature.
Physical-device FPS, peak memory and thermal/energy checks still require an
installed PoC on an iPhone with Instruments/device observation.

See `VALIDATION.md` after a successful build for actual test/screenshot results.

## Approved posture revision

Build 51 removes the pocket/headset stance from every life pose. Stretch uses
both arms overhead with an effort expression; idle lowers both arms; doze
relaxes shoulders, head and hands; waking raises both hands; embarrassment
adjusts the tie. The renderer reserves overhead room and aligns resting faces.
It does not morph individual joints or claim continuous arm articulation.
The original game and its production portrait assets remain untouched.

`pose-prompts-v2.json` and `asset-manifest.json` record the new generation and
copy verification. `capture-life-test.py` records the native simulator wake test
as `life-preview-large.mp4`; recordings/screenshots are build artifacts, not
synthesized gameplay. Windows can also preview the accepted poses in the
self-contained browser demo under the workspace `outputs/operator-life-poc`.
