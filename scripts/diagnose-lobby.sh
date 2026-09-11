#!/bin/bash
set -euo pipefail
mkdir -p build
xcrun simctl list devices available --json > build/simulators.json
DEVICE_ID=$(python3 - <<'PY'
import json
with open('build/simulators.json') as f:
    devices = [d for ds in json.load(f)['devices'].values() for d in ds if d['isAvailable'] and 'iPhone' in d['name']]
print(next((d for d in devices if d['name'] == 'iPhone 17 Pro'), devices[0])['udid'])
PY
)
xcrun simctl boot "$DEVICE_ID" || true
xcrun simctl bootstatus "$DEVICE_ID" -b
xcodebuild -project HunterRun.xcodeproj -scheme HunterRun -configuration Debug -destination "platform=iOS Simulator,id=$DEVICE_ID" -derivedDataPath build/layout CODE_SIGNING_ALLOWED=NO build-for-testing > build/diagnostic-compile.txt 2>&1 || { tail -80 build/diagnostic-compile.txt; exit 1; }
xcrun simctl install "$DEVICE_ID" build/layout/Build/Products/Debug-iphonesimulator/HunterRun.app
for enabled in NO YES; do
    launch=$(xcrun simctl launch "$DEVICE_ID" com.hunterrun.demo -homeMusicEnabled "$enabled")
    pid=${launch##*: }
    sleep 12
    echo "[DEBUG-lobby] BGM=$enabled process=$pid"
    sample "$pid" 2 1 -file "build/lobby-$enabled.txt" >/dev/null 2>&1 || true
    head -110 "build/lobby-$enabled.txt" || true
    xcrun simctl io "$DEVICE_ID" screenshot "build/lobby-$enabled.png" || true
    xcrun simctl terminate "$DEVICE_ID" com.hunterrun.demo || true
done
