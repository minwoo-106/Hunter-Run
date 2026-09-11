# Accepted product rules and demo scope

## Product
Audio-first running RPG. No mid-run taps required for normal automatic play.
Manual pause/end/recovery remain available when stopped. Portrait iPhone layout.
Offline gameplay; no server, account, map, Watch, HealthKit, or live TTS in v1.

## Session rules
Walking and running count toward activity time; running time is tracked separately.
Candidate stops immediately suspend scoring; eight seconds confirms automatic pause.
Five seconds of movement resumes automatic pause; manual pause never resumes itself.
Unknown motion, vehicle segments, nonfinite samples and delivery gaps do not grant progress.
Pursuit requires optional opt-in, usable running baseline and reliable sensors.
Declining pursuit switches to investigation. Low sensor confidence yields a neutral outcome.
Instruction playback must finish before an event begins its scoring/acceptance timer.
Time goals stop new work and settle acquired rewards; no forced overtime.

## Persistence
A single atomic envelope stores progress and active recovery state.
A settled run ID prevents duplicate rewards; simulated runs never settle.
Corrupt saves fall back to the previous valid snapshot or fail visibly, never silently reset.
Reopening restores a paused session and replays the instruction before evaluation.

## Scope distinctions
This first milestone is a technical/demo vertical slice, not the full content-complete v1.
Gate stabilization uses a single maintain segment; persistent major-boss HP is not yet exposed.
0.2 adds equipment, four department upgrades and rank evaluation with three mission modes.
Rank evaluation is offline progression; competitive rankings remain out of scope.
User confirmed installation, the 0.1.1 layout correction, and speaker/AirPods voice playback.
Background field reliability and broad iPhone support still require real-device testing.

