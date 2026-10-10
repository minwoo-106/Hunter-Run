"""승인된 이야기·이미지·기존 음성을 덮어쓰지 않고 개편 운동 데이터만 생성한다."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
# 앞 12칸은 서서 운동, 뒤 4칸은 손·무릎 → 누운 자세 순서.
ROWS = '''
1|전신 적응|fastMarch step boxing crossKnee squatReach fastMarch squat wallPush backLunge sideCrunch hipHinge boxing kneePush birdDog bridge deadBug
2|구조팀 전신 지원|step crossKnee boxing skater fastMarch squatReach backLunge squat wallPush hipHinge sideCrunch boxing birdDog kneePush deadBug bridge
3|하체와 밀기|fastMarch step squatReach crossKnee boxing step squat backLunge wallPush hipHinge squat heel kneePush plank bridge deadBug
4|움직임 정비|march step knee heel step march hipHinge wallPush sideCrunch heel squat march birdDog birdDog bridge deadBug
5|방어선 유산소|fastMarch skater boxing crossKnee squatReach fastMarch boxing backLunge step squat crossKnee boxing kneePush birdDog deadBug heelTouch
6|복구 근력|step fastMarch boxing squatReach crossKnee step backLunge wallPush squat hipHinge heel squat plank kneePush bridge bridge
7|전신 연결|boxing step crossKnee fastMarch skater squatReach squat backLunge sideCrunch wallPush hipHinge boxing birdDog plank deadBug bridge
8|조용한 균형|step march heel knee march step wallPush hipHinge sideCrunch squat heel march birdDog birdDog deadBug bridge
9|하체 지지|crossKnee fastMarch step squatReach boxing step squat hipHinge backLunge wallPush heel squat kneePush plank bridge deadBug
10|중앙 통로 전신|fastMarch boxing skater crossKnee squatReach boxing backLunge squat sideCrunch wallPush hipHinge fastMarch kneePush birdDog heelTouch deadBug
11|몸통 제어|step knee march heel crossKnee step hipHinge sideCrunch wallPush squat heel march birdDog plank deadBug bridge
12|구조팀 교대|skater step boxing fastMarch crossKnee squatReach wallPush backLunge squat boxing hipHinge sideCrunch kneePush birdDog bridge heelTouch
13|전신 순환|crossKnee boxing fastMarch skater squatReach step squat wallPush backLunge sideCrunch boxing hipHinge plank birdDog deadBug bridge
14|회복과 정비|march heel step knee step march squat hipHinge wallPush heel sideCrunch march birdDog birdDog bridge bridge
15|격리벽 근력|fastMarch squatReach step boxing crossKnee fastMarch backLunge squat wallPush heel hipHinge squat kneePush plank bridge heelTouch
16|길 확보 유산소|boxing fastMarch skater crossKnee step squatReach squat boxing backLunge wallPush sideCrunch fastMarch birdDog kneePush deadBug heelTouch
17|지지와 균형|step crossKnee fastMarch squatReach boxing skater hipHinge backLunge squat wallPush heel sideCrunch plank birdDog bridge deadBug
18|호흡과 제어|march step heel knee crossKnee march wallPush sideCrunch hipHinge squat march heel birdDog birdDog deadBug deadBug
19|복구 지구력|squatReach fastMarch boxing step crossKnee step squat wallPush hipHinge backLunge heel squat plank kneePush bridge heelTouch
20|지원팀 전신|fastMarch skater crossKnee boxing squatReach step backLunge wallPush squat sideCrunch hipHinge boxing kneePush birdDog bridge heelTouch
21|방어선 리듬|step boxing fastMarch crossKnee skater squatReach boxing squat backLunge crossKnee wallPush fastMarch plank birdDog deadBug heelTouch
22|전신 제어|crossKnee step squatReach fastMarch boxing step hipHinge squat wallPush sideCrunch backLunge heel birdDog plank bridge deadBug
23|가벼운 정비|heel march step knee march step hipHinge squat sideCrunch wallPush heel march birdDog birdDog bridge heelTouch
24|상체와 하체|boxing step fastMarch crossKnee squatReach skater wallPush squat backLunge hipHinge boxing heel kneePush plank deadBug bridge
25|마지막 방어선 준비|fastMarch crossKnee boxing skater step squatReach squat backLunge wallPush boxing hipHinge sideCrunch birdDog kneePush heelTouch bridge
26|지속 방어|skater fastMarch step boxing crossKnee squatReach backLunge boxing squat fastMarch sideCrunch wallPush plank birdDog deadBug heelTouch
27|최종 복구|step squatReach boxing fastMarch skater crossKnee wallPush backLunge hipHinge squat heel wallPush kneePush plank bridge deadBug
28|다음 작전 회복|march knee step heel step march sideCrunch wallPush heel hipHinge squat march birdDog birdDog deadBug heelTouch
29|전신 교대|boxing crossKnee skater fastMarch squatReach step hipHinge squat backLunge wallPush sideCrunch boxing kneePush birdDog heelTouch deadBug
30|마지막 파동 전신|fastMarch step crossKnee boxing skater squatReach squat wallPush backLunge hipHinge sideCrunch boxing birdDog kneePush bridge deadBug
'''.strip()
episodes=[]
for row in ROWS.splitlines():
    n, focus, moves = row.split('|')
    episodes.append(dict(episode=int(n), focus=focus, exercises=moves.split()))
assert all(len(w['exercises']) == 16 for w in episodes)
(ROOT/'Resources/defense-workouts.json').write_text(json.dumps(dict(version=2,episodes=episodes),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('30회 개편 운동 데이터 생성 완료. 기존 캠페인 자료는 보존했습니다.')
names = dict(march='제자리 걷기', step='좌우 스텝', knee='무릎 올리기', squat='스쿼트',
    wallPush='벽 푸시업', heel='뒤꿈치 들기', boxing='섀도복싱', fastMarch='빠른 제자리 걷기',
    crossKnee='교차 무릎 올리기', skater='점프 없는 스케이터 스텝', squatReach='스쿼트와 팔 뻗기',
    backLunge='번갈아 백 런지', sideCrunch='서서 옆구리 접기', hipHinge='힙 힌지',
    kneePush='무릎 푸시업', birdDog='버드독', plank='무릎 플랭크', bridge='힙 브리지',
    deadBug='데드버그', heelTouch='누워 뒤꿈치 터치')
tips = dict(march='편하게 걸어요', step='좌우로 한 걸음씩 옮겨요', knee='무릎을 번갈아 올려요',
    squat='엉덩이를 뒤로 보내며 앉았다 일어나요', wallPush='벽에 손을 대고 팔을 굽혔다 펴요',
    heel='뒤꿈치를 천천히 들었다 내려요', boxing='주먹을 번갈아 앞으로 뻗어요',
    fastMarch='팔을 흔들며 조용히 걸어요', crossKnee='무릎과 반대 손을 가까이 가져와요',
    skater='뛰지 않고 좌우로 한 걸음씩 옮겨요', squatReach='일어나며 팔을 뻗어요',
    backLunge='한 발씩 뒤로 짚고 얕게 앉아요', sideCrunch='좌우로 무릎과 팔꿈치를 가까이 가져와요',
    hipHinge='엉덩이를 뒤로 보내며 상체를 기울여요', kneePush='무릎을 짚고 팔을 굽혔다 펴요',
    birdDog='반대 팔과 다리를 번갈아 뻗어요', plank='팔꿈치와 무릎을 짚고 유지해요',
    bridge='누워서 엉덩이를 들었다 내려요', deadBug='누워서 반대 팔과 다리를 내려요',
    heelTouch='누워서 손을 좌우 뒤꿈치 쪽으로 뻗어요')
lines = {'defense_v2_move_'+key: f'{name}. {tips[key]}.' for key, name in names.items()}
for intensity, seconds in [('light',30),('standard',45),('challenge',50)]:
    lines['defense_v2_seconds_'+intensity] = f'시작하면 {seconds}초 움직여요.'
lines.update({
    'defense_v2_warm_last':'얕은 스쿼트로 마무리해요. 천천히 앉았다 일어나요. 준비가 더 필요하면 잠깐 멈춰도 좋아요.',
    'defense_v2_floor':'이제 바닥 동작이에요. 매트에 손과 무릎을 짚고 준비해요. 아직 시작하지 않아요. 서두르지 않아도 돼요.',
    'defense_v2_standing':'계속 서서 진행할게요. 잠깐 숨을 고르고 다음 동작을 준비해요.',
    'defense_v2_cool_floor':'바닥에서 편하게 쉬어요. 무릎을 세우고 누워서 천천히 호흡해요. 교전은 끝났어요.',
    'defense_v2_cool_stand':'옆으로 돌아앉아 천천히 일어나요. 어지럽다면 앉아서 더 쉬어요. 준비되면 가볍게 걸어요.',
    'defense_v2_resume':'지금 자세에서 편하게 쉬어요. 다음 안내부터 남은 구간을 이어갈게요.',
})
(ROOT/'Resources/defense-workout-lines.json').write_text(json.dumps(lines,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
