#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-FileTransferApp}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/${APP_NAME}.app"
ENTITLEMENTS_PATH="$ROOT_DIR/appstore/AppStore.entitlements"
PKG_PATH="$DIST_DIR/${APP_NAME}-mac-app-store.pkg"

# Required for signed App Store package
: "${APP_SIGN_IDENTITY:?Set APP_SIGN_IDENTITY to your Apple Distribution/3rd Party Mac Developer Application certificate name}"
: "${INSTALLER_SIGN_IDENTITY:?Set INSTALLER_SIGN_IDENTITY to your Mac Installer Distribution/3rd Party Mac Developer Installer certificate name}"
: "${PROVISIONING_PROFILE_PATH:?Set PROVISIONING_PROFILE_PATH to your embedded.provisionprofile file path}"

if [[ ! -f "$ENTITLEMENTS_PATH" ]]; then
  echo "Missing entitlements file: $ENTITLEMENTS_PATH"
  exit 1
fi

if [[ ! -f "$PROVISIONING_PROFILE_PATH" ]]; then
  echo "Missing provisioning profile: $PROVISIONING_PROFILE_PATH"
  exit 1
fi

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build_app_bundle.sh"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle not found: $APP_PATH"
  exit 1
fi

cp "$PROVISIONING_PROFILE_PATH" "$APP_PATH/Contents/embedded.provisionprofile"

# Re-sign for App Store submission using sandbox entitlements
codesign --force --options runtime --entitlements "$ENTITLEMENTS_PATH" --sign "$APP_SIGN_IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

# Build installer package for App Store Connect upload
rm -f "$PKG_PATH"
productbuild --component "$APP_PATH" /Applications --sign "$INSTALLER_SIGN_IDENTITY" "$PKG_PATH"

pkgutil --check-signature "$PKG_PATH" || true

echo "Created App Store package: $PKG_PATH"
echo "Upload with Transporter or Xcode Organizer."
