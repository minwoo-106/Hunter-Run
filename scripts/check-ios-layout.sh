#!/bin/bash
set -euo pipefail
mkdir -p build
python3 scripts/run-bounded.py --timeout 90 -- xcrun simctl list devices available --json > build/simulators.json
python3 scripts/run-bounded.py --timeout 90 -- xcrun simctl list devicetypes --json > build/device-types.json
python3 scripts/run-bounded.py --timeout 90 -- xcrun simctl list runtimes --json > build/runtimes.json
export HUNTER_SIMULATOR_SDK=$(xcrun --sdk iphonesimulator --show-sdk-version)
DEVICE_ID=$(python3 - <<'PY'
import json, os, sys
sdk = os.environ['HUNTER_SIMULATOR_SDK']
runtimes = [r for r in json.load(open('build/runtimes.json'))['runtimes']
            if r['isAvailable'] and r['name'].startswith('iOS') and (r['version'] == sdk or r['version'].startswith(sdk + '.'))]
if not runtimes: raise SystemExit('No iOS runtime matching the selected Xcode simulator SDK: ' + sdk)
with open('build/simulators.json') as source:
    devices = [d for d in json.load(source)['devices'].get(runtimes[0]['identifier'], []) if d['isAvailable'] and 'iPhone' in d['name']]
if not devices: raise SystemExit('No available iPhone on the selected runtime')
device = next((d for name in ['iPhone 16 Pro', 'iPhone 17 Pro', 'iPhone 16'] for d in devices if d['name'] == name), devices[0])
print('UI simulator: ' + device['name'] + ' / iOS ' + sdk, file=sys.stderr)
print(device['udid'])
PY
)
python3 scripts/run-bounded.py --timeout 90 -- xcrun simctl boot "$DEVICE_ID" || true
python3 scripts/run-bounded.py --timeout 180 -- xcrun simctl bootstatus "$DEVICE_ID" -b
status=0
UI_SCOPE=()
if [ "${1:-}" = "labyrinth" ] || [ "${1:-}" = "indoor" ]; then
  # Focused changed paths; default invocations still run the complete suite.
  UI_SCOPE=(
    -only-testing:HunterRunUITests/HomeLayoutTests/testHomeFitsScreen
    -only-testing:HunterRunUITests/HomeLayoutTests/testEquipmentArtworkDetailsAndHistory
    -only-testing:HunterRunUITests/HomeLayoutTests/testStoryCursorChoicesAndLockedChapters
    -only-testing:HunterRunUITests/LabyrinthLayoutTests
  )
  if [ "${1:-}" = "indoor" ]; then
    UI_SCOPE+=(
      -only-testing:HunterRunUITests/IndoorLayoutTests
      -only-testing:HunterRunUITests/HomeLayoutTests/testGoalSelectionAndCentralNavigation
      -only-testing:HunterRunUITests/HomeLayoutTests/testProductionEntryHasNoSimulationButtons
    )
  fi
fi
if [ "${1:-}" = "stationary" ]; then
  UI_SCOPE=(
    -only-testing:HunterRunUITests/IndoorLayoutTests
    -only-testing:HunterRunUITests/HomeLayoutTests/testGoalSelectionAndCentralNavigation
    -only-testing:HunterRunUITests/HomeLayoutTests/testProductionEntryHasNoSimulationButtons
  )
fi
if [ "${1:-}" = "expedition" ]; then
  UI_SCOPE=(
    -only-testing:HunterRunUITests/ExpeditionLayoutTests
    -only-testing:HunterRunUITests/HomeLayoutTests/testHomeFitsScreen
    -only-testing:HunterRunUITests/HomeLayoutTests/testGoalSelectionAndCentralNavigation
    -only-testing:HunterRunUITests/HomeLayoutTests/testProductionEntryHasNoSimulationButtons
    -only-testing:HunterRunUITests/IndoorLayoutTests
  )
fi
if [ "${1:-}" = "expedition-final" ]; then
  UI_SCOPE=(
    -only-testing:HunterRunUITests/ExpeditionLayoutTests/testPostClearMutationCanBePreparedWithoutLockingOrdinaryMode
    -only-testing:HunterRunUITests/ExpeditionLayoutTests/testWeeklyRewardAndReturnConversation
    -only-testing:HunterRunUITests/HomeLayoutTests/testHomeFitsScreen
    -only-testing:HunterRunUITests/HomeLayoutTests/testOutdoorActivityShowsCurrentAndAveragePace
  )
fi
if [ "${1:-}" = "facilities" ]; then
  UI_SCOPE=(-only-testing:HunterRunUITests/FacilityLayoutTests)
fi
if [ "${1:-}" = "defense" ]; then
  UI_SCOPE=(-only-testing:HunterRunUITests/IndoorLayoutTests -only-testing:HunterRunUITests/HomeLayoutTests/testHomeFitsScreen)
fi
if [ "${1:-}" = "progress-guidance" ]; then
  UI_SCOPE=(-only-testing:HunterRunUITests/ProgressGuidanceTests -only-testing:HunterRunUITests/HomeLayoutTests/testHomeFitsScreen)
fi
if [ "${1:-}" = "combat" ]; then
  UI_SCOPE=(
    -only-testing:HunterRunUITests/CombatReleaseUITests
    -only-testing:HunterRunUITests/ProgressGuidanceTests
    -only-testing:HunterRunUITests/HomeLayoutTests/testHomeFitsScreen
    -only-testing:HunterRunUITests/HomeLayoutTests/testProductionEntryHasNoSimulationButtons
  )
fi
if [ "${1:-}" = "transitions" ]; then
  UI_SCOPE=(
    -only-testing:HunterRunUITests/TransitionReleaseTests
    -only-testing:HunterRunUITests/HomeLayoutTests/testHomeFitsScreen
    -only-testing:HunterRunUITests/HomeLayoutTests/testProductionEntryHasNoSimulationButtons
    -only-testing:HunterRunUITests/CombatReleaseUITests
  )
fi
if [ "${1:-}" = "album" ]; then
  UI_SCOPE=(-only-testing:HunterRunUITests/DefenseAlbumTests -only-testing:HunterRunUITests/HomeLayoutTests/testHomeFitsScreen)
fi
if [ "${1:-}" = "operator-life" ]; then
  UI_SCOPE=(
    -only-testing:HunterRunUITests/OperatorLifeUITests
    -only-testing:HunterRunUITests/HomeLayoutTests/testHomeFitsScreen
    -only-testing:HunterRunUITests/HomeLayoutTests/testFirstRegistrationAcceptsCustomNamesAndOpensStory
    -only-testing:HunterRunUITests/HomeLayoutTests/testLargeTextKeepsStoryAndSettingsReachable
    -only-testing:HunterRunUITests/HomeLayoutTests/testProductionEntryHasNoSimulationButtons
  )
fi
if [ "${1:-}" = "operator-chat" ]; then
  UI_SCOPE=(
    -only-testing:HunterRunUITests/OperatorChatUITests
    -only-testing:HunterRunUITests/LabyrinthLayoutTests/testLargeTextConversationCanReadAndChoose
    -only-testing:HunterRunUITests/LabyrinthLayoutTests/testOperatorReplyAndMemoriesStayReachable
  )
fi
xcodebuild -project HunterRun.xcodeproj -scheme HunterRun -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" -derivedDataPath build/layout \
  -resultBundlePath build/Layout.xcresult -parallel-testing-enabled NO \
  "${UI_SCOPE[@]}" \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tee build/layout-log.txt || status=$?
mkdir -p build/ui-review
xcrun xcresulttool export attachments --path build/Layout.xcresult --output-path build/ui-review || true
if [ "${1:-}" = "operator-life" ]; then
  xcrun simctl spawn "$DEVICE_ID" log show --last 30m --style compact --info --predicate 'subsystem == "com.hunterrun.demo" AND category == "OperatorLife"' > build/life-metrics-large.txt || true
fi
# Keep a directly downloadable screenshot even when the assertion fails.
xcrun simctl terminate "$DEVICE_ID" com.hunterrun.demo || true
xcrun simctl launch "$DEVICE_ID" com.hunterrun.demo --ui-testing-skip-title --ui-testing-skip-welcome --ui-testing-silent-audio || true
sleep 3
xcrun simctl io "$DEVICE_ID" screenshot build/Home-layout.png || true
if [ "$status" -eq 0 ]; then
if [ "${1:-}" != "stationary" ] && [ "${1:-}" != "expedition-final" ] && [ "${1:-}" != "facilities" ] && [ "${1:-}" != "operator-life" ] && [ "${1:-}" != "operator-chat" ] && [ "${1:-}" != "progress-guidance" ] && [ "${1:-}" != "combat" ] && [ "${1:-}" != "album" ] && [ "${1:-}" != "transitions" ]; then
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
fi
SMALL_DEVICE_ID=$(python3 - <<'PY'
import json, os, subprocess
sdk = os.environ['HUNTER_SIMULATOR_SDK']
runtimes = [r for r in json.load(open('build/runtimes.json'))['runtimes'] if r['isAvailable'] and r['name'].startswith('iOS')
            and (r['version'] == sdk or r['version'].startswith(sdk + '.'))]
if not runtimes: raise SystemExit('No matching compact iPhone runtime')
with open('build/simulators.json') as source:
    devices = [d for d in json.load(source)['devices'].get(runtimes[0]['identifier'], []) if d['isAvailable'] and 'iPhone' in d['name']]
preferred = ['iPhone SE (3rd generation)', 'iPhone 16e', 'iPhone 16']
device = next((d for name in preferred for d in devices if d['name'] == name), None)
if device:
    print(device['udid'])
else:
    types = json.load(open('build/device-types.json'))['devicetypes']
    created = None
    for name in preferred:
        kind = next((t for t in types if t['name'] == name), None)
        if kind and runtimes:
            attempt = subprocess.run(['xcrun', 'simctl', 'create', 'HunterRun Compact QA', kind['identifier'], runtimes[0]['identifier']], capture_output=True, text=True, timeout=60)
            if attempt.returncode == 0:
                created = attempt.stdout.strip()
                print(created)
                break
    if not created: raise SystemExit('No compatible compact iPhone simulator could be created')
PY
)
if [ -n "$SMALL_DEVICE_ID" ] && [ "$SMALL_DEVICE_ID" != "$DEVICE_ID" ]; then
  xcrun simctl shutdown "$DEVICE_ID" || true
  python3 scripts/run-bounded.py --timeout 90 -- xcrun simctl boot "$SMALL_DEVICE_ID" || true
  python3 scripts/run-bounded.py --timeout 180 -- xcrun simctl bootstatus "$SMALL_DEVICE_ID" -b
  if [ "${1:-}" = "operator-life" ] || [ "${1:-}" = "operator-chat" ]; then
    # Let the newly-created compact device finish its first app lifecycle before
    # XCTest requests RunningBoard background assertions. This preflight uses
    # an isolated simulator-only save, never a registration bypass in Release.
    python3 scripts/run-bounded.py --timeout 90 -- xcrun simctl install "$SMALL_DEVICE_ID" build/layout/Build/Products/Debug-iphonesimulator/HunterRun.app
    # bootstatus can finish before the new device's first SpringBoard launch.
    # Preserve a bounded wait for that infrastructure startup; do not retry or
    # suppress XCTest assertions and do not change app animation durations.
    python3 scripts/run-bounded.py --timeout 180 -- xcrun simctl launch "$SMALL_DEVICE_ID" com.hunterrun.demo --ui-testing-skip-title --ui-testing-skip-welcome --ui-testing-silent-audio --ui-testing-save life-layout-preflight
    sleep 5
    python3 scripts/run-bounded.py --timeout 60 -- xcrun simctl io "$SMALL_DEVICE_ID" screenshot build/Small-warmup.png
    python3 scripts/run-bounded.py --timeout 60 -- xcrun simctl terminate "$SMALL_DEVICE_ID" com.hunterrun.demo
  fi
  SMALL_SCOPE=(
    -only-testing:HunterRunUITests/HomeLayoutTests/testHomeFitsScreen
    -only-testing:HunterRunUITests/HomeLayoutTests/testFirstRegistrationAcceptsCustomNamesAndOpensStory
    -only-testing:HunterRunUITests/HomeLayoutTests/testLargeTextKeepsStoryAndSettingsReachable
    -only-testing:HunterRunUITests/LabyrinthLayoutTests/testLargeTextConversationCanReadAndChoose
    -only-testing:HunterRunUITests/LabyrinthLayoutTests/testOperatorReplyAndMemoriesStayReachable
    -only-testing:HunterRunUITests/IndoorLayoutTests/testIndoorPreparationDoesNotOfferGPSDistanceOrAcceleration
  )
  if [ "${1:-}" = "stationary" ]; then SMALL_SCOPE=(-only-testing:HunterRunUITests/IndoorLayoutTests); fi
  if [ "${1:-}" = "expedition" ]; then SMALL_SCOPE=(-only-testing:HunterRunUITests/ExpeditionLayoutTests -only-testing:HunterRunUITests/HomeLayoutTests/testHomeFitsScreen); fi
  if [ "${1:-}" = "expedition-final" ]; then SMALL_SCOPE=("${UI_SCOPE[@]}"); fi
  if [ "${1:-}" = "facilities" ]; then SMALL_SCOPE=("${UI_SCOPE[@]}"); fi
  if [ "${1:-}" = "defense" ] || [ "${1:-}" = "progress-guidance" ] || [ "${1:-}" = "combat" ]; then SMALL_SCOPE=("${UI_SCOPE[@]}"); fi
  if [ "${1:-}" = "transitions" ]; then SMALL_SCOPE=("${UI_SCOPE[@]}"); fi
  if [ "${1:-}" = "album" ]; then SMALL_SCOPE=("${UI_SCOPE[@]}"); fi
  if [ "${1:-}" = "operator-life" ] || [ "${1:-}" = "operator-chat" ]; then SMALL_SCOPE=("${UI_SCOPE[@]}"); fi
  xcodebuild -project HunterRun.xcodeproj -scheme HunterRun -configuration Debug \
    -destination "platform=iOS Simulator,id=$SMALL_DEVICE_ID" -derivedDataPath build/layout \
    -resultBundlePath build/Small-layout.xcresult -parallel-testing-enabled NO \
    "${SMALL_SCOPE[@]}" \
    CODE_SIGNING_ALLOWED=NO test-without-building 2>&1 | tee build/small-layout-log.txt || status=$?
  xcrun simctl launch "$SMALL_DEVICE_ID" com.hunterrun.demo --ui-testing-skip-title --ui-testing-skip-welcome --ui-testing-silent-audio || true
  xcrun simctl io "$SMALL_DEVICE_ID" screenshot build/Small-layout.png || true
  mkdir -p build/ui-review-small
  xcrun xcresulttool export attachments --path build/Small-layout.xcresult --output-path build/ui-review-small || true
  if [ "${1:-}" = "operator-life" ]; then
    xcrun simctl spawn "$SMALL_DEVICE_ID" log show --last 30m --style compact --info --predicate 'subsystem == "com.hunterrun.demo" AND category == "OperatorLife"' > build/life-metrics-small.txt || true
  fi
fi
fi
exit "$status"
