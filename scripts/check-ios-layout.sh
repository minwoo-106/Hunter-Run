#!/bin/bash
set -euo pipefail
mkdir -p build
xcrun simctl list devices available --json > build/simulators.json
DEVICE_ID=$(python3 - <<'PY'
import json
with open('build/simulators.json') as source:
    devices = [d for ds in json.load(source)['devices'].values() for d in ds if d['isAvailable'] and 'iPhone' in d['name']]
device = next((d for d in devices if d['name'] == 'iPhone 17 Pro'), devices[0])
print(device['udid'])
PY
)
xcrun simctl boot "$DEVICE_ID" || true
xcrun simctl bootstatus "$DEVICE_ID" -b
status=0
xcodebuild -project HunterRun.xcodeproj -scheme HunterRun -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" -derivedDataPath build/layout \
  -resultBundlePath build/Layout.xcresult -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test > build/layout-log.txt 2>&1 || status=$?
cat build/layout-log.txt
# Keep a directly downloadable screenshot even when the assertion fails.
xcrun simctl terminate "$DEVICE_ID" com.hunterrun.demo || true
xcrun simctl launch "$DEVICE_ID" com.hunterrun.demo || true
sleep 3
xcrun simctl io "$DEVICE_ID" screenshot build/Home-layout.png || true
exit "$status"
