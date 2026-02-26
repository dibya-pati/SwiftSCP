import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    @State private var showingConnectionEditor = false
    @State private var editingConnection: Connection?

    var body: some View {
        NavigationSplitView {
            VStack {
                List(selection: $viewModel.selectedConnectionID) {
                    ForEach(viewModel.connections) { connection in
                        VStack(alignment: .leading) {
                            Text(connection.name)
                            Text("\(connection.username)@\(connection.host):\(connection.port)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(connection.id)
                    }
                }

                VStack(spacing: 8) {
                    Button("New Connection") {
                        editingConnection = nil
                        showingConnectionEditor = true
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Edit Connection") {
                        if let selected = viewModel.selectedConnection {
                            editingConnection = selected
                            showingConnectionEditor = true
                        }
                    }
                    .disabled(viewModel.selectedConnection == nil)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Delete Connection", role: .destructive) {
                        if let selected = viewModel.selectedConnection {
                            viewModel.deleteConnection(selected)
                        }
                    }
                    .disabled(viewModel.selectedConnection == nil)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        if viewModel.isConnected {
                            Button("Disconnect") {
                                viewModel.disconnect()
                            }
                        } else {
                            Button("Connect") {
                                viewModel.connectSelected()
                            }
                            .disabled(viewModel.selectedConnection == nil)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationSplitViewColumnWidth(min: 320, ideal: 360)
            .navigationTitle("Connections")
        } detail: {
            VStack(alignment: .leading, spacing: 12) {
                if let connected = viewModel.connectedConnection {
                    HStack {
                        Text("Connected: \(connected.username)@\(connected.host)")
                            .font(.headline)
                        Spacer()
                        if viewModel.isTransferring {
                            ProgressView()
                        }
                    }

                    if connectionUsesPassword(connected) {
                        SecureField("Password (runtime only, not saved)", text: $viewModel.password)
                    } else {
                        Text("Using private key authentication")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        localBrowserPane
                        remoteBrowserPane
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Select a saved connection on the left and click Connect.")
                            .font(.headline)

                        if let selected = viewModel.selectedConnection {
                            Text("Ready: \(selected.username)@\(selected.host):\(selected.port)")
                                .foregroundStyle(.secondary)

                            if viewModel.requiresPasswordForSelectedConnection() {
                                SecureField("Password (runtime only, not saved)", text: $viewModel.password)
                            } else {
                                Text("This connection uses a private key.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                GroupBox("Log") {
                    ScrollView {
                        Text(viewModel.transferLog.isEmpty ? "No output yet." : viewModel.transferLog)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .font(.system(.body, design: .monospaced))
                    }
                    .frame(height: 72)
                }

                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Browser")
        }
        .sheet(isPresented: $showingConnectionEditor) {
            ConnectionEditorView(connection: editingConnection) { saved in
                viewModel.addOrUpdateConnection(saved)
            }
        }
        .sheet(item: $viewModel.localRenameDraft) { _ in
            VStack(alignment: .leading, spacing: 12) {
                Text("Rename Item")
                    .font(.headline)

                TextField("Folder name", text: localRenameNameBinding)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        viewModel.commitLocalRename()
                    }

                HStack {
                    Spacer()
                    Button("Cancel") {
                        viewModel.cancelLocalRename()
                    }
                    Button("Save") {
                        viewModel.commitLocalRename()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(localRenameNameBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .frame(width: 380)
        }
    }

    private var localBrowserPane: some View {
        GroupBox("Local") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Local path", text: $viewModel.localBrowsePath)
                    Button("Choose...") {
                        chooseLocalFolder()
                    }
                    Button("Load") {
                        viewModel.browseLocalDirectory()
                    }
                    .disabled(viewModel.isBrowsingLocal)
                    Button("Up") {
                        viewModel.browseLocalParentDirectory()
                    }
                    .disabled(viewModel.isBrowsingLocal)
                    Button("New Folder") {
                        viewModel.createLocalFolder()
                    }
                    .disabled(viewModel.isBrowsingLocal)
                }

                if viewModel.isBrowsingLocal {
                    ProgressView()
                }

                List(viewModel.localEntries) { entry in
                    HStack {
                        Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                            .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                        VStack(alignment: .leading) {
                            Text(entry.name)
                            Text(entry.details)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDrag {
                        itemProvider(for: .init(source: .local, path: entry.fullPath, isDirectory: entry.isDirectory))
                    }
                    .onTapGesture(count: 2) {
                        viewModel.openLocalEntry(entry)
                    }
                    .contextMenu {
                        Button("Rename...") {
                            viewModel.startLocalRename(path: entry.fullPath)
                        }
                    }
                }
                .frame(minHeight: 260)
                .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                    handleDrop(providers, target: .local)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var remoteBrowserPane: some View {
        GroupBox("Remote") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Remote path", text: $viewModel.remoteBrowsePath)
                    Button("Load") {
                        viewModel.browseRemoteDirectory()
                    }
                    .disabled(viewModel.isBrowsingRemote)
                    Button("Up") {
                        viewModel.browseRemoteParentDirectory()
                    }
                    .disabled(viewModel.isBrowsingRemote)
                }

                if viewModel.isBrowsingRemote {
                    ProgressView()
                }

                List(viewModel.remoteEntries) { entry in
                    HStack {
                        Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                            .foregroundStyle(entry.isDirectory ? .yellow : .secondary)
                        VStack(alignment: .leading) {
                            Text(entry.name)
                            Text(entry.details)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDrag {
                        itemProvider(for: .init(source: .remote, path: entry.fullPath, isDirectory: entry.isDirectory))
                    }
                    .onTapGesture(count: 2) {
                        viewModel.openRemoteEntry(entry)
                    }
                }
                .frame(minHeight: 260)
                .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                    handleDrop(providers, target: .remote)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func connectionUsesPassword(_ connection: Connection) -> Bool {
        if case .password = connection.authMethod {
            return true
        }
        return false
    }

    private func itemProvider(for payload: DragPayload) -> NSItemProvider {
        let provider = NSItemProvider()
        let encoded = (try? JSONEncoder().encode(payload)) ?? Data()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
            completion(encoded, nil)
            return nil
        }
        return provider
    }

    private func handleDrop(_ providers: [NSItemProvider], target: DropTarget) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) else {
            return false
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
            guard
                let data,
                let payload = try? JSONDecoder().decode(DragPayload.self, from: data)
            else {
                return
            }

            Task { @MainActor in
                switch (payload.source, target) {
                case (.local, .remote):
                    viewModel.uploadDraggedLocal(path: payload.path, isDirectory: payload.isDirectory)
                case (.remote, .local):
                    viewModel.downloadDraggedRemote(path: payload.path, isDirectory: payload.isDirectory)
                default:
                    break
                }
            }
        }

        return true
    }

    private var localRenameNameBinding: Binding<String> {
        Binding(
            get: { viewModel.localRenameDraft?.name ?? "" },
            set: { viewModel.setLocalRenameName($0) }
        )
    }

    private func chooseLocalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Folder"
        panel.directoryURL = URL(fileURLWithPath: viewModel.localBrowsePath)

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.setLocalBrowsePath(url.path)
        }
    }
}

private enum DropTarget {
    case local
    case remote
}

private struct DragPayload: Codable {
    enum Source: String, Codable {
        case local
        case remote
    }

    let source: Source
    let path: String
    let isDirectory: Bool
}
