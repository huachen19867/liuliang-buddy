#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../app"
mkdir -p build
exec > >(tee build/ios-verification.log) 2>&1
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'iOS verification requires macOS with Xcode.' >&2
  exit 1
fi
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

SIMULATOR_ID=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for runtime,items in d["devices"].items() if "iOS" in runtime for x in items if "iPhone" in x["name"]))')
trap 'xcrun simctl shutdown "$SIMULATOR_ID" >/dev/null 2>&1 || true' EXIT
xcrun simctl boot "$SIMULATOR_ID"
xcrun simctl bootstatus "$SIMULATOR_ID" -b
xcrun simctl install "$SIMULATOR_ID" "$APP"
xcrun simctl launch "$SIMULATOR_ID" cn.liuliang.liuliangApp
sleep 15
xcrun simctl io "$SIMULATOR_ID" screenshot build/ios-onboarding.png
xcrun simctl terminate "$SIMULATOR_ID" cn.liuliang.liuliangApp
flutter drive --driver=test_driver/ios_smoke_driver.dart --target=integration_test/ios_smoke_test.dart -d "$SIMULATOR_ID"
[[ -s build/ios-smoke/ios-selection.png && -s build/ios-smoke/ios-dashboard.png ]]
echo 'iOS onboarding, dashboard, widget instructions and settings smoke passed.'
