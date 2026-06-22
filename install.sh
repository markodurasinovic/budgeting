#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="BudgetingMac"
INSTALL_PATH="/Applications/${APP_NAME}.app"

if command -v xcodegen &> /dev/null; then
    echo "Regenerating Xcode project..."
    xcodegen generate
fi

echo "Building ${APP_NAME} (Release)..."

xcodebuild \
    -project "${PROJECT_DIR}/Budgeting.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
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

echo "Signing app bundle..."
codesign --force --deep --sign - "${INSTALL_PATH}"

echo "Removing quarantine attribute..."
xattr -cr "${INSTALL_PATH}"

echo "Done! You can launch ${APP_NAME} from /Applications or Spotlight."

rm -rf "${BUILD_DIR}"