#!/bin/sh

set -eu

TARGET_BIN_DIR="/usr/local/bin"
TARGET_AGENT_DIR="/Library/LaunchAgents"
TARGET_PREFS_DIR="/Library/Preferences/ALCPlugFix"
TARGET_LABEL="com.black-dragon74.ALCPlugFix"
TARGET_AGENT_PLIST="${TARGET_AGENT_DIR}/${TARGET_LABEL}.plist"
GUI_UID="$(stat -f %u /dev/console)"

launchctl bootout "gui/${GUI_UID}" "$TARGET_AGENT_PLIST" >/dev/null 2>&1 || true
launchctl disable "gui/${GUI_UID}/${TARGET_LABEL}" >/dev/null 2>&1 || true

rm -f "${TARGET_AGENT_PLIST}"
rm -f "${TARGET_BIN_DIR}/ALCPlugFix"
rm -f "${TARGET_BIN_DIR}/alc-verb"
rm -rf "${TARGET_PREFS_DIR}"

echo "Removed offline Y9000X ALCPlugFix."
