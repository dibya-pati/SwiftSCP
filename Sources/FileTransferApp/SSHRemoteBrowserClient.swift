import Foundation

actor SSHRemoteBrowserClient {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func listDirectory(
        connection: Connection,
        remotePath: String,
        password: String?,
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> [RemoteEntry] {
        let escapedPath = shellEscape(remotePath)
        let command = "LC_ALL=C ls -la -p \(escapedPath)"
        let output = try runSSH(
            connection: connection,
            password: password,
            remoteCommand: command,
            onOutput: onOutput
        )
        return parseLSOutput(output, basePath: remotePath)
    }

    private func runSSH(
        connection: Connection,
        password: String?,
        remoteCommand: String,
        onOutput: @escaping @Sendable (String) -> Void
    ) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

        var arguments: [String] = [
            "-p", String(connection.port),
            "-o", "BatchMode=no",
            "-o", "StrictHostKeyChecking=accept-new"
        ]

        switch connection.authMethod {
        case .password:
            break
        case .key(let keyPath):
            guard !keyPath.isEmpty else {
                throw TransferError.missingKeyPath
            }
            arguments += ["-i", keyPath]
        }

        arguments.append("\(connection.username)@\(connection.host)")
        arguments.append(remoteCommand)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var env = ProcessInfo.processInfo.environment
        var askPassPath: String?
        if case .password = connection.authMethod {
            if let password, !password.isEmpty {
                let path = try makeAskPassScript()
                askPassPath = path
                env["SSH_ASKPASS"] = path
                env["SSH_ASKPASS_REQUIRE"] = "force"
                env["SSH_TRANSFER_PASSWORD"] = password
                env["DISPLAY"] = "codex"
                process.standardInput = FileHandle.nullDevice
            } else {
                throw TransferError.missingPassword
            }
        }
        process.environment = env

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        if !stderr.isEmpty {
            onOutput(stderr)
        }

        if let askPassPath {
            try? fileManager.removeItem(atPath: askPassPath)
        }

        if process.terminationStatus != 0 {
            throw TransferError.transferFailed(code: Int(process.terminationStatus))
        }

        return stdout
    }

    private func parseLSOutput(_ output: String, basePath: String) -> [RemoteEntry] {
        let lines = output.split(whereSeparator: { $0.isNewline })
        var entries: [RemoteEntry] = []

        for line in lines {
            let text = String(line)
            if text.hasPrefix("total ") || text.isEmpty {
                continue
            }

            let parts = text.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: true)
            guard parts.count >= 9 else {
                continue
            }

            let perms = String(parts[0])
            let size = String(parts[4])
            let nameWithSlash = String(parts[8])
            if nameWithSlash == "." || nameWithSlash == ".." {
                continue
            }

            let isDirectory = perms.hasPrefix("d") || nameWithSlash.hasSuffix("/")
            let normalizedName = isDirectory ? String(nameWithSlash.dropLast()) : nameWithSlash
            let fullPath = joinRemote(base: basePath, child: normalizedName)
            let details = "\(parts[0])  \(size)"

            entries.append(
                RemoteEntry(
                    name: normalizedName,
                    fullPath: fullPath,
                    isDirectory: isDirectory,
                    details: details
                )
            )
        }

        return entries.sorted { lhs, rhs in
            if lhs.isDirectory == rhs.isDirectory {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.isDirectory && !rhs.isDirectory
        }
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

    private func shellEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    private func makeAskPassScript() throws -> String {
        let tempPath = NSTemporaryDirectory()
        let scriptURL = URL(fileURLWithPath: tempPath).appendingPathComponent("ssh-askpass-\(UUID().uuidString).sh")
        let body = "#!/bin/sh\necho \"$SSH_TRANSFER_PASSWORD\"\n"
        try body.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        return scriptURL.path
    }
}
