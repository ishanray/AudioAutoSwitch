#!/bin/sh
# Builds, signs with a Developer ID, notarizes, and zips the app for a GitHub release.
# Notarization uses the Apple account signed in to Xcode (Settings → Accounts), so no password is needed.
set -eu
cd "$(dirname "$0")/.."

: "${TEAM_ID:?Set TEAM_ID to your Apple developer team ID}"
export CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application}"

./scripts/build-app.sh

app="Audio Auto Switch.app"
archive="build/AudioAutoSwitch.xcarchive"
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
build=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" Resources/Info.plist)

# xcodebuild only notarizes Xcode archives, so wrap the signed app in one.
rm -rf "$archive" build/export build/notarized
mkdir -p "$archive/Products/Applications"
cp -R "build/$app" "$archive/Products/Applications/"
cat > "$archive/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>ApplicationProperties</key>
  <dict>
    <key>ApplicationPath</key><string>Applications/$app</string>
    <key>CFBundleIdentifier</key><string>io.github.ishanray.AudioAutoSwitch</string>
    <key>CFBundleShortVersionString</key><string>$version</string>
    <key>CFBundleVersion</key><string>$build</string>
    <key>Team</key><string>$TEAM_ID</string>
  </dict>
  <key>ArchiveVersion</key><integer>2</integer>
  <key>CreationDate</key><date>$(date -u +%Y-%m-%dT%H:%M:%SZ)</date>
  <key>Name</key><string>AudioAutoSwitch</string>
</dict>
</plist>
PLIST
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates

echo "Waiting for Apple to notarize..."
tries=0
until xcodebuild -exportNotarizedApp -archivePath "$archive" -exportPath build/notarized > build/notarize.log 2>&1; do
  tries=$((tries + 1))
  if [ "$tries" -ge 90 ]; then
    echo "Notarization didn't finish within 30 minutes. Last output:" >&2
    tail -20 build/notarize.log >&2
    exit 1
  fi
  sleep 20
done

spctl --assess --type execute --verbose "build/notarized/$app"
zip="build/AudioAutoSwitch.zip"
rm -f "$zip"
ditto -c -k --keepParent "build/notarized/$app" "$zip"
echo "Release ready: $zip"
