#!/bin/bash
set -euo pipefail
mkdir -p build
xcrun simctl list devicetypes --json > build/device-types.json
xcrun simctl list runtimes --json > build/runtimes.json
DEVICE_ID=$(python3 - <<'PY'
import json, subprocess
types = json.load(open('build/device-types.json'))['devicetypes']
runtimes = [r for r in json.load(open('build/runtimes.json'))['runtimes'] if r['isAvailable'] and r['name'].startswith('iOS')]
for name in ['iPhone SE (3rd generation)', 'iPhone 16e', 'iPhone 16']:
    kind = next((t for t in types if t['name'] == name), None)
    if kind and runtimes:
        result = subprocess.run(['xcrun', 'simctl', 'create', name + ' QA', kind['identifier'], runtimes[-1]['identifier']], capture_output=True, text=True)
        if result.returncode == 0:
            print(result.stdout.strip()); break
else: raise SystemExit('No compatible compact iPhone could be created')
PY
)
xcrun simctl boot "$DEVICE_ID"
xcrun simctl bootstatus "$DEVICE_ID" -b
status=0
xcodebuild -project HunterRun.xcodeproj -scheme HunterRun -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" -derivedDataPath build/layout \
  -resultBundlePath build/Small-layout.xcresult -parallel-testing-enabled NO \
  -only-testing:HunterRunUITests/HomeLayoutTests/testHomeFitsScreen \
  -only-testing:HunterRunUITests/HomeLayoutTests/testFirstRegistrationAcceptsCustomNamesAndOpensStory \
  -only-testing:HunterRunUITests/HomeLayoutTests/testLargeTextKeepsStoryAndSettingsReachable \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tee build/small-layout-log.txt || status=$?
xcrun simctl launch --terminate-running-process "$DEVICE_ID" com.hunterrun.demo --ui-testing-skip-welcome --ui-testing-silent-audio || true
sleep 2
xcrun simctl io "$DEVICE_ID" screenshot build/Small-layout.png || true
exit "$status"
