# Recent pace display

The user reported that time/distance were usable but current pace swung strongly.
The old display directly inverted SensorProbe's short-window median speed. A
synthetic alternating 1.6/2.8 m/s sequence on that presentation path produced a
267.857-second/km range. This reproduces display sensitivity; no actual device
sensor trace was available, so it does not prove the source of field GPS noise.

`swift test --filter DisplayedPaceTests` failed on the old direct assignment.
The extracted DisplayedPace now averages elapsed-time-weighted speed over the
last 12 seconds, waits for three seconds of data, and bounds changes to 0.15 m/s
per second. Duplicate/out-of-order delivery is ignored. Invalid values, poor GPS,
stops, unknown/vehicle motion, pause and >5-second gaps clear the display. Resume
starts from fresh data. The UI calls this recent pace, not instantaneous pace.

This filter is presentation-only: SensorFrame still reaches RunEngine unchanged.
Distance, time, learning and combat do not use the smoothed display value.
Tests cover noisy input, cadence independence, duplicate/replayed samples,
pause/stop/signal loss, warmup after gaps, and sustained speed-change response.

Field follow-up: steady walk/jog for 1–2 minutes; stop, resume; try an open area
and poor-GPS area. Expect a short settling period and dashes during unreliable
measurement. Final sensor tuning requires those device observations.
