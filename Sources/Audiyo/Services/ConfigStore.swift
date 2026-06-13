import Foundation

enum ConfigStoreError: Error, Equatable {
    case unsupportedVersion(Int)
}

final class ConfigStore {
    let url: URL

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(url: URL? = nil) {
        if let url {
            self.url = url
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.url = base.appendingPathComponent("audiyo", isDirectory: true).appendingPathComponent("config.json")
        }

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    static var live: ConfigStore {
        ConfigStore()
    }

    func load() throws -> PriorityConfig {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return PriorityConfig()
        }

        let data = try Data(contentsOf: url)
        let config = try decoder.decode(PriorityConfig.self, from: data)
        guard config.version == 1 else {
            throw ConfigStoreError.unsupportedVersion(config.version)
        }
        return config
    }

    func save(_ config: PriorityConfig) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(config)
        try data.write(to: url, options: [.atomic])
    }
}
