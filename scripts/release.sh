#!/bin/sh
# Builds, signs with a Developer ID, notarizes, and zips the app for a GitHub release.
# Save notarization credentials once with: xcrun notarytool store-credentials <profile>
set -eu
cd "$(dirname "$0")/.."

: "${CODESIGN_IDENTITY:?Set CODESIGN_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool keychain profile}"

./scripts/build-app.sh

app="build/Audio Auto Switch.app"
zip="build/AudioAutoSwitch.zip"
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
xcrun notarytool submit "$zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$app"

# Zip again so the download includes the stapled ticket.
rm "$zip"
ditto -c -k --keepParent "$app" "$zip"
spctl --assess --type execute --verbose "$app"
echo "Release ready: $zip"
