"""Original short synthesized UI cues, generated offline without external samples."""
from pathlib import Path
import math, struct, wave
root=Path(__file__).resolve().parents[1]/'Resources/Effects'
root.mkdir(parents=True,exist_ok=True)
for name,notes,duration in [('ui-select',[660,880],.16),('ui-reward',[523.25,659.25,783.99],.48),('ui-gate',[392,523.25,784],.36)]:
    samples=[]
    for index in range(int(24000*duration)):
        t=index/24000
        value=0
        for n,f in enumerate(notes):
            local=t-n*duration/(len(notes)*2)
            if local>=0:
                envelope=min(1,local/.008)*math.exp(-local*14)*(max(0,1-t/duration))
                value+=math.sin(2*math.pi*f*local)*envelope/len(notes)
        samples.append(int(value*10000))
    with wave.open(str(root/(name+'.wav')),'wb') as output:
        output.setnchannels(1); output.setsampwidth(2); output.setframerate(24000)
        output.writeframes(struct.pack('<'+'h'*len(samples),*samples))
print('Generated three original interface cues.')
