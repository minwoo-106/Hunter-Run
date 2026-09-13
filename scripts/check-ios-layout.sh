#!/bin/bash
set -euo pipefail
mkdir -p build
xcrun simctl list devices available --json > build/simulators.json
xcrun simctl list devicetypes --json > build/device-types.json
xcrun simctl list runtimes --json > build/runtimes.json
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
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tee build/layout-log.txt || status=$?
# Keep a directly downloadable screenshot even when the assertion fails.
xcrun simctl terminate "$DEVICE_ID" com.hunterrun.demo || true
xcrun simctl launch "$DEVICE_ID" com.hunterrun.demo --ui-testing-skip-welcome --ui-testing-silent-audio || true
sleep 3
xcrun simctl io "$DEVICE_ID" screenshot build/Home-layout.png || true
if [ "$status" -eq 0 ]; then
mkdir -p build/portrait-checks
for expression in calm smile playful thoughtful worried relieved; do
  xcrun simctl launch --terminate-running-process "$DEVICE_ID" com.hunterrun.demo --ui-testing-portrait --expression "$expression" --time 0
  sleep 1
  xcrun simctl io "$DEVICE_ID" screenshot "build/portrait-checks/$expression.png"
done
xcrun simctl launch --terminate-running-process "$DEVICE_ID" com.hunterrun.demo --ui-testing-portrait --expression calm --time 3.88
sleep 1
xcrun simctl io "$DEVICE_ID" screenshot build/portrait-checks/blink.png
xcrun simctl launch --terminate-running-process "$DEVICE_ID" com.hunterrun.demo --ui-testing-portrait --expression calm --time 1.3
sleep 1
xcrun simctl io "$DEVICE_ID" screenshot build/portrait-checks/breath.png
SMALL_DEVICE_ID=$(python3 - <<'PY'
import json, subprocess
with open('build/simulators.json') as source:
    devices = [d for ds in json.load(source)['devices'].values() for d in ds if d['isAvailable'] and 'iPhone' in d['name']]
preferred = ['iPhone SE (3rd generation)', 'iPhone 16e', 'iPhone 16']
device = next((d for name in preferred for d in devices if d['name'] == name), None)
if device:
    print(device['udid'])
else:
    types = json.load(open('build/device-types.json'))['devicetypes']
    runtimes = [r for r in json.load(open('build/runtimes.json'))['runtimes'] if r['isAvailable'] and r['name'].startswith('iOS')]
    created = None
    for name in preferred:
        kind = next((t for t in types if t['name'] == name), None)
        if kind and runtimes:
            attempt = subprocess.run(['xcrun', 'simctl', 'create', 'HunterRun Compact QA', kind['identifier'], runtimes[-1]['identifier']], capture_output=True, text=True)
            if attempt.returncode == 0:
                created = attempt.stdout.strip()
                print(created)
                break
    if not created: raise SystemExit('No compatible compact iPhone simulator could be created')
PY
)
if [ -n "$SMALL_DEVICE_ID" ] && [ "$SMALL_DEVICE_ID" != "$DEVICE_ID" ]; then
  xcrun simctl shutdown "$DEVICE_ID" || true
  xcrun simctl boot "$SMALL_DEVICE_ID" || true
  xcrun simctl bootstatus "$SMALL_DEVICE_ID" -b
  xcodebuild -project HunterRun.xcodeproj -scheme HunterRun -configuration Debug \
    -destination "platform=iOS Simulator,id=$SMALL_DEVICE_ID" -derivedDataPath build/layout \
    -resultBundlePath build/Small-layout.xcresult -parallel-testing-enabled NO \
    -only-testing:HunterRunUITests/HomeLayoutTests/testHomeFitsScreen \
    -only-testing:HunterRunUITests/HomeLayoutTests/testFirstRegistrationAcceptsCustomNamesAndOpensStory \
    -only-testing:HunterRunUITests/HomeLayoutTests/testLargeTextKeepsStoryAndSettingsReachable \
    CODE_SIGNING_ALLOWED=NO test-without-building 2>&1 | tee build/small-layout-log.txt || status=$?
  xcrun simctl launch "$SMALL_DEVICE_ID" com.hunterrun.demo --ui-testing-skip-welcome --ui-testing-silent-audio || true
  xcrun simctl io "$SMALL_DEVICE_ID" screenshot build/Small-layout.png || true
fi
fi
exit "$status"
