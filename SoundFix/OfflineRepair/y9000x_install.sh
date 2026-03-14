#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_BIN_DIR="/usr/local/bin"
TARGET_AGENT_DIR="/Library/LaunchAgents"
TARGET_PREFS_DIR="/Library/Preferences/ALCPlugFix"
TARGET_LABEL="com.black-dragon74.ALCPlugFix"
TARGET_AGENT_PLIST="${TARGET_AGENT_DIR}/${TARGET_LABEL}.plist"
TARGET_CONFIG_PLIST="${TARGET_PREFS_DIR}/Config.plist"
GUI_UID="$(stat -f %u /dev/console)"

mkdir -p "$TARGET_BIN_DIR"
mkdir -p "$TARGET_PREFS_DIR"

cp "${SCRIPT_DIR}/alc-verb" "${TARGET_BIN_DIR}/alc-verb"
chmod 755 "${TARGET_BIN_DIR}/alc-verb"
chown root:wheel "${TARGET_BIN_DIR}/alc-verb"

cp "${SCRIPT_DIR}/ALCPlugFix" "${TARGET_BIN_DIR}/ALCPlugFix"
chmod 755 "${TARGET_BIN_DIR}/ALCPlugFix"
chown root:wheel "${TARGET_BIN_DIR}/ALCPlugFix"

cat > "$TARGET_AGENT_PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>KeepAlive</key>
    <true/>
    <key>Label</key>
    <string>com.black-dragon74.ALCPlugFix</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/ALCPlugFix</string>
        <string>/Library/Preferences/ALCPlugFix/Config.plist</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ServiceIPC</key>
    <false/>
</dict>
</plist>
PLIST

chmod 644 "$TARGET_AGENT_PLIST"
chown root:wheel "$TARGET_AGENT_PLIST"

cat > "$TARGET_CONFIG_PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <array>
    <dict>
      <key>Comment</key>
      <string>0x20 0x500 0x24</string>
      <key>Enabled</key>
      <true />
      <key>Node ID</key>
      <string>0x20</string>
      <key>On Boot</key>
      <true />
      <key>On Connect</key>
      <false />
      <key>On Disconnect</key>
      <true />
      <key>On Mute</key>
      <false />
      <key>On Sleep</key>
      <false />
      <key>On Unmute</key>
      <true />
      <key>On Wake</key>
      <true />
      <key>Param</key>
      <string>0x24</string>
      <key>Verb</key>
      <string>0x500</string>
    </dict>
    <dict>
      <key>Comment</key>
      <string>0x20 0x400 0x41</string>
      <key>Enabled</key>
      <true />
      <key>Node ID</key>
      <string>0x20</string>
      <key>On Boot</key>
      <true />
      <key>On Connect</key>
      <false />
      <key>On Disconnect</key>
      <true />
      <key>On Mute</key>
      <false />
      <key>On Sleep</key>
      <false />
      <key>On Unmute</key>
      <true />
      <key>On Wake</key>
      <true />
      <key>Param</key>
      <string>0x41</string>
      <key>Verb</key>
      <string>0x400</string>
    </dict>
    <dict>
      <key>Comment</key>
      <string>0x20 0x500 0x26</string>
      <key>Enabled</key>
      <true />
      <key>Node ID</key>
      <string>0x20</string>
      <key>On Boot</key>
      <true />
      <key>On Connect</key>
      <false />
      <key>On Disconnect</key>
      <true />
      <key>On Mute</key>
      <false />
      <key>On Sleep</key>
      <false />
      <key>On Unmute</key>
      <true />
      <key>On Wake</key>
      <true />
      <key>Param</key>
      <string>0x26</string>
      <key>Verb</key>
      <string>0x500</string>
    </dict>
    <dict>
      <key>Comment</key>
      <string>0x20 0x400 0x2</string>
      <key>Enabled</key>
      <true />
      <key>Node ID</key>
      <string>0x20</string>
      <key>On Boot</key>
      <true />
      <key>On Connect</key>
      <false />
      <key>On Disconnect</key>
      <true />
      <key>On Mute</key>
      <false />
      <key>On Sleep</key>
      <false />
      <key>On Unmute</key>
      <true />
      <key>On Wake</key>
      <true />
      <key>Param</key>
      <string>0x2</string>
      <key>Verb</key>
      <string>0x400</string>
    </dict>
    <dict>
      <key>Comment</key>
      <string>0x20 0x400 0x0</string>
      <key>Enabled</key>
      <true />
      <key>Node ID</key>
      <string>0x20</string>
      <key>On Boot</key>
      <true />
      <key>On Connect</key>
      <false />
      <key>On Disconnect</key>
      <true />
      <key>On Mute</key>
      <false />
      <key>On Sleep</key>
      <false />
      <key>On Unmute</key>
      <true />
      <key>On Wake</key>
      <true />
      <key>Param</key>
      <string>0x0</string>
      <key>Verb</key>
      <string>0x400</string>
    </dict>
    <dict>
      <key>Comment</key>
      <string>0x20 0x400 0x0</string>
      <key>Enabled</key>
      <true />
      <key>Node ID</key>
      <string>0x20</string>
      <key>On Boot</key>
      <true />
      <key>On Connect</key>
      <false />
      <key>On Disconnect</key>
      <true />
      <key>On Mute</key>
      <false />
      <key>On Sleep</key>
      <false />
      <key>On Unmute</key>
      <true />
      <key>On Wake</key>
      <true />
      <key>Param</key>
      <string>0x0</string>
      <key>Verb</key>
      <string>0x400</string>
    </dict>
    <dict>
      <key>Comment</key>
      <string>0x20 0x4b0 0x20</string>
      <key>Enabled</key>
      <true />
      <key>Node ID</key>
      <string>0x20</string>
      <key>On Boot</key>
      <true />
      <key>On Connect</key>
      <false />
      <key>On Disconnect</key>
      <true />
      <key>On Mute</key>
      <false />
      <key>On Sleep</key>
      <false />
      <key>On Unmute</key>
      <true />
      <key>On Wake</key>
      <true />
      <key>Param</key>
      <string>0x20</string>
      <key>Verb</key>
      <string>0x4b0</string>
    </dict>
    <dict>
      <key>Comment</key>
      <string>0x20 0x500 0x24</string>
      <key>Enabled</key>
      <true />
      <key>Node ID</key>
      <string>0x20</string>
      <key>On Boot</key>
      <true />
      <key>On Connect</key>
      <false />
      <key>On Disconnect</key>
      <true />
      <key>On Mute</key>
      <false />
      <key>On Sleep</key>
      <false />
      <key>On Unmute</key>
      <true />
      <key>On Wake</key>
      <true />
      <key>Param</key>
      <string>0x24</string>
      <key>Verb</key>
      <string>0x500</string>
    </dict>
    <dict>
      <key>Comment</key>
      <string>0x20 0x400 0x42</string>
      <key>Enabled</key>
      <true />
      <key>Node ID</key>
      <string>0x20</string>
      <key>On Boot</key>
      <true />
      <key>On Connect</key>
      <false />
      <key>On Disconnect</key>
      <true />
      <key>On Mute</key>
      <false />
      <key>On Sleep</key>
      <false />
      <key>On Unmute</key>
      <true />
      <key>On Wake</key>
      <true />
      <key>Param</key>
      <string>0x42</string>
      <key>Verb</key>
      <string>0x400</string>
    </dict>
    <dict>
      <key>Comment</key>
      <string>0x20 0x500 0x26</string>
      <key>Enabled</key>
      <true />
      <key>Node ID</key>
      <string>0x20</string>
      <key>On Boot</key>
      <true />
      <key>On Connect</key>
      <false />
      <key>On Disconnect</key>
      <true />
      <key>On Mute</key>
      <false />
      <key>On Sleep</key>
      <false />
      <key>On Unmute</key>
      <true />
      <key>On Wake</key>
      <true />
      <key>Param</key>
      <string>0x26</string>
      <key>Verb</key>
      <string>0x500</string>
    </dict>
    <dict>
      <key>Comment</key>
      <string>0x20 0x400 0x2</string>
      <key>Enabled</key>
      <true />
      <key>Node ID</key>
      <string>0x20</string>
      <key>On Boot</key>
      <true />
      <key>On Connect</key>
      <false />
      <key>On Disconnect</key>
      <true />
      <key>On Mute</key>
      <false />
      <key>On Sleep</key>
      <false />
      <key>On Unmute</key>
      <true />
      <key>On Wake</key>
      <true />
      <key>Param</key>
      <string>0x2</string>
      <key>Verb</key>
      <string>0x400</string>
    </dict>
    <dict>
      <key>Comment</key>
      <string>0x20 0x400 0x0</string>
      <key>Enabled</key>
      <true />
      <key>Node ID</key>
      <string>0x20</string>
      <key>On Boot</key>
      <true />
      <key>On Connect</key>
      <false />
      <key>On Disconnect</key>
      <true />
      <key>On Mute</key>
      <false />
      <key>On Sleep</key>
      <false />
      <key>On Unmute</key>
      <true />
      <key>On Wake</key>
      <true />
      <key>Param</key>
      <string>0x0</string>
      <key>Verb</key>
      <string>0x400</string>
    </dict>
    <dict>
      <key>Comment</key>
      <string>0x20 0x400 0x0</string>
      <key>Enabled</key>
      <true />
      <key>Node ID</key>
      <string>0x20</string>
      <key>On Boot</key>
      <true />
      <key>On Connect</key>
      <false />
      <key>On Disconnect</key>
      <true />
      <key>On Mute</key>
      <false />
      <key>On Sleep</key>
      <false />
      <key>On Unmute</key>
      <true />
      <key>On Wake</key>
      <true />
      <key>Param</key>
      <string>0x0</string>
      <key>Verb</key>
      <string>0x400</string>
    </dict>
    <dict>
      <key>Comment</key>
      <string>0x20 0x4b0 0x20</string>
      <key>Enabled</key>
      <true />
      <key>Node ID</key>
      <string>0x20</string>
      <key>On Boot</key>
      <true />
      <key>On Connect</key>
      <false />
      <key>On Disconnect</key>
      <true />
      <key>On Mute</key>
      <false />
      <key>On Sleep</key>
      <false />
      <key>On Unmute</key>
      <true />
      <key>On Wake</key>
      <true />
      <key>Param</key>
      <string>0x20</string>
      <key>Verb</key>
      <string>0x4b0</string>
    </dict>
  </array>
</plist>
PLIST

chmod 644 "$TARGET_CONFIG_PLIST"
chown root:wheel "$TARGET_CONFIG_PLIST"

launchctl bootout "gui/${GUI_UID}" "$TARGET_AGENT_PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/${GUI_UID}" "$TARGET_AGENT_PLIST"
launchctl enable "gui/${GUI_UID}/${TARGET_LABEL}" >/dev/null 2>&1 || true
launchctl kickstart -k "gui/${GUI_UID}/${TARGET_LABEL}" >/dev/null 2>&1 || true

echo "Installed offline Y9000X ALCPlugFix."
