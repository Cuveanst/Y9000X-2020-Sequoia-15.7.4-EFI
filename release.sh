#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_PATH="${PROJECT_ROOT}/SoundFix.xcodeproj"
SCHEME="SoundFix"
CONFIGURATION="Release"
APP_NAME="SoundFix"
DERIVED_DATA_PATH="${PROJECT_ROOT}/build/DerivedData"
ARCHIVE_PATH="${PROJECT_ROOT}/build/${APP_NAME}.xcarchive"
EXPORT_DIR="${PROJECT_ROOT}/build/export"
DMG_STAGING_DIR="${PROJECT_ROOT}/build/dmg"
DIST_DIR="${PROJECT_ROOT}/dist"

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "error: xcodebuild not found."
    exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
    echo "error: hdiutil not found."
    exit 1
fi

rm -rf "$DERIVED_DATA_PATH" "$ARCHIVE_PATH" "$EXPORT_DIR" "$DMG_STAGING_DIR"
mkdir -p "$EXPORT_DIR" "$DMG_STAGING_DIR" "$DIST_DIR"

echo "==> Archiving ${APP_NAME} (${CONFIGURATION})"
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -archivePath "$ARCHIVE_PATH" \
    archive

APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo "error: archived app not found at ${APP_PATH}"
    exit 1
fi

echo "==> Preparing app bundle"
ditto "$APP_PATH" "${EXPORT_DIR}/${APP_NAME}.app"

APP_PLIST="${EXPORT_DIR}/${APP_NAME}.app/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PLIST" 2>/dev/null || echo "0.0.0")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PLIST" 2>/dev/null || echo "0")"
DMG_NAME="${APP_NAME}-${VERSION}-${BUILD_NUMBER}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

echo "==> Creating DMG staging folder"
ditto "${EXPORT_DIR}/${APP_NAME}.app" "${DMG_STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${DMG_STAGING_DIR}/Applications"

rm -f "$DMG_PATH"

echo "==> Building DMG"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo
echo "Release app: ${EXPORT_DIR}/${APP_NAME}.app"
echo "DMG image:   ${DMG_PATH}"
echo
echo "Tip: for public distribution, use a Developer ID certificate and notarize the DMG before publishing."
