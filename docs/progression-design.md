# Progression slice decisions

0.2 connects completed runs to purchasable equipment, four department unlocks,
manual rank evaluation, three mission profiles, and mode-specific settlement.
This is an incremental playable milestone, not content-complete v1.

## Persistence and transactions

New Codable fields are optional so schema-1 saves from 0.1 can decode without
resetting XP, currencies, settled IDs, or histories. `Profile.growth` supplies
defaults and carries forward the old observation level. Writes encode the new
fields; downgrading to an older app is not a supported round-trip.

Growth mutations run against a copied save. AppModel publishes the new profile
only after SaveRepository atomically writes it. Purchase and upgrade guards
prevent negative balances and duplicate spending. Save.active prevents changing
gear/departments during a recoverable run, and the app also blocks changes while
an engine/result screen is open.

Starting a run stores its combat loadout and mission content in the session.
Recovery uses those snapshots, including after a content update. Old sessions
without snapshots retain the original demo mission fallback.

## Gameplay

Equipment definitions and department costs/hints/unlock actions live in
Resources/progression.json; mission profiles live in Resources/missions.json.
Rank thresholds are an initial code table and will need economy tuning.
Department hints precede unlock descriptions. Each available upgrade opens
implemented content or information rather than only increasing a percentage.

Attack/defense/passives modify game outcomes, not baseline pace or qualification
thresholds. Investigation, including a combat event converted to investigation
for walking or uncertain sensors, causes no combat damage and cannot award a
boss core. A gate core requires an actual defeated gate-core record. Settlement
still uses run IDs for idempotence, and simulated runs never settle.

## Validation

23 portable tests include legacy save decoding, catalog validation, purchasing,
equipment removal, active-run locks, department unlocks, rank conditions,
idempotent mode rewards, no boss core for investigation, and same-pace combat
with different loadouts. iPhone UI checks cover home bounds, RUN navigation,
association access, equipment access, exploration selection and locked gates.

Codemagic demo build 6 (`d503224`, 2026-09-11) passed all 23 core tests and
2 UI tests, compiled the iPhone app and produced the install ZIP in 4m 30s.
UI tests used iPhone 17 Pro / iOS 26.5. Actual device sensor and background
behavior remain subject to field testing.
