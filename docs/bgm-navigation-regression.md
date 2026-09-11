# Lobby music across navigation

The device report was reproduced by extracting the exact AppModel condition into LobbyMusicContext, then running `swift test --filter LobbyMusicPolicyTests` before the fix. The browsing test failed for tabs 1/3/4 and association dismissal over menu. The other two priority tests passed.

The predicate now excludes RUN setup (tab 2) unless association is presented above it; a presented/active run, background app, disabled music or voice test still takes priority. AppModel uses this predicate directly. LobbyMusicPlayer keeps its existing AVAudioPlayer when asked to play again, updating volume without restarting the track. Navigation does not create a new player unless playback was explicitly stopped.

All 51 core tests passed on Linux after the fix. Apple UI/compile verification is recorded in README after the cloud build. The real-audio UI case visits hunter, archive, menu, home, RUN and association; audible continuity still needs physical-device confirmation.
