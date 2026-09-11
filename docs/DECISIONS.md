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
Ordinary gate stabilization remains a single maintain segment; 0.4 adds separate persistent major-boss campaigns.
0.2 adds equipment, four department upgrades and rank evaluation with three mission modes.
Rank evaluation is offline progression; competitive rankings remain out of scope.
User confirmed installation, the 0.1.1 layout correction, and speaker/AirPods voice playback.
Background field reliability and broad iPhone support still require real-device testing.


## 0.3 field and visual expansion
The user asked for larger batches and approved association management as the home CTA with a slightly larger central RUN tab. Twelve equipment illustrations, item detail/loadout views, distance/free goals, activity details and a field guide are included in this milestone.
Time/distance goals count toward completed-goal rank requirements; free activities grant resources/XP but have no completed target. Non-time patrols repeat existing content every 20 active minutes. A run awards at most one gate core and gate-clear record.

## 0.4 world and boss progression
The user's revised layout is implemented as a large home RUN CTA plus a slightly larger central association-management control.
Boss HP is saved only within the idempotent finished-run settlement. Recovery snapshots keep the boss definition, phase, starting HP and earned damage; scoring is corroborated against completed combat records. A stale round cannot damage a newer campaign. New rounds require a cleared boss, rank/department eligibility and no active run.
HP phases are >70%, >35%, and <=35%. They alter authored event composition and clip selection, without increasing the required pace. Walking converts combat into investigation; simulated sessions never alter real boss HP or unlock discoveries.
Association stages follow two and four Lv.2 departments. Seven individual creature images and two room variants were generated with builtin imagegen and copied unchanged; sources are recorded in world-art-sources.json.
Lobby audio is an original 32-second locally synthesized sketch, without external samples or runtime services. It plays in foreground home/association only, yields to other audio, and stops when starting/recovering a run, backgrounding, interrupting, or losing headphones. Playback controls persist locally. Existing operator clips remain temporary.

Audio hardware initialization is serialized on a dedicated run loop after a cloud simulator sample showed AVAudioPlayer.play blocking the main thread. Request cancellation is independent of that loop, and preparation has an eight-second timeout. Feature UI tests have a simulator-only silent backend; a separate test retains real audio initialization to verify navigation responsiveness. Actual output remains a device test.
