#!/bin/sh
# Usage: build.sh        → build/Salat.app (VERSION / BUILD_NUMBER env override the version)
#        build.sh test   → run the Swift tests
cd "$(dirname "$0")" || exit 1
mkdir -p build
xcodegen generate --quiet || exit 1
if [ "$1" = "test" ]; then
  xcodebuild -project Salat.xcodeproj -scheme Salat -derivedDataPath build/dd -destination 'platform=macOS' test > build/test.log 2>&1
  rc=$?
  grep -E "error:|: error|failed \(|Executed|\*\* TEST" build/test.log | grep -v "\[Connection\]" | sort -u | tail -40
  exit $rc
fi
# VERSION=1.2.3 build.sh → that version in Info.plist (CI sets it from the tag).
xcodebuild -project Salat.xcodeproj -scheme Salat -configuration Release -derivedDataPath build/dd build \
  ${VERSION:+MARKETING_VERSION=$VERSION} ${BUILD_NUMBER:+CURRENT_PROJECT_VERSION=$BUILD_NUMBER} > build/build.log 2>&1
rc=$?
grep -E "error:|\*\* BUILD" build/build.log | tail -20
[ $rc -eq 0 ] || exit $rc
rm -rf build/Salat.app && cp -R build/dd/Build/Products/Release/Salat.app build/Salat.app
echo "→ $(pwd)/build/Salat.app"
