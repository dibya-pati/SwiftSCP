import Foundation

actor ConnectionStore {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load() throws -> [Connection] {
        let url = try fileURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Connection].self, from: data)
    }

    func save(_ connections: [Connection]) throws {
        let url = try fileURL()
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(connections)
        try data.write(to: url, options: .atomic)
    }

    private func fileURL() throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport
            .appendingPathComponent("FileTransferApp", isDirectory: true)
            .appendingPathComponent("connections.json", isDirectory: false)
    }
}
