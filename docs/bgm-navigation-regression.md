# Lobby music across navigation

## 0.6 follow-up
The user requested music on activity setup too. LobbyMusicContext now ignores the
selected tab and association visibility: foreground/enabled music plays unless a
voice test or actual/mock activity is active/presented. The policy tests include
setup and association dismissal over setup. Result presentation still keeps BGM
stopped until returning to browsing. The earlier 0.5 behavior below is historical.

## 0.5 diagnosis and verification

The device report was reproduced by extracting the exact AppModel condition into LobbyMusicContext, then running `swift test --filter LobbyMusicPolicyTests` before the fix. The browsing test failed for tabs 1/3/4 and association dismissal over menu. The other two priority tests passed.

The predicate now excludes RUN setup (tab 2) unless association is presented above it; a presented/active run, background app, disabled music or voice test still takes priority. AppModel uses this predicate directly. LobbyMusicPlayer keeps its existing AVAudioPlayer when asked to play again, updating volume without restarting the track. Navigation does not create a new player unless playback was explicitly stopped.

All 51 core tests passed on Linux after the fix. Apple UI/compile verification is recorded in README after the cloud build. The real-audio UI case visits hunter, archive, menu, home, RUN and association; audible continuity still needs physical-device confirmation.

Build 14 (29a419d) passed all 51 Apple core tests, iPhone Release compilation and the six existing UI cases, including real-audio navigation. The new story case reached locked content but tried to close the association sheet from a nested navigation destination; only the root view provides that close button. The test now returns through the two back buttons before closing, and relaunches without the welcome-skip test argument to verify completion persistence. No application code changed for this test correction.

Verified build 15 (`74662e7`) passed all 51 core tests and 7 UI tests, including the corrected story/welcome case and actual audio initialization. The iPhone Release target and installer integrity check passed. [Build and artifacts](https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa3f2b105d4cecd5b0308ad).
