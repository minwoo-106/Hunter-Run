# Hunter Run 1.1 — labyrinth interface

## Scope

The existing home composition, operator artwork, dialogue content, voice clips, game rules and save format remain intact. A cold-launch title gate leads into the existing home and registration flow; background/foreground transitions do not replay the title. Save recovery remains accessible when validation fails.

Non-home screens use a shared dark-stone backdrop, antique-gold borders, cut-corner panels and scalable game buttons. The profile has a rank crest and a personal record panel. Settings are custom scrollable sections with accessible native sliders and toggles. Conversation and story screens have a persistent animated portrait above an independently scrolling dialogue panel. Relationship chapters are under “함께한 기록”. Advancing a dialogue or choosing a reply brings the new reply into view. The original story cursor and preference persistence logic is preserved.

## Art provenance

- Tool: built-in image generation, September 13, 2026.
- Original: `C:/Users/ckdem/.codex/generated_images/01a08b7c-2c5b-7cf0-9a33-aa3680c838f4/exec-6e7cd8c9-b14d-48a5-9478-aeb57674311f.png`
- App copy: `Resources/Assets.xcassets/LabyrinthEntrance.imageset/art.png`.
- New environment illustration; no existing operator art was changed. UI frames are native SwiftUI geometry and typography, not baked into the raster.
- Native launch image configuration follows [Apple UILaunchScreen](https://developer.apple.com/documentation/bundleresources/information-property-list/uilaunchscreen).

## Validation

Content validation and Swift syntax checks passed before cloud submission. The cloud workflow runs the existing core suite, iPhone UI suite, new title/conversation/menu checks, and compact-screen checks. Test screenshots are exported to `build/ui-review` and `build/ui-review-small` for visual inspection. Final cloud and artifact verification results are recorded in the release notes after completion.

Initial build26 captured a transparent home-portrait hit target that remained on the home screen when tapped. An explicit rectangular content shape fixes the hit area without changing home artwork or layout. The same UI test taps the original `home.operator` target and verifies the real reply and relationship archive, including accessibility text size. The first screenshots also exposed an open subpath in the decorative panel geometry; the outline now uses a single closed polygon. Guide scrolling and the two-level story return in the visual tour match the new screen structure.

Final build30 (`2097d25`, 1.1.0/build19) passed 119 core tests, content validation, seven focused iPhone 17 Pro UI tests and five 375×667 compact UI tests. The default script still retains the full suite; the release ran `check-ios-layout.sh labyrinth` to focus on changed presentation paths. Downloaded ZIP/IPA verification passed, including all 113 voice hashes and launch-image configuration.

Compact XXXL dialogue testing exposed a clipped portrait's invisible hit area. The decorative portrait now disables hit testing so it cannot cover the lower conversation panel. A short, controlled scroll reaches the choice, retains the actual hittability/tap assertion and captures the screen before selection. Both compact and primary runs now pass. Settings guide tests drag at the scroll edge to avoid changing sliders; the inline dark navigation bar keeps its title legible.
