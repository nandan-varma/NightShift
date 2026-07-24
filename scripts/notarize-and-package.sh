#!/bin/bash
# Produces a signed, notarized, stapled DMG. Signing material is supplied by
# the CI environment; this script never reads credentials from the repository.
set -euo pipefail

: "${APPLE_API_KEY_ID:?Missing APPLE_API_KEY_ID}"
: "${APPLE_API_ISSUER_ID:?Missing APPLE_API_ISSUER_ID}"
: "${APPLE_API_KEY_PATH:?Missing APPLE_API_KEY_PATH}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${RUNNER_TEMP:-$ROOT_DIR}/nightshift-release-${GITHUB_RUN_ID:-local}"
VERSION="${VERSION:?Missing VERSION}"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archive"
xcodebuild \
  -project "$ROOT_DIR/NightShift.xcodeproj" \
  -scheme NightShift \
  -configuration Release \
  -archivePath "$BUILD_DIR/NightShift.xcarchive" \
  MARKETING_VERSION="$VERSION" \
  archive

echo "==> Export Developer ID app"
xcodebuild -exportArchive \
  -archivePath "$BUILD_DIR/NightShift.xcarchive" \
  -exportPath "$BUILD_DIR/export" \
  -exportOptionsPlist "$ROOT_DIR/scripts/ExportOptions.plist"

APP_PATH="$BUILD_DIR/export/NightShift.app"
test -d "$APP_PATH"

echo "==> Notarize app"
ditto -c -k --keepParent "$APP_PATH" "$BUILD_DIR/NightShift.zip"
xcrun notarytool submit "$BUILD_DIR/NightShift.zip" \
  --key "$APPLE_API_KEY_PATH" \
  --key-id "$APPLE_API_KEY_ID" \
  --issuer "$APPLE_API_ISSUER_ID" \
  --wait

echo "==> Staple and assess app"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"

echo "==> Package and notarize DMG"
STAGING_DIR="$BUILD_DIR/dmg-staging"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

DMG_PATH="$BUILD_DIR/NightShift-${VERSION}-macos.dmg"
hdiutil create -volname "NightShift" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" \
  --key "$APPLE_API_KEY_PATH" \
  --key-id "$APPLE_API_KEY_ID" \
  --issuer "$APPLE_API_ISSUER_ID" \
  --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

mkdir -p "$ROOT_DIR/dist"
cp "$DMG_PATH" "$ROOT_DIR/dist/"
shasum -a 256 "$ROOT_DIR/dist/$(basename "$DMG_PATH")" \
  > "$ROOT_DIR/dist/$(basename "$DMG_PATH").sha256"
