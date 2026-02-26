# App Store Release Guide (macOS)

This project can be submitted as a **free macOS app** via App Store Connect.

## 1. Apple setup

1. In the Apple Developer portal, create an App ID for your bundle identifier (for example, `com.example.swiftscp`).
2. Enable App Sandbox capability for the app.
3. Create a macOS App Store provisioning profile for that App ID.
4. Install required certificates in Keychain:
   - App signing certificate (Apple Distribution / 3rd Party Mac Developer Application)
   - Installer signing certificate (Mac Installer Distribution / 3rd Party Mac Developer Installer)

## 2. Build a signed App Store package

Run:

```bash
APP_SIGN_IDENTITY="Apple Distribution: Your Name (TEAMID)" \
INSTALLER_SIGN_IDENTITY="Mac Installer Distribution: Your Name (TEAMID)" \
PROVISIONING_PROFILE_PATH="/absolute/path/to/embedded.provisionprofile" \
./scripts/build_app_store_pkg.sh
```

Output package:

- `dist/FileTransferApp-mac-app-store.pkg`

## 3. Upload to App Store Connect

Upload the package with either:

1. **Transporter** app (recommended for pkg uploads), or
2. **Xcode Organizer** (if using an archive flow).

## 4. Configure as a free app

In App Store Connect:

1. Create the app record.
2. Set pricing to **Free** in Pricing and Availability.
3. Fill in metadata, screenshots, and privacy fields.
4. Submit for review.

## Notes

- Sandbox entitlements are stored in `appstore/AppStore.entitlements`.
- Local file access entitlement is set to user-selected read/write. Use the `Choose...` button in the local pane to grant access in sandboxed builds.
- Passwords are not persisted.
