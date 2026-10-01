#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../app"
mkdir -p build
exec > >(tee -a build/ios-verification.log) 2>&1
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'iOS verification requires macOS with Xcode.' >&2
  exit 1
fi
STAGE="${1:-all}"
case "$STAGE" in build|smoke|all) ;; *) echo 'Usage: verify-ios.sh [build|smoke|all]' >&2; exit 2 ;; esac
if [[ "$STAGE" == build || "$STAGE" == all ]]; then
flutter --version
xcodebuild -version
flutter config --no-enable-swift-package-manager
flutter pub get
flutter analyze
flutter test
xcrun swiftc ios/Shared/TrafficSnapshot.swift ios/Tests/TrafficSnapshotTests.swift -o build/traffic-model-tests
build/traffic-model-tests
flutter build ios --simulator --debug --no-codesign
APP=build/ios/iphonesimulator/Runner.app
[[ -d "$APP/PlugIns/TrafficWidget.appex" ]]
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/PlugIns/TrafficWidget.appex/Info.plist"
tar -czf build/ios-simulator.tar.gz -C build/ios/iphonesimulator Runner.app
echo 'Unsigned simulator application and embedded WidgetKit extension verified.'

fi
if [[ "$STAGE" == smoke || "$STAGE" == all ]]; then
SIMULATOR_ID=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for runtime,items in d["devices"].items() if "iOS" in runtime for x in items if "iPhone" in x["name"]))')
mkdir -p build/ios-diagnostics
# WebKit bug 293831: some iOS simulator runtimes omit the ordinary overlay
# location although the same Apple library is present inside their Cryptex.
# Resolve the selected runtime; never weaken product linkage or alter iOS 17.
xcrun simctl list -j > build/ios-diagnostics/simulator-inventory.json
SWIFT_FALLBACK=$(python3 - "$SIMULATOR_ID" <<'PY'
import json, os, sys
with open('build/ios-diagnostics/simulator-inventory.json') as f:
    inventory = json.load(f)
runtime_id = next(key for key, devices in inventory['devices'].items()
                  if any(device['udid'] == sys.argv[1] for device in devices))
runtime = next(item for item in inventory['runtimes'] if item['identifier'] == runtime_id)
root = runtime.get('runtimeRoot') or os.path.join(runtime['bundlePath'], 'Contents/Resources/RuntimeRoot')
ordinary = os.path.join(root, 'usr/lib/swift/libswiftWebKit.dylib')
fallback = os.path.join(root, 'System/Cryptexes/OS/usr/lib/swift')
overlay = os.path.join(fallback, 'libswiftWebKit.dylib')
result = {'runtime': runtime_id, 'runtimeRoot': root, 'ordinaryExists': os.path.isfile(ordinary),
          'cryptexExists': os.path.isfile(overlay), 'fallbackApplied': False}
if not os.path.isfile(ordinary) and os.path.isfile(overlay):
    result['fallbackApplied'] = True
    result['fallbackPath'] = fallback
    print(fallback)
with open('build/ios-diagnostics/webkit-runtime.json', 'w') as f:
    json.dump(result, f, indent=2)
PY
)
cat build/ios-diagnostics/webkit-runtime.json
if [[ -n "$SWIFT_FALLBACK" ]]; then
  export SIMCTL_CHILD_DYLD_FALLBACK_LIBRARY_PATH="$SWIFT_FALLBACK${SIMCTL_CHILD_DYLD_FALLBACK_LIBRARY_PATH:+:$SIMCTL_CHILD_DYLD_FALLBACK_LIBRARY_PATH}"
  echo "Applying official simulator-only WebKit 293831 workaround: $SIMCTL_CHILD_DYLD_FALLBACK_LIBRARY_PATH"
fi
collect_diagnostics() {
  xcrun simctl spawn "$SIMULATOR_ID" log show --last 10m --style compact --predicate 'process == "Runner" OR eventMessage CONTAINS[c] "cn.liuliang.liuliangApp"' > build/ios-diagnostics/simulator.log 2>&1 || true
  /usr/bin/log show --last 10m --style compact --predicate 'process == "Runner" OR eventMessage CONTAINS[c] "cn.liuliang.liuliangApp"' > build/ios-diagnostics/host.log 2>&1 || true
  find "$HOME/Library/Logs/DiagnosticReports" -type f \( -iname '*Runner*' -o -iname '*liuliang*' \) -exec cp {} build/ios-diagnostics/ \; 2>/dev/null || true
  xcrun simctl spawn "$SIMULATOR_ID" launchctl list > build/ios-diagnostics/processes.txt 2>&1 || true
}
finish_smoke() {
  status=$?
  trap - EXIT
  collect_diagnostics
  xcrun simctl terminate "$SIMULATOR_ID" cn.liuliang.liuliangApp >/dev/null 2>&1 || true
  xcrun simctl shutdown "$SIMULATOR_ID" >/dev/null 2>&1 || true
  exit "$status"
}
trap finish_smoke EXIT
xcrun simctl boot "$SIMULATOR_ID"
xcrun simctl bootstatus "$SIMULATOR_ID" -b
APP=build/ios/iphonesimulator/Runner.app
xcrun simctl install "$SIMULATOR_ID" "$APP"
startup_status=0
if xcrun simctl launch --stdout="$PWD/build/ios-diagnostics/startup.stdout" --stderr="$PWD/build/ios-diagnostics/startup.stderr" "$SIMULATOR_ID" cn.liuliang.liuliangApp > build/ios-diagnostics/launch.txt 2>&1; then
  cat build/ios-diagnostics/launch.txt
  startup_pid=$(sed -n 's/.*: \([0-9][0-9]*\)$/\1/p' build/ios-diagnostics/launch.txt | tail -1)
  sleep 15
  if [[ -z "$startup_pid" ]] || ! kill -0 "$startup_pid" 2>/dev/null; then
    echo 'ERROR: standalone simulator application exited before the 15-second startup check.'
    startup_status=1
  fi
else
  cat build/ios-diagnostics/launch.txt
  startup_status=1
fi
xcrun simctl io "$SIMULATOR_ID" screenshot build/ios-onboarding.png || true
# Keep the cold-launch result, but let Flutter drive attach with its debugger and
# report the actual UI failure too. Cleanup must not prevent the integration test.
collect_diagnostics
xcrun simctl terminate "$SIMULATOR_ID" cn.liuliang.liuliangApp >/dev/null 2>&1 || true
# Bound Flutter debugger discovery as well as the UI run; preserve its exit code.
python3 - "$SIMULATOR_ID" <<'PY'
import os, signal, subprocess, sys
command = ['flutter', 'drive', '--driver=test_driver/ios_smoke_driver.dart',
           '--target=integration_test/ios_smoke_test.dart', '-d', sys.argv[1]]
process = subprocess.Popen(command, start_new_session=True)
try:
    sys.exit(process.wait(timeout=300))
except subprocess.TimeoutExpired:
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
    print('ERROR: Flutter simulator smoke exceeded 300 seconds.', flush=True)
    sys.exit(124)
PY
[[ -s build/ios-smoke/ios-selection.png && -s build/ios-smoke/ios-dashboard.png ]]
if [[ "$startup_status" != 0 ]]; then
  echo 'Flutter-driven smoke completed, but standalone cold launch failed; see ios-diagnostics.'
  exit "$startup_status"
fi
echo 'iOS standalone launch, onboarding, dashboard, widget instructions and settings smoke passed.'
fi
