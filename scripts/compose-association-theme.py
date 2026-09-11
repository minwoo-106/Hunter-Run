"""Original instrumental lobby sketch, synthesized locally; no sampled recordings."""
import pathlib, wave
import numpy as np

RATE, SECONDS = 44100, 32
t = np.arange(RATE * SECONDS) / RATE
mix = np.zeros((len(t), 2))

def note(midi, start, duration, level, pan, bell=False):
    age = (t - start) % SECONDS
    freq = 440 * 2 ** ((midi - 69) / 12)
    envelope = np.minimum(age / (0.03 if bell else 1.3), 1)
    envelope *= np.minimum(np.maximum(duration - age, 0) / (1.8 if bell else 2.0), 1)
    if bell:
        envelope *= np.exp(-age / 1.6)
        tone = np.sin(2*np.pi*freq*age) + .16*np.sin(2*np.pi*freq*2*age)
    else:
        tone = np.sin(2*np.pi*freq*age) + .12*np.sin(2*np.pi*freq*2*age) + .04*np.sin(2*np.pi*freq*3*age)
    signal = level * envelope * tone
    mix[:, 0] += signal * np.sqrt((1-pan)/2)
    mix[:, 1] += signal * np.sqrt((1+pan)/2)

chords = [[45,52,59,60,64], [41,48,52,57,64], [48,55,59,62,64], [43,50,55,60,62]]
for bar, chord in enumerate(chords):
    for index, pitch in enumerate(chord):
        note(pitch, bar*8, 10, .055 if index else .065, (index-2)*.16)
melodies = [[76,71,72,64], [69,76,72,67], [71,74,76,67], [74,72,69,71]]
for bar, pitches in enumerate(melodies):
    for step, pitch in enumerate(pitches):
        start = bar*8 + .6 + step*1.75
        note(pitch, start, 5, .1, -.25 if step%2 else .25, True)
        note(pitch, start+.37, 4, .027, .4 if step%2 else -.4, True)
mix *= .25 / np.max(np.abs(mix))
pcm = np.round(mix*32767).astype('<i2')
path = pathlib.Path(__file__).resolve().parents[1] / 'Resources/Music/association-theme.wav'
path.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(path), 'wb') as output:
    output.setnchannels(2); output.setsampwidth(2); output.setframerate(RATE)
    output.writeframes(pcm.tobytes())
assert np.max(np.abs(pcm.astype(int))) <= 8192
assert np.max(np.abs(pcm[0].astype(int)-pcm[-1].astype(int))) < 500
print(f'Original lobby sketch: {SECONDS}s stereo PCM, peak -12dBFS, loop boundary checked.')
