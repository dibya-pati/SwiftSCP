# SwiftSCP

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

## How To Use

1. Open the app and create a connection from the left sidebar (`New Connection`).
2. Set host, username, port, and auth mode:
   - `Key file` for SSH key login
   - `Password` for password login (runtime only)
3. Select the saved connection and click `Connect`.
4. Use the dual-pane browser:
   - Left pane: local files
   - Right pane: remote files
5. Transfer files/folders by drag and drop:
   - local -> remote to upload
   - remote -> local to download
6. Use `New Folder` on the local pane to create a folder, then rename it in the prompt.
7. Check transfer output in the log panel at the bottom.

## App Store Prep

- Entitlements: `appstore/AppStore.entitlements`
- Build App Store package: `scripts/build_app_store_pkg.sh`
- Guide: `guides/APP_STORE_RELEASE.md`

## GitHub Push

- Guide: `guides/GITHUB_PUSH.md`

## Notes

- Passwords are never stored.
- Only key *paths* are saved.
- The app shells out to `/usr/bin/scp` and `/usr/bin/ssh`.
