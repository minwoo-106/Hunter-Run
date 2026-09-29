"""Estimate eligible outdoor hunts for promotion gate credits (not total play time)."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
balance = json.loads((root / "Resources/gate-balance.json").read_text(encoding="utf-8"))
p = balance["firstEncounterChance"]
assert balance["eligibleSessionsToGuarantee"] == 2 and 0 <= p <= 1
credits = {"C": 1, "B": 4, "A": 10, "S": 25}
# Story-paced illustration, not an assertion that every player clears these bosses before promotion.
story_first_clears = {"C": 1, "B": 2, "A": 2, "S": 3}

def expected_hunts(normal_gates: int, retreat_rate: float = 0) -> float:
    # A failed gate remains pending and the next eligible hunt offers it again.
    return normal_gates * ((2 - p) + retreat_rate / (1 - retreat_rate))

print(f"First eligible hunt p={p:.0%}; guarantee by eligible hunt 2; mean discovery={2-p:.2f}")
print("Rank | total credit | no boss hunts | story-paced first clears | story-paced hunts | 10% retreat hunts")
for rank, needed in credits.items():
    remaining = max(0, needed - story_first_clears[rank])
    print(f"{rank:>4} | {needed:>12} | {expected_hunts(needed):>13.1f} |"
          f" {story_first_clears[rank]:>23} | {expected_hunts(remaining):>17.1f} |"
          f" {expected_hunts(remaining, .1):>17.1f}")
print("Subtract existing legacy credits from each target before estimating new gates.")
print("Each 20-minute eligible hunt can also count toward the independent activity-time requirement.")
