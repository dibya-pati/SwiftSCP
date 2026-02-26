import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    struct LocalRenameDraft: Identifiable {
        let id = UUID()
        var path: String
        var name: String
    }

    @Published var connections: [Connection] = []
    @Published var selectedConnectionID: Connection.ID?
    @Published var connectedConnectionID: Connection.ID?

    @Published var password: String = ""

    @Published var statusText: String = "Idle"
    @Published var isTransferring: Bool = false
    @Published var isBrowsingRemote: Bool = false
    @Published var isBrowsingLocal: Bool = false
    @Published var transferLog: String = ""

    @Published var remoteBrowsePath: String = "/"
    @Published var remoteEntries: [RemoteEntry] = []

    @Published var localBrowsePath: String = "/"
    @Published var localEntries: [LocalEntry] = []
    @Published var localRenameDraft: LocalRenameDraft?

    private let store = ConnectionStore()
    private let transferClient = SSHTransferClient()
    private let remoteBrowserClient = SSHRemoteBrowserClient()
    private let fileManager = FileManager.default

    var selectedConnection: Connection? {
        connections.first(where: { $0.id == selectedConnectionID })
    }

    var connectedConnection: Connection? {
        guard let connectedConnectionID else { return nil }
        return connections.first(where: { $0.id == connectedConnectionID })
    }

    var isConnected: Bool {
        connectedConnection != nil
    }

    func loadConnections() {
        Task {
            do {
                let loaded = try await store.load()
                await MainActor.run {
                    connections = loaded
                    if selectedConnectionID == nil {
                        selectedConnectionID = loaded.first?.id
                    }
                }
            } catch {
                statusText = "Failed to load connections: \(error.localizedDescription)"
            }
        }
    }

    func addOrUpdateConnection(_ connection: Connection) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
        } else {
            connections.append(connection)
        }
        if selectedConnectionID == nil {
            selectedConnectionID = connection.id
        }
        persistConnections()
    }

    func deleteConnection(_ connection: Connection) {
        connections.removeAll(where: { $0.id == connection.id })
        if selectedConnectionID == connection.id {
            selectedConnectionID = connections.first?.id
        }
        if connectedConnectionID == connection.id {
            disconnect()
        }
        persistConnections()
    }

    func connectSelected() {
        guard let selectedConnection else {
            statusText = "Select a connection first."
            return
        }

        if case .password = selectedConnection.authMethod, password.isEmpty {
            statusText = "Enter password to connect."
            return
        }

        connectedConnectionID = selectedConnection.id
        localBrowsePath = "/"
        remoteBrowsePath = "/"
        statusText = "Connected to \(selectedConnection.host)"

        browseLocalDirectory()
        browseRemoteDirectory()
    }

    func disconnect() {
        connectedConnectionID = nil
        remoteEntries = []
        statusText = "Disconnected"
    }

    func browseLocalDirectory() {
        guard !isBrowsingLocal else { return }

        let requestedPath = localBrowsePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedPath.isEmpty else {
            statusText = "Local path is required."
            return
        }

        let expandedPath = expandLocalPath(requestedPath)
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDir), isDir.boolValue else {
            statusText = "Local directory not found: \(requestedPath)"
            return
        }

        isBrowsingLocal = true
        defer { isBrowsingLocal = false }

        do {
            let urls = try fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: expandedPath),
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsPackageDescendants]
            )

            localEntries = urls.compactMap { url in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                let isDirectory = values?.isDirectory ?? false
                let size = values?.fileSize ?? 0
                return LocalEntry(
                    name: url.lastPathComponent,
                    fullPath: url.path,
                    isDirectory: isDirectory,
                    details: isDirectory ? "dir" : "\(size) bytes"
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory == rhs.isDirectory {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.isDirectory && !rhs.isDirectory
            }

            localBrowsePath = expandedPath
            statusText = "Loaded \(localEntries.count) local items"
        } catch {
            statusText = "Failed local browse: \(error.localizedDescription)"
        }
    }

    func browseLocalParentDirectory() {
        let currentURL = URL(fileURLWithPath: expandLocalPath(localBrowsePath))
        let parent = currentURL.deletingLastPathComponent().path
        localBrowsePath = parent.isEmpty ? "/" : parent
        browseLocalDirectory()
    }

    func setLocalBrowsePath(_ path: String) {
        localBrowsePath = path
        browseLocalDirectory()
    }

    func createLocalFolder() {
        let basePath = expandLocalPath(localBrowsePath)
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: basePath, isDirectory: &isDir), isDir.boolValue else {
            statusText = "Local directory not found: \(localBrowsePath)"
            return
        }

        var folderName = "New Folder"
        var destination = URL(fileURLWithPath: basePath).appendingPathComponent(folderName).path
        var suffix = 2
        while fileManager.fileExists(atPath: destination) {
            folderName = "New Folder \(suffix)"
            destination = URL(fileURLWithPath: basePath).appendingPathComponent(folderName).path
            suffix += 1
        }

        do {
            try fileManager.createDirectory(atPath: destination, withIntermediateDirectories: false)
            statusText = "Created \(folderName)"
            browseLocalDirectory()
            startLocalRename(path: destination)
        } catch {
            statusText = "Failed to create folder: \(error.localizedDescription)"
        }
    }

    func startLocalRename(path: String) {
        let sourceURL = URL(fileURLWithPath: path)
        localRenameDraft = LocalRenameDraft(path: path, name: sourceURL.lastPathComponent)
    }

    func setLocalRenameName(_ value: String) {
        guard var draft = localRenameDraft else { return }
        draft.name = value
        localRenameDraft = draft
    }

    func cancelLocalRename() {
        localRenameDraft = nil
    }

    func commitLocalRename() {
        guard let draft = localRenameDraft else { return }

        let newName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else {
            statusText = "Folder name cannot be empty."
            return
        }

        let sourceURL = URL(fileURLWithPath: draft.path)
        let destinationURL = sourceURL.deletingLastPathComponent().appendingPathComponent(newName)

        if destinationURL.path == sourceURL.path {
            localRenameDraft = nil
            return
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            statusText = "An item named '\(newName)' already exists."
            return
        }

        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            localRenameDraft = nil
            statusText = "Renamed to \(newName)"
            browseLocalDirectory()
        } catch {
            statusText = "Failed to rename folder: \(error.localizedDescription)"
        }
    }

    func openLocalEntry(_ entry: LocalEntry) {
        if entry.isDirectory {
            localBrowsePath = entry.fullPath
            browseLocalDirectory()
        }
    }

    func browseRemoteDirectory() {
        guard !isBrowsingRemote else { return }
        guard let connection = connectedConnection else {
            statusText = "Connect to a server first."
            return
        }

        let path = remoteBrowsePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            statusText = "Remote path is required."
            return
        }

        if case .password = connection.authMethod, password.isEmpty {
            statusText = "Enter password to browse remote files."
            return
        }

        isBrowsingRemote = true
        statusText = "Loading remote directory..."

        Task {
            do {
                let entries = try await remoteBrowserClient.listDirectory(
                    connection: connection,
                    remotePath: path,
                    password: password
                ) { [weak self] output in
                    Task { @MainActor in
                        self?.appendLog(output)
                    }
                }
                await MainActor.run {
                    remoteBrowsePath = path
                    remoteEntries = entries
                    statusText = "Loaded \(entries.count) remote items"
                    isBrowsingRemote = false
                }
            } catch {
                await MainActor.run {
                    statusText = error.localizedDescription
                    isBrowsingRemote = false
                }
            }
        }
    }

    func browseRemoteParentDirectory() {
        remoteBrowsePath = parentRemotePath(of: remoteBrowsePath)
        browseRemoteDirectory()
    }

    func openRemoteEntry(_ entry: RemoteEntry) {
        if entry.isDirectory {
            remoteBrowsePath = entry.fullPath
            browseRemoteDirectory()
        }
    }

    func uploadDraggedLocal(path: String, isDirectory: Bool) {
        guard let connection = connectedConnection else {
            statusText = "Connect to a server first."
            return
        }

        if case .password = connection.authMethod, password.isEmpty {
            statusText = "Enter password before uploading."
            return
        }

        let fileName = URL(fileURLWithPath: path).lastPathComponent
        let targetRemotePath = joinRemote(base: remoteBrowsePath, child: fileName)

        runTransfer(
            request: TransferRequest(
                connection: connection,
                direction: .upload,
                localPath: path,
                remotePath: targetRemotePath,
                password: password,
                recursive: isDirectory
            ),
            successMessage: "Uploaded \(fileName)",
            refreshAfter: { [weak self] in
                self?.browseRemoteDirectory()
            }
        )
    }

    func downloadDraggedRemote(path: String, isDirectory: Bool) {
        guard let connection = connectedConnection else {
            statusText = "Connect to a server first."
            return
        }

        if case .password = connection.authMethod, password.isEmpty {
            statusText = "Enter password before downloading."
            return
        }

        let fileName = (path as NSString).lastPathComponent
        let targetLocalPath = URL(fileURLWithPath: expandLocalPath(localBrowsePath))
            .appendingPathComponent(fileName)
            .path

        runTransfer(
            request: TransferRequest(
                connection: connection,
                direction: .download,
                localPath: targetLocalPath,
                remotePath: path,
                password: password,
                recursive: isDirectory
            ),
            successMessage: "Downloaded \(fileName)",
            refreshAfter: { [weak self] in
                self?.browseLocalDirectory()
            }
        )
    }

    func requiresPasswordForSelectedConnection() -> Bool {
        guard let selectedConnection else { return false }
        if case .password = selectedConnection.authMethod {
            return true
        }
        return false
    }

    private func runTransfer(
        request: TransferRequest,
        successMessage: String,
        refreshAfter: @escaping @MainActor () -> Void
    ) {
        guard !isTransferring else { return }

        isTransferring = true
        statusText = "Transferring..."

        Task {
            do {
                try await transferClient.transfer(request: request) { [weak self] output in
                    Task { @MainActor in
                        self?.appendLog(output)
                    }
                }
                await MainActor.run {
                    self.statusText = successMessage
                    self.isTransferring = false
                    refreshAfter()
                }
            } catch {
                await MainActor.run {
                    self.statusText = error.localizedDescription
                    self.isTransferring = false
                }
            }
        }
    }

    private func appendLog(_ text: String) {
        guard !text.isEmpty else { return }
        transferLog.append(text)
        if !transferLog.hasSuffix("\n") {
            transferLog.append("\n")
        }
    }

    private func expandLocalPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private func joinRemote(base: String, child: String) -> String {
        if base == "/" {
            return "/\(child)"
        }
        if base.hasSuffix("/") {
            return "\(base)\(child)"
        }
        return "\(base)/\(child)"
    }

    private func parentRemotePath(of path: String) -> String {
        if path == "/" || path == "~" {
            return path
        }

        if path.hasPrefix("~/") {
            let suffix = String(path.dropFirst(2))
            if suffix.isEmpty || !suffix.contains("/") {
                return "~"
            }
            let comps = suffix.split(separator: "/")
            let newSuffix = comps.dropLast().joined(separator: "/")
            return newSuffix.isEmpty ? "~" : "~/\(newSuffix)"
        }

        let components = path.split(separator: "/")
        if components.count <= 1 {
            return "/"
        }
        return "/" + components.dropLast().joined(separator: "/")
    }

    private func persistConnections() {
        let current = connections
        Task {
            do {
                try await store.save(current)
            } catch {
                await MainActor.run {
                    statusText = "Failed to save connections: \(error.localizedDescription)"
                }
            }
        }
    }
}
