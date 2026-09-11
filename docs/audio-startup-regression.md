# Audio preparation and UI responsiveness

The first 0.4 iPhone compile succeeded, but the first simulator UI test could not obtain the home controls. The event loop did not become idle for 60 seconds.

Diagnostic build: https://codemagic.io/app/6aa34d1b5a8fa8a63bc40bb9/build/6aa3c8a2d1206ff4816769c5 (source f96eb17).
The process sample identified this main-thread chain:
`AppModel.refreshLobbyMusic -> LobbyMusicPlayer.play -> AVAudioPlayer.play -> prepareToPlayQueue -> AudioToolbox/CoreAudio hardware wait`.
Both initial NO/YES launches reached the same chain: the argument-domain string had not been interpreted as a Bool by the optional cast. Preference loading now uses UserDefaults.bool(forKey:) when a value exists. The initial probe must not be described as a successful audio-off control.

## Fix
- All audio session/player operations run on one dedicated thread with a run loop, preserving playback delegate delivery and ordering between lobby and voice players.
- UI cancellation invalidates a request immediately, independently of the worker. Delayed requests check validity before and after starting audio.
- An eight-second preparation timeout cancels stale work. Voice failure pauses the activity; lobby failure is shown in its settings text.
- Players deactivate only the audio session they activated; an empty player's stop does not deactivate another player.
- The five feature UI tests use an explicit simulator-only silent-audio argument, with asynchronous mock instruction completion. It has no effect in iPhone builds.
- A sixth UI test uses the real audio initialization path and verifies home, RUN and association navigation remain responsive.
- Portable worker tests exercise a blocked operation, responsive submission/cancellation and stale timeout rejection.

The temporary process-sampling workflow/script was removed after diagnosis. Device audio quality, speaker/AirPods playback, interruption and mixing still require an iPhone retest after this change.

The worker follows Apple's [secondary-thread run-loop guidance](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html).
