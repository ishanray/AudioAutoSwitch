#!/bin/sh
# Builds a universal "Audio Auto Switch.app" into build/.
set -eu
cd "$(dirname "$0")/.."

flags="-c release --arch arm64 --arch x86_64"
swift build $flags
bin="$(swift build $flags --show-bin-path)"

app="build/Audio Auto Switch.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/AudioAutoSwitch" "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/"
cp Resources/AppIcon.icns "$app/Contents/Resources/"
# Ad-hoc signing by default. Set CODESIGN_IDENTITY to a Developer ID to sign for distribution.
identity="${CODESIGN_IDENTITY:--}"
if [ "$identity" = "-" ]; then
  codesign --force --sign - --options runtime "$app"
else
  codesign --force --sign "$identity" --options runtime --timestamp "$app"
fi

echo "Built $app"
