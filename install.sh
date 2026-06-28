#!/bin/bash

set -eo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="BudgetingMac"
INSTALL_PATH="/Applications/${APP_NAME}.app"
BUDGETING_APP_GROUP="group.com.markodurasinovic.budgeting"

# Find the developer signing identity and team ID
SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | rg "Apple Development:" | head -1 | awk -F'"' '{print $2}')
if [ -z "${SIGN_IDENTITY}" ]; then
    echo "Error: No Apple Development certificate found. Widgets require proper code signing with sandbox."
    echo "Add a developer account in Xcode → Settings → Accounts."
    exit 1
fi
DEVELOPMENT_TEAM=$(echo "${SIGN_IDENTITY}" | rg -o '\(([A-Z0-9]+)\)$' | rg -o '[A-Z0-9]+')
echo "Using signing identity: ${SIGN_IDENTITY}"
echo "Development team: ${DEVELOPMENT_TEAM}"

if command -v xcodegen &> /dev/null; then
    echo "Regenerating Xcode project..."
    xcodegen generate
fi

# xcodegen resets entitlements files to empty dicts; write them back with sandbox + app-group
echo "Writing entitlements..."
cat > "${PROJECT_DIR}/BudgetingWidget/BudgetingWidget.entitlements" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.markodurasinovic.budgeting</string>
	</array>
</dict>
</plist>
EOF

cat > "${PROJECT_DIR}/BudgetingMac/BudgetingMac.entitlements" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.markodurasinovic.budgeting</string>
	</array>
</dict>
</plist>
EOF

echo "Building ${APP_NAME} (Release)..."

xcodebuild \
    -project "${PROJECT_DIR}/Budgeting.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    CODE_SIGNING_ALLOWED=NO \
    build \
    | tail -5

APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "Error: Built app not found at ${APP_PATH}"
    exit 1
fi

echo "Removing previous installation..."
rm -rf "${INSTALL_PATH}"

echo "Installing to ${INSTALL_PATH}..."
cp -R "${APP_PATH}" "${INSTALL_PATH}"

echo "Signing widget extension with sandbox entitlements..."
codesign --force --sign "${SIGN_IDENTITY}" \
    --entitlements "${PROJECT_DIR}/BudgetingWidget/BudgetingWidget.entitlements" \
    "${INSTALL_PATH}/Contents/PlugIns/BudgetingWidget.appex"

echo "Signing app bundle with entitlements..."
codesign --force --sign "${SIGN_IDENTITY}" \
    --entitlements "${PROJECT_DIR}/BudgetingMac/BudgetingMac.entitlements" \
    "${INSTALL_PATH}"

echo "Removing quarantine attribute..."
xattr -cr "${INSTALL_PATH}"

# Migrate existing SwiftData store to the App Group container if needed
GROUP_APP_SUPPORT="${HOME}/Library/Group Containers/${BUDGETING_APP_GROUP}/Library/Application Support"
LEGACY_STORES=(
    "${HOME}/Library/Application Support/default.store"
    "${HOME}/Library/Containers/com.markodurasinovic.Budgeting.Mac/Data/Library/Application Support/default.store"
)
for LEGACY in "${LEGACY_STORES[@]}"; do
    if [ -f "${LEGACY}" ]; then
        LEGACY_COUNT=$(sqlite3 "${LEGACY}" "SELECT count(*) FROM ZENTRY;" 2>/dev/null)
        GROUP_COUNT=$(sqlite3 "${GROUP_APP_SUPPORT}/default.store" "SELECT count(*) FROM ZENTRY;" 2>/dev/null)
        if [ "${LEGACY_COUNT:-0}" -gt "${GROUP_COUNT:-0}" ] 2>/dev/null; then
            echo "Migrating ${LEGACY_COUNT} entries from legacy store to App Group..."
            mkdir -p "${GROUP_APP_SUPPORT}"
            cp "${LEGACY}" "${GROUP_APP_SUPPORT}/default.store"
            cp "${LEGACY}-wal" "${GROUP_APP_SUPPORT}/default.store-wal" 2>/dev/null || true
            cp "${LEGACY}-shm" "${GROUP_APP_SUPPORT}/default.store-shm" 2>/dev/null || true
        fi
    fi
done

echo "Registering with LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R "${INSTALL_PATH}"

echo "Registering widget with pluginkit..."
pluginkit -a "${INSTALL_PATH}/Contents/PlugIns/BudgetingWidget.appex"

echo "Done! You can launch ${APP_NAME} from /Applications or Spotlight."
echo ""
echo "Widget: After launching the app at least once, open Notification Center → Edit Widgets → search 'Budget'."

rm -rf "${BUILD_DIR}"