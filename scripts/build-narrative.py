"""Compile the reviewed authoring drafts into offline dialogue graphs.

Only explicitly tagged spoken lines and choices enter the app. Production never
loads Markdown or author-only stage directions. Regenerate after dialogue edits.
"""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]


def condition(kind, value, hint, key=None):
    return dict(kind=kind, value=value, hint=hint, key=key)


REQUIREMENTS = [
    [],
    [condition('seconds', 300, '실제 활동 기록 5분 모으기')],
    [condition('defeat', 1, '잔향 늑대 첫 토벌', 'beast')],
    [condition('quest', 1, '비교 관측 의뢰 완료', 'compare-signals')],
    [condition('seconds', 3600, '누적 활동 60분'), condition('quest', 1, '기초 조사 의뢰 완료', 'basic-survey')],
    [condition('rank', 1, 'D급 승급 심사 통과')],
    [condition('quest', 1, '월영 표식 조사 완료', 'moon-mark')],
    [condition('quest', 1, '환영 관측 의뢰 완료', 'illusion-survey')],
    [condition('quest', 1, '원본 대조 의뢰 완료', 'compare-original')],
    [condition('departments', 2, '두 부서를 Lv.2로 확장'), condition('quest', 1, '관측망 복구 의뢰 완료', 'restore-link')],
    [condition('boss', 1, '경계의 군주 완전 토벌', 'boundary-lord')],
    [condition('quest', 1, '두 종류의 원본 복원 완료', 'restore-records')],
    [condition('rank', 2, 'C급 승급 심사 통과')],
    [condition('departments', 4, '네 부서를 Lv.2로 확장'), condition('quest', 1, '안쪽 신호 조사 완료', 'inner-signal')],
    [condition('boss', 1, '공허의 사서 완전 토벌', 'void-librarian')],
    [condition('boss', 1, '마지막 토벌 기록 확인', 'void-librarian')],
]


def compile_scene(identifier, title, body, kind, index):
    nodes, previous, branches = [], None, []

    def add(text, speaker='operator', expression='calm'):
        nonlocal previous, branches
        node = dict(id=f'{identifier}.n{len(nodes)+1:03}', text=text, speaker=speaker, expression=expression)
        if previous:
            previous['next'] = node['id']
        for response in branches:
            response['next'] = node['id']
        branches = []
        nodes.append(node)
        previous = node
        return node

    chooser = None
    for raw in body.splitlines():
        line = raw.strip()
        match = re.match(r'(?:오퍼레이터|O): (.+)', line)
        report = re.match(r'(평가관의 서면|문해진의 기록|환영의 문자|사서의 문자): (.+)', line)
        choice = re.match(r'- ([RM]\d{2}-[A-Z]) 「([^」]+)」 → (?:O|오퍼레이터): (.+)', line)
        if choice:
            if chooser is None:
                chooser = add('어떻게 말할까요?', 'hunter')
                chooser['choices'] = []
                previous = None
            response_text, _, memory = choice[3].partition(' / ')
            response = dict(id=f'{identifier}.n{len(nodes)+1:03}', speaker='operator', text=response_text, expression='smile')
            nodes.append(response)
            branches.append(response)
            item = dict(id=choice[1], text=choice[2], next=response['id'])
            if '=' in memory:
                key, value = (piece.strip() for piece in memory.split('=', 1))
                item['memory'] = {key.removeprefix('memory.'): value}
            if identifier == 'R12':
                pref = {'A':'closer', 'B':'closer', 'C':'partnership', 'D':'partnership', 'F':'undecided'}.get(choice[1][-1])
                if pref:
                    item['requiresMemory'] = {'relationshipPreference': pref}
            chooser['choices'].append(item)
        elif match or report:
            chooser = None
            text = match[1] if match else report[2]
            add(text, 'operator' if match else 'report')
    # Last authored scene acknowledgement always exists; choices cannot award early.
    if branches:
        add('다음에 또 이야기해요.', expression='smile')
    assert nodes and not branches, identifier
    tier = 1 if index <= 2 else 2 if index <= 5 else 3 if index <= 8 else 4 if index <= 10 else 5
    main_gate = [1,1,3,3,4,6,6,8,10,12,14,16][index-1] if kind == 'bond' else 0
    dependencies = {'R02':['R01'], 'R07':['R02'], 'R09':['R07'], 'R10':['R06'], 'R12':['R11']}
    return dict(id=identifier, title=title, kind=kind, order=index,
                artwork='AssociationOffice' if index <= 6 else 'AssociationOperational' if index <= 12 else 'AssociationAdvanced',
                requiredMain=main_gate, requiredTier=tier if kind == 'bond' else 1,
                prerequisite=dependencies.get(identifier, []), requirements=REQUIREMENTS[index-1] if kind == 'main' else [],
                start=nodes[0]['id'], nodes=nodes)


def conditional_line(scene, text, variants, suffix='memory'):
    # Insert one node before the final line, keeping the authoring graph acyclic.
    final = scene['nodes'][-1]
    identifier = scene['id'] + '.' + suffix
    for node in scene['nodes']:
        if node.get('next') == final['id']:
            node['next'] = identifier
    scene['nodes'].insert(-1, dict(id=identifier, speaker='operator', text=text,
                                  expression='smile', next=final['id'], variants=variants))


scenes = []
for filename, pattern, kind, expected in [
    ('story-v1-writers-bible.md', r'^### (M\d{2}) · (.+)$', 'main', 16),
    ('operator-relationship-scenes.md', r'^## (R\d{2}) · (.+)$', 'bond', 12),
]:
    source = (ROOT/'docs'/filename).read_text(encoding='utf-8')
    headings = list(re.finditer(pattern, source, flags=re.M))
    assert len(headings) == expected
    for i, heading in enumerate(headings):
        end = headings[i+1].start() if i+1 < len(headings) else len(source)
        body = source[heading.end():end]
        # Stop before following non-scene chapters, especially daily dialogue examples.
        body = re.split(r'\n## (?!R\d{2} ·|M\d{2} ·)', body)[0]
        scenes.append(compile_scene(heading[1], heading[2], body, kind, i+1))

by_id = {scene['id']: scene for scene in scenes}
conditional_line(by_id['R07'], '오늘은 잠깐 쉬면서 이야기하고 싶어요.', [
    dict(key='rest', value='quiet', text='오늘은 아까 하신 말이 생각났어요. 아무 말 안 해도 괜찮다고요.'),
    dict(key='rest', value='smallTalk', text='사소한 이야기 하나 들으실래요? 오늘은 프린터 말고 제 이야기예요.'),
    dict(key='rest', value='joke', text='쉬는 시간 규정을 만들었어요. 첫 번째, 규정을 읽느라 쉬는 시간을 다 쓰지 않기예요.'),
])
conditional_line(by_id['R09'], '먼저 이야기해도 괜찮다는 걸 조금씩 배우고 있어요.', [
    dict(key='support', value='company', text='그때 같이 쉬었던 시간이 생각보다 오래 기억에 남았어요.'),
    dict(key='support', value='listen', text='정리되지 않아도 들어주신다고 해서 말을 꺼낼 수 있었어요.'),
])
conditional_line(by_id['R10'], '답례로 작은 메모를 남겼어요. 보고서 사이에 끼워둘게요.', [
    dict(key='doodle', value='antenna', text='답례로 안테나 달린 늑대를 하나 더 그렸어요. 이제 공식 명칭처럼 쓰면 안 되는데요.'),
    dict(key='doodle', value='more', text='약속한 두 번째 늑대예요. 이번에는 조금 더 알아보기 쉬울 거예요.'),
    dict(key='doodle', value='original', text='귀는 그대로 뒀어요. 이대로가 좋다고 하셨으니까요.'),
])
conditional_line(by_id['R11'], '마실 건 그날 같이 골라요. 미리 전부 정할 필요는 없겠죠.', [
    dict(key='drink', value='warm', text='따뜻한 음료는 제가 준비할게요. 이번에는 서류부터 치워둘 거예요.'),
    dict(key='drink', value='cool', text='시원한 걸로 준비해둘게요. 컵 받침도 잊지 않고요.'),
])
conditional_line(by_id['R12'], '첫 보고서가 여기 있어요. 지금 보니 그때 글씨가 엄청 단정하네요. 긴장했나 봐요.', [
    dict(key='desk', value='cup', text='처음 비워둔 컵 자리, 기억하세요? 이제는 꼭 두 자리가 있어야 할 것 같아요.'),
])

# Opening callbacks belong before the new conversation, not after its conclusion.
for scene_id in ['R07', 'R12']:
    scene = by_id[scene_id]
    memory = next(n for n in scene['nodes'] if n['id'] == scene_id + '.memory')
    for node in scene['nodes']:
        if node.get('next') == memory['id']: node['next'] = memory['next']
    memory['next'] = scene['start']; scene['start'] = memory['id']
conditional_line(by_id['R12'], '아직 같이 써볼 기록이 많이 남았어요.', [
    dict(key='project', value='reader', text='교육 자료 첫 장도 완성했어요. 첫 독자가 되어주신다는 약속, 기억하고 있어요.'),
    dict(key='project', value='illustrated', text='교육 자료 첫 장에 제 늑대도 넣었어요. 그림을 넣자고 하셔서 조금 용기가 났어요.'),
], suffix='project')
for scene in scenes:
    mood = {'R02':'thoughtful', 'R03':'playful', 'R07':'worried', 'R08':'smile', 'R09':'thoughtful',
            'R10':'playful', 'R11':'smile', 'R12':'relieved', 'M08':'thoughtful', 'M09':'worried',
            'M10':'thoughtful', 'M12':'relieved', 'M15':'relieved', 'M16':'smile'}.get(scene['id'], 'calm')
    for node in scene['nodes']:
        if node['expression'] == 'calm' and node['speaker'] == 'operator': node['expression'] = mood
    if scene['nodes'][-1]['speaker'] == 'operator' and scene['kind'] == 'bond':
        scene['nodes'][-1]['expression'] = 'relieved' if mood in ['worried', 'thoughtful'] else 'smile'
result = dict(schema=1, scenes=scenes)
path = ROOT/'Resources/narrative.json'
path.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(f'Compiled {len(scenes)} scenes, {sum(len(s["nodes"]) for s in scenes)} nodes, '
      f'{sum(len(n.get("choices", [])) for s in scenes for n in s["nodes"])} choices.')
