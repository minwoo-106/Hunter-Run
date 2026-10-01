"""Validate the small-talk graph and preference/placeholder scope."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / 'Resources/operator-chat.json').read_text(encoding='utf-8'))
assert catalog['schema'] == 1
assert len({e['id'] for e in catalog['episodes']}) == len(catalog['episodes'])
lines = 0
for e in catalog['episodes']:
    assert 1 <= e['minimumTier'] <= 5 and e['prompt']
    assert e['activity'] in [None, 'coffee', 'burger', 'tablet', 'spacingOut', 'hairSweep', 'stretching', 'postRun']
    assert isinstance(e['requiresRecentActivity'], bool)
    nodes = {n['id']: n for n in e['nodes']}
    assert len(nodes) == len(e['nodes'])
    reached = set()
    def visit(key, path):
        assert key in nodes and key not in path, (e['id'], key)
        node = nodes[key]
        assert node['expression'] in ['calm','smile','playful','thoughtful','worried','relieved']
        assert node['lines'] and all(node['lines'])
        assert len(node['replies']) <= 3
        assert len({r['id'] for r in node['replies']}) == len(node['replies'])
        reached.add(key)
        for r in node['replies']:
            assert r['text']
            visit(r['next'], path | {key})
    visit(e['start'], set())
    assert reached == set(nodes)
    for n in e['nodes']:
        for text in n['lines'] + [r['text'] for r in n['replies']]:
            sanitized = text.replace('{operatorName}', '').replace('{activitySummary}', '')
            assert '{' not in sanitized and '}' not in sanitized
            if '{activitySummary}' in text: assert e['requiresRecentActivity']
        lines += len(n['lines'])
print(f'Validated {len(catalog["episodes"])} spoiler-free episodes, {lines} lines, every reply path and context placeholders.')
