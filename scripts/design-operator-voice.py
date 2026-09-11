"""Generate original operator auditions with a locally downloaded VoiceDesign model."""
import argparse, hashlib, json, time
from pathlib import Path
import numpy as np
import soundfile as sf
import torch
from qwen_tts import Qwen3TTSModel

parser = argparse.ArgumentParser()
parser.add_argument("--model", required=True)
parser.add_argument("--output", required=True)
parser.add_argument("--round", choices=["initial", "brighter"], default="initial")
args = parser.parse_args()
out = Path(args.output); out.mkdir(parents=True, exist_ok=True)
torch.set_num_threads(4)
text = "오셨네요. 오늘도 함께하겠습니다. 마력 흔적을 발견했어요. 천천히 이동하면서 조사해 볼까요? 제가 곁에서 안내할게요."
styles = [
 ("clear", "맑고 다정한 톤", 741,
  "A young adult Korean woman in her mid twenties, a friendly fantasy game operator. A clear, delicate, slightly high-pitched feminine voice with a small warm smile and a naturally cute charm. Calm, reassuring, intimate conversational delivery. Soft precise Korean pronunciation, gentle melodic intonation, measured comfortable pace, relaxed sentence endings. Studio clean voice."),
 ("velvet", "부드럽고 차분한 톤", 928,
  "A young adult Korean female game character, a composed and kind operator in her late twenties. Soft velvety feminine timbre, medium pitch, subtly airy edges and warm resonance. Quietly playful warmth with a charming gentle smile, unhurried and reassuring conversational delivery. Natural Korean diction, understated emotion and smooth gentle sentence endings. Clean close microphone recording.")
]
if args.round == "brighter":
    original = styles[0][3]
    styles = [
      ("bright_gentle", "밝고 다정한 조정", 741,
       original.replace("a small warm smile", "a bright warm smile").replace("Calm, reassuring, intimate conversational delivery.", "Calm yet cheerful and confident conversational delivery, with a little more spirited energy and a smile audible in her voice.") + " Keep subtle natural breaths between phrases. Clear supported sentence endings, friendly and ready to help."),
      ("bright_spirited", "한층 씩씩한 조정", 741,
       original.replace("a small warm smile", "a lively warm smile").replace("Calm, reassuring, intimate conversational delivery.", "Bright, spirited, upbeat and confidently reassuring conversational delivery, like a capable friendly teammate eager to start the mission.").replace("measured comfortable pace, relaxed sentence endings", "comfortable lightly buoyant pace, clear energized sentence endings") + " Keep delicate natural audible breaths between phrases and the soft feminine texture. Positive warm enthusiasm with composed clear guidance.")
    ]
print("Loading voice design model", flush=True)
model = Qwen3TTSModel.from_pretrained(args.model, device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")
records=[]
for key, label, seed, instruct in styles:
    torch.manual_seed(seed); np.random.seed(seed)
    print("Generating " + key, flush=True); start=time.time()
    wavs, sr = model.generate_voice_design(text=text, language="Korean", instruct=instruct, max_new_tokens=700, do_sample=True, temperature=0.8)
    audio=np.asarray(wavs[0], dtype=np.float32)
    active=np.flatnonzero(np.abs(audio)>.003)
    if len(active): audio=audio[max(0,active[0]-int(sr*.08)):min(len(audio),active[-1]+int(sr*.12))]
    rms=float(np.sqrt(np.mean(audio**2))); peak=float(np.max(np.abs(audio)))
    assert rms>0.001 and peak>0.01, "Silent output"
    audio *= min(.1/rms, .89/peak)
    path=out/("operator_"+key+".wav"); sf.write(path,audio,sr,subtype="PCM_16")
    records.append(dict(file=path.name,label=label,seed=seed,instruct=instruct,text=text,sample_rate=sr,duration=round(len(audio)/sr,2),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    (out/"manifest.json").write_text(json.dumps(dict(model="Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",revision="5ecdb67327fd37bb2e042aab12ff7391903235d3",status="audition-not-approved",clips=records),ensure_ascii=False,indent=2),encoding="utf-8")
    print(f"Saved {path} {len(audio)/sr:.2f}s in {time.time()-start:.1f}s",flush=True)
