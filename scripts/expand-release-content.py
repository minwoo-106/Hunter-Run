"""Idempotent 1.0 content additions. Art and recorded audio are verified separately."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
R = ROOT/'Resources'
def read(name): return json.loads((R/(name+'.json')).read_text(encoding='utf-8'))
def write(name, data): (R/(name+'.json')).write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
world, encounters, narration, progression, lines = [read(name) for name in ['world','encounters','narration','progression','audio-lines']]
monsters = [
    ('mirror-moth','거울 날개 나방','거울 날개를 접어 같은 자리에 다른 잔향을 비추는 개체예요.','maintain',30,65,'D',False),
    ('ash-boar','재갑 멧돼지','재와 돌로 된 외피를 두른 야수예요. 짧고 일정한 대응으로 돌진을 흘려보낼 수 있어요.','ambush',25,70,'D',False),
    ('lost-sentinel','유실 감시체','초기 감시자와 같은 계열의 불완전한 구조체예요. 핵심 일부를 잃어 상대하기 쉬워졌어요.','maintain',30,45,'C',False),
    ('hollow-knight','공백 기사','비어 있는 갑옷을 잔향으로 묶은 엘리트예요. 긴 공방에서 외피가 약해져요.','endurance',240,130,'B',True),
    ('fallen-fairy','타락한 요정','검은 꽃잎과 보랏빛 날개를 두른 요정이에요. 일정한 리듬으로 날개의 환영을 흩뜨려요.','maintain',30,60,'D',False),
    ('veil-witch','장막의 마녀','달빛 장막을 엮는 마녀예요. 짧은 가속으로 틈을 공략하거나 유지 대응으로 장막을 걷어낼 수 있어요.','boss',10,125,'C',True),
]
for identifier,name,detail,kind,duration,hp,rank,elite in monsters:
    event=dict(id=identifier,title=name+' 대응',kind=kind,startFraction=.3,duration=duration,hp=hp,audio=identifier+'_intro')
    if kind == 'endurance': event.update(targetDistance=400,shortAudio=identifier+'_short')
    if identifier == 'veil-witch': event.update(burstSeconds=10,steadyAudio='veil-witch_steady')
    entry=dict(id=identifier,monsterID=identifier,name=name,elite=elite,requiredRank=rank,requiredAction='elite-signal' if elite else None,
               unlockHint=rank+'급 이상'+(' · 관측부 Lv.3' if elite else ''),tactic=detail,
               slots=dict(contract='contract-endurance' if elite else 'beast',gate='gate-guard' if elite else 'gate-ambush',exploration='exp-echo'),
               event=event,survey=dict(id=identifier,title=name+' 흔적',kind='discovery',startFraction=.3,duration=30,hp=0,audio=identifier+'_survey'))
    encounters['encounters']=[e for e in encounters['encounters'] if e['id']!=identifier]+[entry]
    world['monsters']=[m for m in world['monsters'] if m['id']!=identifier]+[dict(id=identifier,name=name,family='엘리트 구조체' if elite else '잔향 개체',description=detail,eventIDs=[identifier],bossID=None)]
    narration['encounters']=[n for n in narration['encounters'] if n['id']!=identifier]+[dict(id=identifier,eventIDs=[identifier],bossID=None,defeated=identifier+'_defeated',hit=identifier+'_hit')]
    lines[identifier+'_intro'] = {
        'mirror-moth':'거울 날개 나방이 나타났어요! 삼십 초 동안 편안한 달리기를 이어가면 날개의 잔향을 흩뜨릴 수 있어요.',
        'ash-boar':'재갑 멧돼지가 다가와요! 더 빨라질 필요는 없어요. 잠시 일정한 달리기를 이어가요.',
        'lost-sentinel':'유실 감시체를 발견했어요! 전에 상대했던 감시자와 닮았네요. 삼십 초 동안 차분하게 대응해요.',
        'hollow-knight':'공백 기사가 길을 막고 있어요! 사백 미터 동안 편안한 페이스로 공방을 이어가요.',
        'fallen-fairy':'타락한 요정이 환영을 펼쳤어요! 삼십 초 동안 일정한 달리기로 날개의 마력을 흩뜨려요.',
        'veil-witch':'장막의 마녀가 나타났어요! 안전한 구간이면 십 초 가속으로 틈을 공략해요. 유지 대응도 괜찮아요.'
    }[identifier]
    lines[identifier+'_survey']=name+'의 흔적을 찾았어요! 지금처럼 이동하면 제가 표본을 살펴볼게요.'
    lines[identifier+'_defeated']='잘했어요! '+name+'의 반응이 완전히 멈췄어요. 토벌 기록을 남겨둘게요.'
    lines[identifier+'_hit']='좋아요! '+name+'에게 피해를 줬어요. 남은 반응을 확인해볼게요.'
lines['hollow-knight_short']='공백 기사가 나타났어요! 이번에는 짧은 공방이에요. 삼십 초 동안 달리기를 이어가요.'
lines['veil-witch_steady']='마녀의 장막을 차근차근 걷어내요. 삼십 초 동안 편안한 달리기를 이어가요.'
lines.update({
    'quest_start':'선택한 의뢰를 시작해요! 오늘 모은 표본과 시간은 다음 활동으로 이어져요.',
    'quest_complete':'잘했어요! 의뢰에 필요한 기록을 모두 모았어요. 돌아가서 보상을 확인해요.',
    'exam_start':'승급 심사를 시작해요! 제가 관측을 맡을게요. 평소 페이스로 차근차근 대응해요.',
    'exam_pass':'축하해요! 심사 대상의 반응이 완전히 멈췄어요. 새로운 등급을 받을 준비가 됐어요!',
    'story_welcome':'안녕하세요! 오늘부터 함께할 전담 오퍼레이터예요. 저희 지부에서 첫 기록을 시작해봐요.',
    'story_return':'잘 다녀오셨어요. 오늘 함께 남긴 기록은 제가 잘 간직해둘게요.',
    'bond_greeting':'부르셨어요? 좋아요. 잠깐 쉬면서 이야기해요.',
})

# Different loadouts trade defense, attack and investigation utility. No real pace bonuses.
gear = [
('glass-rapier','거울결 세검','weapon','C',0,.45,0,.02,0),
('ash-mallet','재갑 파쇄추','weapon','B',18,.35,.08,0,0),
('return-blade','귀환의 검','weapon','A',0,.5,0,0,1),
('mirror-coat','굴절 방호 코트','armor','C',18,0,.20,.06,0),
('ash-cuirass','재갑 흉갑','armor','B',45,0,.28,0,0),
('return-jacket','귀환 관측복','armor','A',32,0,.22,0,1),
('echo-striders','잔광 기동화','shoes','C',10,.1,0,.15,0),
('ash-treads','재갑 전술화','shoes','B',18,0,.1,.1,0),
('anchor-boots','정착의 장화','shoes','A',12,0,.05,.2,0),
('glass-compass','거울 나침반','relic','C',8,0,0,.02,3),
('hollow-seal','공백 인장','relic','B',0,.2,.08,0,0),
('return-badge','귀환의 표식','relic','A',20,0,.06,0,2),
]
for identifier,name,slot,rank,hp,attack,defense,bonus,research in gear:
    tier=['C','B','A'].index(rank)
    detail=' · '.join(label for number,label in [(hp,f'HP +{hp}'),(attack,f'공격 +{attack:.2f}'),(defense,f'피해 경감 +{int(defense*100)}%'),(bonus,f'게임 판정 보정 +{int(bonus*100)}%'),(research,f'조사 보너스 +{research}')] if number)
    item=dict(id=identifier,name=name,slot=slot,detail=detail,crystals=80+tier*35,research=20+tier*15,cores=1+tier,supportLevel=3,requiredRank=rank,hp=hp,attack=attack,defense=defense,eventBonus=bonus,researchBonus=research)
    progression['equipment']=[e for e in progression['equipment'] if e['id']!=identifier]+[item]
for upgrade in progression['upgrades']:
    if upgrade['level']==3: upgrade['requiredRank']='C'
for encounter in encounters['encounters']:
    encounter['requiredMain'] = {'dark-elf-scout':'M06','succubus-weaver':'M07','dark-elf-captain':'M10','succubus-warden':'M11','mirror-moth':'M08','ash-boar':'M06','lost-sentinel':'M13','hollow-knight':'M16','fallen-fairy':'M06','veil-witch':'M10'}[encounter['id']]
    if '지부 조사 진행' not in encounter['unlockHint']: encounter['unlockHint'] += ' · 지부 조사 진행'
for boss in world['bosses']:
    boss['requiredMain'] = 'M10' if boss['id']=='boundary-lord' else 'M14'
for name,data in [('world',world),('encounters',encounters),('narration',narration),('progression',progression),('audio-lines',lines)]: write(name,data)
(ROOT/'docs'/'release-new-voice-keys.json').write_text(json.dumps([k for k in lines if k.startswith(tuple(m[0] for m in monsters)) or k in ['quest_start','quest_complete','exam_start','exam_pass','story_welcome','story_return','bond_greeting']],ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Content totals: {len(world["monsters"])} monsters, {len(progression["equipment"])} equipment, {len(lines)} voice lines.')
