#!/usr/bin/env bash
set -euo pipefail
SIM_UDID="97620F7B-32A2-4EC4-AB6C-2AD75A1C360E"

xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID"

if ! xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -showdestinations | grep -q "$SIM_UDID"; then
  rm -rf ~/Library/Developer/Xcode/DerivedData/*
  flutter clean
  flutter pub get
fi

flutter run -d "$SIM_UDID"
