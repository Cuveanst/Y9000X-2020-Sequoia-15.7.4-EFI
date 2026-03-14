DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -pro
ject SoundFix.xcodeproj -scheme SoundFix -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEED
ED|BUILD FAILED"