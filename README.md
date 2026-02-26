# FileTransferApp (MVP)

Basic macOS SwiftUI app for transferring files between local and remote hosts over SSH using `scp`.

## Features

- Save named SSH connections (host/port/username/auth mode).
- Connect from sidebar to open a WinSCP-style dual-pane browser.
- Drag local items to remote pane to upload.
- Drag remote items to local pane to download.
- Password auth (runtime only; not persisted) or private key path.
- Remote browser to list and navigate server directories.
- Transfer log output and status.
- License-free generated custom app icon in the app bundle.

## Run

```bash
swift run
```

## Build Clickable macOS App

```bash
./scripts/build_app_bundle.sh
open dist/FileTransferApp.app
```

This creates a Finder-clickable app bundle at `dist/FileTransferApp.app`.

## App Store Prep

- Entitlements: `appstore/AppStore.entitlements`
- Build App Store package: `scripts/build_app_store_pkg.sh`
- Guide: `docs/APP_STORE_RELEASE.md`

## GitHub Push

- Guide: `docs/GITHUB_PUSH.md`

## Notes

- Passwords are never stored.
- Only key *paths* are saved.
- This MVP shells out to `/usr/bin/scp`.
