"""Offline candidate production. Model and inference source stay outside the app/repo."""
import argparse, hashlib, json, pathlib, sys
import numpy as np
import onnxruntime as ort
import soundfile as sf

p = argparse.ArgumentParser()
p.add_argument('--engine-root', type=pathlib.Path, required=True)
p.add_argument('--assets', type=pathlib.Path, required=True)
p.add_argument('--output', type=pathlib.Path, required=True)
p.add_argument('--extra-previews', action='store_true')
args = p.parse_args()
sys.path.insert(0, str(args.engine_root / 'py'))
from helper import load_cfgs, load_onnx_all, load_text_processor, TextToSpeech, load_voice_style

opts = ort.SessionOptions(); opts.intra_op_num_threads = 4; opts.inter_op_num_threads = 1
onnx_dir = str(args.assets / 'onnx')
engine = TextToSpeech(load_cfgs(onnx_dir), load_text_processor(onnx_dir), *load_onnx_all(onnx_dir, opts, ['CPUExecutionProvider']))
root = pathlib.Path(__file__).resolve().parents[1]
lines = json.loads((root / 'Resources/audio-lines.json').read_text(encoding='utf-8'))
lines['run_start'] = '헌터 활동을 시작합니다. 편안한 페이스로 이동하세요.'
preview = '오셨네요. 오늘도 함께하겠습니다. 마력 흔적을 발견했어요. 편하게 이동하며 조사할게요. 성과를 확보했습니다. 수고하셨어요.'
args.output.mkdir(parents=True, exist_ok=True)
manifest = {'model': 'supertone-oss-archive/supertonic-3', 'revision': 'aafc6e32416a594460b32413efc49d7fe4ce6d46', 'language': 'ko', 'speed': 1.0, 'steps': 10, 'status': 'candidate-not-final', 'clips': []}
choices = [('D', 'F4'), ('E', 'F5')] if args.extra_previews else [('A', 'F1'), ('B', 'F2'), ('C', 'F3')]
for candidate, voice in choices:
    style = load_voice_style([str(args.assets / 'voice_styles' / (voice + '.json'))])
    scripts = [('preview', preview)] if args.extra_previews else [('preview', preview), *lines.items()]
    for key, text in scripts:
        seed = int.from_bytes(hashlib.sha256((candidate + key).encode()).digest()[:4], 'little')
        np.random.seed(seed)
        wav, duration = engine(text, 'ko', style, 10, 1.0)
        samples = wav[0, :int(engine.sample_rate * float(duration[0]))].astype(np.float64)
        assert np.isfinite(samples).all() and len(samples) > 0
        audible = np.flatnonzero(np.abs(samples) > 0.003)
        assert len(audible), (candidate, key, 'silent')
        pad = int(engine.sample_rate * 0.06)
        samples = samples[max(0, audible[0] - pad):min(len(samples), audible[-1] + pad)]
        gain = min(10 ** (-20 / 20) / max(1e-6, np.sqrt(np.mean(samples ** 2))), 0.89 / np.max(np.abs(samples)))
        samples *= gain
        name = f'voice{candidate}_{key}.wav'
        dest = args.output / name
        sf.write(dest, samples, engine.sample_rate, subtype='PCM_16')
        seconds = len(samples) / engine.sample_rate
        assert 0.3 < seconds < (30 if key == 'preview' else 15), (name, seconds)
        manifest['clips'].append({'file': name, 'candidate': candidate, 'preset': voice, 'key': key, 'text': text, 'seconds': round(seconds, 3), 'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()})
        print(f'{name}: {seconds:.2f}s', flush=True)
(args.output / 'voice-candidates.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
