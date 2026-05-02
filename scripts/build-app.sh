#!/usr/bin/env bash
# Build a distributable WhatCable.app bundle.
#
# Modes:
#   - No DEVELOPER_ID set: ad-hoc signed (works locally, Gatekeeper warns elsewhere).
#   - DEVELOPER_ID set:   Developer ID signed + hardened runtime.
#   - Plus NOTARY_PROFILE: also notarises and staples (full distribution).
#
# Configure via .env (see .env.example).
set -euo pipefail

cd "$(dirname "$0")/.."

# Load .env if present
if [[ -f ".env" ]]; then
    # shellcheck disable=SC1091
    set -a; source .env; set +a
fi

APP_NAME="WhatCable"
BUNDLE_ID="com.bitmoor.whatcable"
VERSION="1.0.0"
BUILD_NUMBER="10"
MIN_OS="14.0"

DEVELOPER_ID="${DEVELOPER_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

DIST_DIR="dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ENTITLEMENTS="scripts/${APP_NAME}.entitlements"

echo "==> Running tests"
swift test

echo "==> Cleaning previous build"
rm -rf "${DIST_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

echo "==> Building universal release binary (arm64 + x86_64)"
swift build -c release --product "${APP_NAME}" \
    --arch arm64 --arch x86_64

BIN_PATH=$(swift build -c release --product "${APP_NAME}" \
    --arch arm64 --arch x86_64 --show-bin-path)
cp "${BIN_PATH}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

echo "==> Verifying universal binary"
lipo -archs "${MACOS_DIR}/${APP_NAME}" | sed 's/^/    /'

echo "==> Copying app icon"
if [[ ! -f "scripts/AppIcon.icns" ]]; then
    echo "    AppIcon.icns missing — regenerating via make-icon.sh"
    ./scripts/make-icon.sh
fi
cp "scripts/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"

echo "==> Writing Info.plist"
cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_OS}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© $(date +%Y) WhatCable contributors</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

printf "APPL????" > "${CONTENTS_DIR}/PkgInfo"

if [[ -n "${DEVELOPER_ID}" ]]; then
    echo "==> Signing with Developer ID + hardened runtime"
    echo "    Identity: ${DEVELOPER_ID}"
    codesign --force --options runtime --timestamp \
        --entitlements "${ENTITLEMENTS}" \
        --sign "${DEVELOPER_ID}" \
        "${APP_DIR}"
else
    echo "==> Ad-hoc signing (no DEVELOPER_ID set)"
    codesign --force --deep --sign - "${APP_DIR}"
fi

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "${APP_DIR}" 2>&1 | sed 's/^/    /'

echo "==> Creating zip"
( cd "${DIST_DIR}" && ditto -c -k --keepParent "${APP_NAME}.app" "${APP_NAME}.zip" )

if [[ -n "${DEVELOPER_ID}" && -n "${NOTARY_PROFILE}" ]]; then
    echo "==> Submitting to Apple notarisation (this can take a few minutes)"
    xcrun notarytool submit "${DIST_DIR}/${APP_NAME}.zip" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait

    echo "==> Stapling notarisation ticket"
    xcrun stapler staple "${APP_DIR}"

    echo "==> Re-creating zip with stapled ticket"
    rm -f "${DIST_DIR}/${APP_NAME}.zip"
    ( cd "${DIST_DIR}" && ditto -c -k --keepParent "${APP_NAME}.app" "${APP_NAME}.zip" )

    echo "==> Verifying Gatekeeper acceptance"
    spctl --assess --type execute --verbose "${APP_DIR}" 2>&1 | sed 's/^/    /'
elif [[ -n "${DEVELOPER_ID}" ]]; then
    echo "==> NOTARY_PROFILE not set — skipping notarisation"
    echo "    Set it in .env once you've run:"
    echo "      xcrun notarytool store-credentials \"WhatCable-notary\" --apple-id ... --team-id ... --password ..."
fi

echo
echo "Done."
echo "  App:  ${APP_DIR}"
echo "  Zip:  ${DIST_DIR}/${APP_NAME}.zip"
