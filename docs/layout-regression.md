# Home layout regression

## Report and reproduction

The first installed demo ran on the user's iPhone, but the home profile and RUN
card extended beyond the right edge. The supplied screenshot is the device
evidence; AltStore also displayed a format error, whose cause is not established.

`bash scripts/check-ios-layout.sh` runs the actual SwiftUI app through XCTest on
an available iPhone simulator (preferring iPhone 17 Pro). It asserts that the
profile, greeting, and RUN button remain inside the window with horizontal
margins, and that tapping RUN opens its setup screen.

Baseline commit `b036974`, Codemagic build
[6aa3742ded216a48bfeb8579](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa3742ded216a48bfeb8579):

- Window: 402 × 874 points.
- Profile right edge: 414.16 points.
- RUN frame: x 20, width 394; right edge 414 points.
- Result: two right-overflow assertions failed; RUN navigation worked.

## Fix

The operator artwork used a width of 108% in the same ZStack as the controls.
The resulting stack widened the controls beyond the GeometryReader's viewport.
Artwork now lives in a background, while the control surface explicitly uses
the measured viewport size. This retains the artwork scale without using it to
size the header or cards. Bundle version is 0.1.1 (2).

The simulator regression also runs before packaging in `ios-demo`. Screenshots
and XCTest results are retained in the build artifacts. A simulator pass is not
a claim that every device, text size, or sensor/background behavior has been
tested. The user still checks the updated app on their own iPhone.

## Verified result

Fix commit `b0a6322`, [demo build 5](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa375c0882a10b960c25ca0)
finished successfully in 5m 46s on 2026-09-11.
On iPhone 17 Pro / iOS 26.5 (402 × 874 points):

- Profile right edge: 382 points (was 414.16).
- RUN frame: x 20, width 362; right edge 382 (was 414).
- Greeting bounds remain inside the viewport.
- All layout assertions and RUN navigation passed, zero failures.
- iPhone compilation, core tests, and IPA-in-ZIP integrity validation passed.
- User-device confirmation on the reported iOS 26.6.2 remains pending.
