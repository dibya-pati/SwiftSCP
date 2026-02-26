import Foundation

actor SSHTransferClient {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func transfer(
        request: TransferRequest,
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/scp")

        var arguments: [String] = [
            "-P", String(request.connection.port),
            "-o", "BatchMode=no",
            "-o", "StrictHostKeyChecking=accept-new"
        ]

        switch request.connection.authMethod {
        case .password:
            break
        case .key(let keyPath):
            guard !keyPath.isEmpty else {
                throw TransferError.missingKeyPath
            }
            arguments += ["-i", keyPath]
        }

        if request.recursive || isDirectory(path: request.localPath) {
            arguments.append("-r")
        }

        let remote = "\(request.connection.username)@\(request.connection.host):\(request.remotePath)"
        switch request.direction {
        case .upload:
            arguments += [request.localPath, remote]
        case .download:
            arguments += [remote, request.localPath]
        }

        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var env = ProcessInfo.processInfo.environment
        var askPassPath: String?
        if case .password = request.connection.authMethod {
            if let password = request.password, !password.isEmpty {
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

        let outputHandler: @Sendable (FileHandle) -> Void = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                onOutput(text)
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = outputHandler
        stderrPipe.fileHandleForReading.readabilityHandler = outputHandler

        try process.run()

        let cleanupAskPassPath = askPassPath

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { process in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                if let cleanupAskPassPath {
                    try? FileManager.default.removeItem(atPath: cleanupAskPassPath)
                }

                if process.terminationStatus == 0 {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: TransferError.transferFailed(code: Int(process.terminationStatus)))
                }
            }
        }
    }

    private func makeAskPassScript() throws -> String {
        let tempPath = NSTemporaryDirectory()
        let scriptURL = URL(fileURLWithPath: tempPath).appendingPathComponent("scp-askpass-\(UUID().uuidString).sh")
        let body = "#!/bin/sh\necho \"$SSH_TRANSFER_PASSWORD\"\n"
        try body.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        return scriptURL.path
    }

    private func isDirectory(path: String) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}

enum TransferError: LocalizedError {
    case missingPassword
    case missingKeyPath
    case transferFailed(code: Int)

    var errorDescription: String? {
        switch self {
        case .missingPassword:
            return "Password is required for password authentication."
        case .missingKeyPath:
            return "Private key path is required for key authentication."
        case .transferFailed(let code):
            return "Transfer failed with exit code \(code)."
        }
    }
}
