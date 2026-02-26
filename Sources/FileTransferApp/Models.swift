import Foundation

enum AuthMethod: Codable, Equatable {
    case password
    case key(path: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case path
    }

    private enum Kind: String, Codable {
        case password
        case key
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .password:
            self = .password
        case .key:
            let path = try container.decode(String.self, forKey: .path)
            self = .key(path: path)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .password:
            try container.encode(Kind.password, forKey: .kind)
        case .key(let path):
            try container.encode(Kind.key, forKey: .kind)
            try container.encode(path, forKey: .path)
        }
    }
}

struct Connection: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authMethod: AuthMethod

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authMethod: AuthMethod = .password
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
    }
}

enum TransferDirection: String, CaseIterable, Identifiable {
    case upload
    case download

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upload:
            return "Upload"
        case .download:
            return "Download"
        }
    }
}

struct TransferRequest {
    var connection: Connection
    var direction: TransferDirection
    var localPath: String
    var remotePath: String
    var password: String?
    var recursive: Bool = false
}

struct RemoteEntry: Identifiable, Hashable {
    var id: String { fullPath }
    var name: String
    var fullPath: String
    var isDirectory: Bool
    var details: String
}

struct LocalEntry: Identifiable, Hashable {
    var id: String { fullPath }
    var name: String
    var fullPath: String
    var isDirectory: Bool
    var details: String
}
