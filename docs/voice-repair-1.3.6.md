# 1.3.6 build34 오퍼레이터 음성 수정

사용자가 들었을 때 목소리가 다르거나 끝에서 바뀌는 새 대사 7개를 다시 합성했습니다. 모두 승인된 `run_start.wav`를 참조했으며, 재합성 후 한 파일 안의 앞·뒤 2초와 참조 음성의 화자 임베딩 유사도를 확인했습니다. 이 지표는 음색 변화의 자동 검수용이며 최종 청감 판단을 대신하지 않습니다.

| 파일 키 | 수정 전 최저 유사도 | 수정 후 최저 유사도 |
| --- | ---: | ---: |
| `corrupted-hunter_hit` | 0.9535 | 0.9796 |
| `corrupted-hunter_phase1` | 0.9597 | 0.9806 |
| `corrupted-vanguard-archer_intro` | 0.9592 | 0.9842 |
| `mirror-witch_steady` | 0.9622 | 0.9815 |
| `ironclad-rhino_survey` | 0.9627 | 0.9809 |
| `ironhide-charger_defeated` | 0.9595 | 0.9852 |
| `ironhide-charger_survey` | 0.9621 | 0.9841 |

검수 기준은 세 비교값(앞/참조, 뒤/참조, 앞/뒤)이 모두 0.975 이상인 것입니다. 재현 명령은 Qwen3 TTS 음성 생성 환경에서 `python scripts/audit-voice-consistency.py --assert-consistent --model <모델 경로> --reference docs/voice-audition/consistent-approved/run_start.wav --audio-dir Resources/Audio <위 7개 키>`입니다. 기존 일곱 파일은 이 검사에서 실패했고, 교체 후에는 통과했습니다.

거울마녀의 안내 문장은 의미를 유지하면서 “거울마녀의 결계가 약해지고 있어요! 삼십 초 동안 평소 페이스를 이어가요.”로 다듬었습니다. 새 음성의 발음·감정·문장 전체의 자연스러움은 [번호별 미리듣기](voice-review-1.3.6/index.html)에서 직접 확인해야 합니다.
