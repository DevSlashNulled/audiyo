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

    func seed(from endpoints: [Endpoint], now: Date = Date()) -> PriorityConfig {
        var config = PriorityConfig()
        config.input = endpoints
            .filter { $0.direction == .input }
            .sorted()
            .map { endpoint in
                PriorityDevice(
                    uid: endpoint.uid,
                    name: endpoint.name,
                    transport: endpoint.transport,
                    mode: endpoint.transport == .bluetooth ? .never : .automatic,
                    lastSeen: now
                )
            }
        config.output = endpoints
            .filter { $0.direction == .output }
            .sorted()
            .map { endpoint in
                PriorityDevice(uid: endpoint.uid, name: endpoint.name, transport: endpoint.transport, mode: .automatic, lastSeen: now)
            }
        return config
    }
}

typealias KnownDevice = PriorityDevice

extension PriorityConfig {
    var inputPriority: [String] {
        get { input.map(\.uid) }
        set { input = compatibilityReordered(input, by: newValue) }
    }

    var outputPriority: [String] {
        get { output.map(\.uid) }
        set { output = compatibilityReordered(output, by: newValue) }
    }

    var knownDevices: [KnownDevice] {
        get { input + output }
        set {
            input = newValue
            output = []
        }
    }

    mutating func upsert(_ device: KnownDevice) {
        upsert(device, direction: device.direction)
    }

    private func compatibilityReordered(_ devices: [PriorityDevice], by priority: [String]) -> [PriorityDevice] {
        let byUID = Dictionary(uniqueKeysWithValues: devices.map { ($0.uid, $0) })
        let ordered = priority.compactMap { byUID[$0] }
        let orderedUIDs = Set(ordered.map(\.uid))
        return ordered + devices.filter { !orderedUIDs.contains($0.uid) }
    }
}

enum PriorityConfigSeeder {
    static func seed(from endpoints: [Endpoint], now: Date = Date()) -> PriorityConfig {
        let input = endpoints
            .filter { $0.direction == .input }
            .map { endpoint in
                PriorityDevice(
                    uid: endpoint.uid,
                    name: endpoint.name,
                    transport: endpoint.transport,
                    mode: endpoint.transport == .bluetooth ? .never : .automatic,
                    lastSeen: now
                )
            }
        let output = endpoints
            .filter { $0.direction == .output }
            .map { endpoint in
                PriorityDevice(uid: endpoint.uid, name: endpoint.name, transport: endpoint.transport, mode: .automatic, lastSeen: now)
            }
        return PriorityConfig(input: input, output: output)
    }
}

extension PriorityDevice {
    var direction: AudioDirection {
        .input
    }

    init(endpoint: Endpoint) {
        self.init(
            uid: endpoint.uid,
            name: endpoint.name,
            transport: endpoint.transport,
            mode: endpoint.transport == .bluetooth && endpoint.direction == .input ? .never : .automatic,
            lastSeen: Date()
        )
    }
}
