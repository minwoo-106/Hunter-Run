"""개편 30회 운동 자료와 음성의 형식·시간·승인 여부를 확인한다."""
import argparse, hashlib, json, wave
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('--require-approval',action='store_true'); args=p.parse_args()
root=Path(__file__).resolve().parents[1]
load=lambda path:json.loads((root/path).read_text(encoding='utf-8'))
workouts=load('Resources/defense-workouts.json'); lines=load('Resources/defense-workout-lines.json')
voice=load('Resources/defense-workout-voice.json')
assert workouts['version']==2 and [w['episode'] for w in workouts['episodes']]==list(range(1,31))
posture={x:1 for x in ['kneePush','birdDog','plank']}|{x:2 for x in ['bridge','deadBug','heelTouch']}
for w in workouts['episodes']:
    moves=w['exercises']; assert len(moves)==16 and w['focus']
    assert all(posture.get(m,0)==0 for m in moves[:12])
    assert all(posture.get(m,0)>0 for m in moves[12:])
    ranks=[posture.get(m,0) for m in moves]; assert ranks==sorted(ranks)
    assert all('defense_v2_move_'+m in lines for m in moves)
assert len(lines)==len(voice['clips'])==29
clips={c['key']:c for c in voice['clips']}; assert set(clips)==set(lines)
for key,c in clips.items():
    assert c['text']==lines[key] and c['file']==key+'.wav'
    path=root/'Resources/DefenseAudio'/c['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest()==c['sha256']
    with wave.open(str(path)) as f:
        assert (f.getnchannels(),f.getsampwidth(),f.getframerate())==(1,2,24000)
        assert abs(f.getnframes()/24000-c['duration'])<.002
for w in workouts['episodes']:
    for intensity in ['light','standard','challenge']:
        # 도전의 가장 짧은 준비 구간에도 안내를 끝낸 뒤 여유가 남아야 한다.
        for move in w['exercises']+['wallPush','hipHinge','squat','crossKnee','sideCrunch']:
            assert clips['defense_v2_move_'+move]['duration']+clips['defense_v2_seconds_'+intensity]['duration']<=9
old={c['key']:c for c in load('Resources/defense-voice.json')['clips']}
for n in range(1,31):
    assert old[f'defense_{n:02}_rest2']['duration']+clips['defense_v2_floor']['duration']<58
    assert clips['defense_v2_cool_floor']['duration']+old[f'defense_{n:02}_outro']['duration']<58
if args.require_approval:
    approval=root/'docs/indoor-defense/reviews/workout-v2-approval.json'
    assert approval.is_file(), '신규 운동 안내 음성 사용자 승인 전에는 설치 파일을 만들지 않습니다.'
    assert json.loads(approval.read_text(encoding='utf-8'))['voices']=={k:c['sha256'] for k,c in clips.items()}
print('개편 30회 운동 / 신규 안내 29개 / 준비·회복 구간 음성 길이 검증 통과')
