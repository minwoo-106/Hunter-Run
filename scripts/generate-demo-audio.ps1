# Windows offline speech, temporary personal-test audio only.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$projectRoot = Split-Path -Parent $PSScriptRoot
$audioDir = Join-Path $projectRoot 'Resources/Audio'
New-Item -ItemType Directory -Force -Path $audioDir | Out-Null
$lines = @{
    audio_test = '통신 확인. 음악과 함께 제 목소리가 들리시나요?'
    run_start = '의뢰를 시작합니다. 편안한 페이스로 이동하세요.'
    run_end = '활동을 마쳤습니다. 확보한 기록을 정리할게요.'
    pause = '잠시 대기할게요.'
    resume = '다시 이동합니다.'
    discovery = '마력 흔적을 발견했어요. 편하게 이동하며 조사하겠습니다.'
    maintain = '개체가 접근합니다. 평소 달리기 페이스를 유지해주세요.'
    pursuit = '추적 가능해요. 안전한 구간이면 조금 가속하세요. 아니면 흔적을 조사할게요.'
    pursuit_started = '추적을 시작합니다.'
    investigate = '주변 흔적을 조사하겠습니다.'
    boss = '신호원을 찾았어요. 평소 페이스로 달리며 안정화해주세요.'
    success = '성과를 확보했습니다.'
    partial = '확보한 성과를 보존하고 이동하겠습니다.'
    signal = '측정이 불안정해요. 속도 평가는 중단할게요.'
}
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
    $synth.SelectVoice('Microsoft Heami Desktop')
    $synth.Rate = 1
    foreach ($entry in $lines.GetEnumerator()) {
        $synth.SetOutputToWaveFile((Join-Path $audioDir ($entry.Key + '.wav')))
        $synth.Speak($entry.Value)
        $synth.SetOutputToNull()
    }
} finally { $synth.Dispose() }
$lines | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $projectRoot 'Resources/audio-lines.json') -Encoding utf8
Write-Output ('Generated ' + $lines.Count + ' offline demo clips.')

