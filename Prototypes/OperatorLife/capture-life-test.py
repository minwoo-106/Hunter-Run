"""Capture the real simulator wake test, not a recreated browser animation."""
import pathlib
import signal
import subprocess
import sys
import time

log, device, destination = sys.argv[1:]
path = pathlib.Path(log)
marker = 'testNaturalSequenceConsumesWakeTapAndReturnsToIdle'
deadline = time.monotonic() + 1200
recorder = None
try:
    while time.monotonic() < deadline:
        text = path.read_text(errors='replace') if path.exists() else ''
        lines = [line for line in text.splitlines() if marker in line]
        if recorder is None and any('started' in line for line in lines):
            recorder = subprocess.Popen(['xcrun', 'simctl', 'io', device, 'recordVideo', '--codec=h264', destination],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if recorder is not None and any('passed' in line or 'failed' in line for line in lines):
            time.sleep(1)
            break
        time.sleep(0.5)
finally:
    if recorder is not None and recorder.poll() is None:
        recorder.send_signal(signal.SIGINT)
        try:
            recorder.wait(timeout=15)
        except subprocess.TimeoutExpired:
            recorder.terminate()
            recorder.wait(timeout=5)
