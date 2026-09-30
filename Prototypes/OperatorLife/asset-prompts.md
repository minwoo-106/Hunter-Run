# Current approved posture prompts — build 51

The current six files are documented in `pose-prompts-v2.json` and
`asset-manifest.json`. Five distinct body poses replace the old pocket stance,
and the closed-eye drawing matches the new idle face. All are built-in imagegen
reference edits with genuine transparency. PNG bytes were copied unchanged; no
local image redraw or cutout was performed.

The following build-50 prompt history is retained only to explain the rejected
first PoC. These poses are no longer selected.

# Selected image prompt set

Generated with the built-in `image_gen` tool; four separate reference-based edits,
`transparent_background=true`. Alpha is preserved; no cutout, redraw, recolour or
post-generation image manipulation was performed by local Python. The script
only copied selected PNG bytes into the prototype's asset catalog.

Edit/reference target for every pose:
`Resources/Assets.xcassets/OperatorCutout.imageset/operator-cutout.png`.

Normalized final prompt specification (the generation instructions below):

Common: retain the exact adult approximately 22-year-old Korean fantasy game
operator identity, face, navy hair streaks, hairstyle, white shirt/black tie,
gold badge, watch and trousers; same illustration style, portrait framing,
head/waist anchors and 1024×1536 canvas. Genuine transparent background. One
character only; no text, backdrop, UI or exaggerated comedy. Keep the arm
silhouette inside the existing home portrait canvas.

1. **Stretch** — gentle shoulder stretch, lower the hand from the earpiece and
   rest it naturally across the opposite shoulder, elbows low; soft closed-mouth
   smile, slight shoulder lift, no large twisting of the torso.
   Saved: `Resources/Assets.xcassets/OperatorLifeStretch.imageset/art.png`.
2. **Doze** — same pose, eyes completely closed, chin tilted subtly down about
   eight degrees, slight relaxed head lean; the hand at the earpiece follows the
   head naturally. Subtle believable tiredness, no drool/sleep bubbles/comic face.
   Saved: `Resources/Assets.xcassets/OperatorLifeDoze.imageset/art.png`.
3. **Surprised** — upright recovered posture, grey-blue eyes noticeably wider,
   eyebrows gently lifted, small parted mouth; natural startle, same hand near
   the earpiece. No huge anime eyes or chibi proportions.
   Saved: `Resources/Assets.xcassets/OperatorLifeSurprised.imageset/art.png`.
4. **Embarrassed** — subtle pink cheeks, a small apologetic smile, a slight
   sideways glance, relaxed upright posture; keep the same hand near the earpiece.
   Understated embarrassment, no exaggerated blush streaks/hearts.
   Saved: `Resources/Assets.xcassets/OperatorLifeEmbarrassed.imageset/art.png`.

Paths above are relative to `Prototypes/OperatorLife`. `asset-manifest.json`
records selected source basenames, dimensions, alpha range and SHA-256 hashes.
