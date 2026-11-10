#!/bin/bash
# Builds build/Flipane.app. Pass "install" to also copy it to /Applications and relaunch.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/Flipane.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Flipane "$APP/Contents/MacOS/Flipane"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Version comes from the latest vX.Y.Z tag (falling back to Info.plist); the build
# number is the commit count, so every build from a newer commit sorts higher.
PLIST="$APP/Contents/Info.plist"
if TAG=$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null); then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${TAG#v}" "$PLIST"
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(git rev-list --count HEAD 2>/dev/null || echo 1)" "$PLIST"

# A stable signing identity keeps the Accessibility grant valid across rebuilds;
# ad-hoc signatures change every build and force you to re-grant.
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Apple Development/ {print $2; exit}')}"
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Built $APP (signed with ${IDENTITY:-ad-hoc identity})"

if [[ "${1:-}" == "install" ]]; then
    pkill -x Flipane || true
    # Launch Services refuses to open the app while the old copy is still shutting down.
    for _ in {1..50}; do pgrep -x Flipane >/dev/null || break; sleep 0.1; done
    rm -rf /Applications/Flipane.app
    cp -R "$APP" /Applications/Flipane.app
    open /Applications/Flipane.app
    echo "Installed to /Applications/Flipane.app and launched"
fi
