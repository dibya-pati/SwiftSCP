# macOS SSH Client – SwiftUI + Swift Requirements

## 1. Platform and Project Setup

- Target: macOS 14+ (adjust as needed).
- Architectures: Apple Silicon and Intel (Universal 2).
- App type: SwiftUI “App” lifecycle (no storyboards).
- Dependencies:
  - SSH library (e.g., libssh2 wrapper / SwiftNIO SSH / C-bridge).
  - Terminal rendering (custom view or wrapper around a text/terminal component).
- App icon:
  - Include a custom app icon in the packaged `.app`.
  - Icon asset must be license-free (self-generated preferred) and safe for distribution.

## 2. Data Model

### Connection

- Fields:
  - `id: UUID`
  - `name: String`
  - `host: String`
  - `port: Int`
  - `username: String`
  - `authMethod: AuthMethod`

- `AuthMethod` enum:
  - `.password`
  - `.key(path: String)`

### SessionState

- Fields:
  - `connection: Connection`
  - `isConnected: Bool`
  - `outputBuffer: String` (or `[TerminalLine]`)
  - `lastError: String?`

### Persistence

- Store connections in JSON or UserDefaults.
- Persist:
  - Host, port, username, connection name.
  - Path to private key file.
- Do *not* persist:
  - Passwords.
  - Private key contents.

## 3. SSH Core Layer

### SSHClient

- Responsibilities:
  - Establish SSH connection.
  - Authenticate via password or key.
  - Create PTY and handle interactive shell.
  - Stream output back to the UI.
  - Send user input to the remote shell.
  - Handle disconnects and errors.

- API (example):

  - `func connect(connection: Connection, password: String?) async throws`
  - `func send(_  Data) async throws`
  - `func resize(rows: Int, cols: Int) async`
  - `func disconnect()`

- Behavior:
  - Non-blocking I/O (async/await or background threads).
  - Callbacks/closures for:
    - `onOutput(String)`
    - `onDisconnect(Error?)`

## 4. SwiftUI Architecture

### AppViewModel (global state)

- Type: `@MainActor class AppViewModel: ObservableObject`
- Fields:
  - `@Published var connections: [Connection]`
  - `@Published var activeSessions: [UUID: SessionViewModel]`
- Responsibilities:
  - Load/save connections.
  - Create and track `SessionViewModel` instances.
  - Handle “New Connection”, “Delete Connection”, “Connect” actions.

### SessionViewModel

- Fields:
  - `let id: UUID`
  - `let connection: Connection`
  - `@Published var output: String`
  - `@Published var isConnected: Bool`
  - `@Published var lastError: String?`
- Methods:
  - `func connect(password: String?)`
  - `func disconnect()`
  - `func sendCommand(_ text: String)`
  - `func handleResize(rows: Int, cols: Int)`

## 5. UI Requirements

### Main Window

- Layout:
  - Sidebar: list of saved connections.
  - Main content: dual-pane browser (local + remote) after connect.
- Actions:
  - Click connection in sidebar.
  - Click “Connect” in sidebar.
  - On connect, open browser workspace for that connection.
  - Button: “New Connection”.
  - Button: “Connect” / “Disconnect”.

### Connection Editor

- Modal sheet or new window.
- Fields:
  - Name
  - Host
  - Port
  - Username
  - Auth method picker: Password vs Key file.
  - File picker for key path.
- Buttons:
  - Save
  - Cancel

### Quick Connect Bar

- Inline fields:
  - Host
  - Username
  - Port
- “Connect” button:
  - Creates a temporary `Connection` and opens a session.

### Session View

- Terminal area:
  - Scrollable.
  - Displays colored text later; start with plain text.
- Input:
  - Accept keyboard input and send to SSH session.
- Status:
  - Show connection status (Connected, Disconnected, Connecting…).
  - “Disconnect” button.
  - Optional: latency / host label.

### WinSCP-Style Browser Flow

- Replace manual transfer button flow with browser-driven file operations.
- After selecting a saved connection in the left sidebar, user clicks “Connect”.
- On successful connect, show:
  - Local file browser pane.
  - Remote file browser pane.
- Each pane must support:
  - Path field.
  - Up/parent navigation.
  - Double-click directory to enter.
- File copy behavior:
  - Drag local item to remote pane → upload.
  - Drag remote item to local pane → download.
  - Support files and directories.
- Show transfer status/log while drag-drop copies run.

### Authentication UX

- User must be able to choose auth type:
  - Password
  - Private key
- If key auth is selected:
  - Allow selecting/entering key file path.
  - Do not require password to initiate connection/transfer.
- If password auth is selected:
  - Prompt for password at runtime only.
  - Do not persist password.

### Remote Browser

- Add a remote file browser panel for the active connection.
- Must support:
  - Entering a remote path and listing directory contents.
  - Navigating into directories and moving to parent directory.
  - Drag-drop source for copy to local pane.
- Browser should work with both password and key auth.

## 6. Terminal Behavior

- Basic VT100/ANSI support:
  - At minimum: newlines, backspace, clear screen, simple colors.
- Scrollback:
  - Configurable limit (e.g., 5,000–10,000 lines).
- Copy/paste:
  - Mouse selection integrated with macOS clipboard.
  - Paste from clipboard sends text to remote.

## 7. macOS Integration

- Menus:
  - File:
    - New Connection (⌘N)
    - Close Session (⌘W)
  - App:
    - Preferences… (⌘,)
  - View:
    - Increase/Decrease font size.
    - Toggle theme (if you don’t rely solely on system appearance).

- Preferences:
  - Default font family and size.
  - Default theme (light/dark/system).
  - Default username (optional).

- Window management:
  - Remember window size/position.
  - Optionally reopen last sessions on launch.

## 8. Security and Privacy

- Do not store passwords in v1.
- Store only key file paths, not contents.
- Consider Keychain integration later for:
  - “Remember password” per connection.
- Provide “Clear all saved data” option.

## 9. MVP Definition

A usable v1 should:

1. Let the user create and save connections.
2. Connect via password or key file.
3. Open a session and run interactive commands.
4. Show session output in a scrollable view.
5. Allow basic copy/paste.
6. Cleanly disconnect and close sessions.
7. Show a license-free custom app icon in the clickable app bundle.
8. Support both key-based and password-based auth from the UI.
9. Provide dual-pane local/remote browsing after connect.
10. Copy files/folders via drag-drop between panes (WinSCP-like).
