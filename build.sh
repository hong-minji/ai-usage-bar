#!/bin/bash
# Builds AIUsageBar.app. Requires only Xcode Command Line Tools.
#   ./build.sh         build the app (runs tests first)
#   ./build.sh test    run tests only
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$PWD"
BUILD="$ROOT/build"
APP="$BUILD/AIUsageBar.app"
BUNDLE_ID="com.local.ai-usage-bar"

# Pure-logic files only -- these must stay free of AppKit so they can be linked
# into the test binary.
TESTABLE=(Sources/Model.swift Sources/Parsing.swift Sources/BarFormatter.swift Sources/FetchError.swift Sources/GeminiChromeBridge.swift)

run_tests() {
    echo "==> 테스트"
    mkdir -p "$BUILD"
    swiftc -O "${TESTABLE[@]}" Tests/main.swift -o "$BUILD/tests"
    "$BUILD/tests"
}

build_app() {
    echo "==> 빌드"
    rm -rf "$APP"
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

    swiftc -O Sources/*.swift -o "$APP/Contents/MacOS/AIUsageBar"

    cp -R ChromeExtension "$APP/Contents/Resources/ChromeExtension"
    cp gemini-native-host "$APP/Contents/Resources/gemini-native-host"
    chmod 755 "$APP/Contents/Resources/gemini-native-host"

    cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>AIUsageBar</string>
    <key>CFBundleDisplayName</key><string>AI 사용량</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>AIUsageBar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.1</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <!-- Menu bar only: no Dock icon. -->
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

    # Ad-hoc signature: enough for macOS to treat the bundle as a stable app.
    # Unsigned-but-adhoc still re-prompts for keychain access after a rebuild.
    codesign --force --sign - --identifier "$BUNDLE_ID" "$APP" >/dev/null 2>&1 \
        || echo "    (코드서명 생략됨)"

    echo "==> 완료: $APP"
}

case "${1:-all}" in
    test) run_tests ;;
    app)  build_app ;;
    *)    run_tests; build_app ;;
esac
