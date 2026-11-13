#!/bin/bash
# Builds AIUsageBar.app. Requires only Xcode Command Line Tools.
#   ./build.sh         build the app (runs tests first)
#   ./build.sh test    run tests only
#   ./build.sh universal  test and build for Apple Silicon + Intel
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$PWD"
BUILD="$ROOT/build"
APP="$BUILD/AIUsageBar.app"
BUNDLE_ID="com.local.ai-usage-bar"
VERSION="1.2.0"
BUILD_NUMBER="4"

if [[ "$(uname -s)" != Darwin ]]; then
    echo "macOS에서 실행하세요 / macOS is required." >&2
    exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "개발 도구가 필요합니다: xcode-select --install" >&2
    exit 1
fi
ARCH="$(uname -m)"
TARGET="$ARCH-apple-macosx13.0"

# Pure-logic files only -- these must stay free of AppKit so they can be linked
# into the test binary.
TESTABLE=(Sources/Model.swift Sources/Parsing.swift Sources/BarFormatter.swift Sources/FetchError.swift Sources/GeminiChromeBridge.swift Sources/ChromeInstallation.swift Sources/BrowserUsageBridge.swift)

run_tests() {
    echo "==> 테스트"
    mkdir -p "$BUILD"
    swiftc -O -target "$TARGET" "${TESTABLE[@]}" Tests/main.swift -o "$BUILD/tests"
    "$BUILD/tests"
}

build_app() {
    echo "==> 빌드"
    mkdir -p "$BUILD"
    STAGING="$(mktemp -d "$BUILD/.app-build.XXXXXX")"
    trap 'rm -rf "$STAGING"' EXIT
    local OUTPUT="$STAGING/AIUsageBar.app"
    mkdir -p "$OUTPUT/Contents/MacOS" "$OUTPUT/Contents/Resources"

    if [[ "${1:-native}" == universal ]]; then
        for arch in arm64 x86_64; do
            swiftc -O -target "$arch-apple-macosx13.0" Sources/*.swift -o "$STAGING/AIUsageBar-$arch"
        done
        lipo -create "$STAGING/AIUsageBar-arm64" "$STAGING/AIUsageBar-x86_64" -output "$OUTPUT/Contents/MacOS/AIUsageBar"
    else
        swiftc -O -target "$TARGET" Sources/*.swift -o "$OUTPUT/Contents/MacOS/AIUsageBar"
    fi

    # Ship runtime files only; keep fixtures, local captures and test helpers out.
    mkdir -p "$OUTPUT/Contents/Resources/ChromeExtension"
    for file in ChromeExtension/manifest.json ChromeExtension/popup.html ChromeExtension/*.js; do
        cp "$file" "$OUTPUT/Contents/Resources/ChromeExtension/"
    done
    cp gemini-native-host "$OUTPUT/Contents/Resources/gemini-native-host"
    chmod 755 "$OUTPUT/Contents/Resources/gemini-native-host"

    cat > "$OUTPUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>AIUsageBar</string>
    <key>CFBundleDisplayName</key><string>AI 사용량</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>AIUsageBar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <!-- Menu bar only: no Dock icon. -->
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

    # Ad-hoc signature: enough for macOS to treat the bundle as a stable app.
    # Unsigned-but-adhoc still re-prompts for keychain access after a rebuild.
    codesign --force --sign - --identifier "$BUNDLE_ID" "$OUTPUT"
    codesign --verify --strict "$OUTPUT"

    # Keep the previous build intact until compilation and signing succeed.
    rm -rf "$APP"
    mv "$OUTPUT" "$APP"

    echo "==> 완료: $APP"
}

case "${1:-all}" in
    test) run_tests ;;
    app)  build_app ;;
    universal) run_tests; build_app universal ;;
    all) run_tests; build_app ;;
    *) echo "Usage: $0 [all|test|app|universal]" >&2; exit 2 ;;
esac
