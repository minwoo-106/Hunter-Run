# Activity goals and recurring patrols

RunSession.goal and RunSummary.goal/runningSeconds are optional for schema-1 decoding.
An older session without a goal remains a time goal based on targetSeconds.
ActivityGoal validates finite bounded time/distance targets and a zero-valued free goal.
The existing targetSeconds field remains for old save compatibility; non-time sessions can exceed it.

Time goals stop at active time. Distance goals clamp the final distance increment to the remaining goal and prorate that frame's active/running time. Free goals require explicit termination and never count as a completed goal for rank evaluation.
Pause, motion filtering, timestamp ordering and delivery-gap protection run before goal progress.

Distance/free patrols schedule content on a 1,200-active-second cycle, independently of pace.
Occurrence IDs append #cycle after the first pass. EventRecord.catalogID recovers the stable content ID for archive analysis and gate settlement. No continuous intensification is added: existing pursuit opt-in, recovery and intensity limits remain.
Cores and gate-clear history remain capped at one per run; settlement remains idempotent.

Eight added portable tests cover exact distance termination, continued distance goals past the old time limit, repeating free patrols, paused/vehicle/gap input, recovery, legacy decoding, invalid goals and repeated core settlement. All 31 portable tests passed locally on 2026-09-11. Codemagic build 8 (51c061f) also passed all 31 portable tests and 4 iPhone UI tests. The app compiled and packaged successfully. Real sensor/background behavior still needs device testing.
