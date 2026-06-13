import Foundation

enum PriorityMode: String, Codable, Equatable, CaseIterable {
    case automatic
    case never
}

typealias DeviceMode = PriorityMode

struct PriorityDevice: Codable, Equatable, Identifiable {
    var id: String { uid }

    let uid: String
    var name: String
    var transport: TransportKind
    var mode: PriorityMode
    var lastSeen: Date?

    init(uid: String, name: String, transport: TransportKind, mode: PriorityMode = .automatic, lastSeen: Date? = nil) {
        self.uid = uid
        self.name = name
        self.transport = transport
        self.mode = mode
        self.lastSeen = lastSeen
    }
}

struct PriorityConfig: Codable, Equatable {
    var version: Int = 1
    var input: [PriorityDevice]
    var output: [PriorityDevice]
    var pinnedSystemOutputUID: String?
    var masterAutoEnabled: Bool = true
    var notificationsEnabled: Bool = false
    var newBluetoothInputsNever: Bool = true

    init(input: [PriorityDevice] = [], output: [PriorityDevice] = [], pinnedSystemOutputUID: String? = nil) {
        self.input = input
        self.output = output
        self.pinnedSystemOutputUID = pinnedSystemOutputUID
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case input
        case output
        case pinnedSystemOutputUID
        case masterAutoEnabled
        case notificationsEnabled
        case newBluetoothInputsNever
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        input = try container.decodeIfPresent([PriorityDevice].self, forKey: .input) ?? []
        output = try container.decodeIfPresent([PriorityDevice].self, forKey: .output) ?? []
        pinnedSystemOutputUID = try container.decodeIfPresent(String.self, forKey: .pinnedSystemOutputUID)
        masterAutoEnabled = try container.decodeIfPresent(Bool.self, forKey: .masterAutoEnabled) ?? true
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
        newBluetoothInputsNever = try container.decodeIfPresent(Bool.self, forKey: .newBluetoothInputsNever) ?? true
    }

    func devices(for direction: AudioDirection) -> [PriorityDevice] {
        switch direction {
        case .input:
            return input
        case .output:
            return output
        }
    }

    var alertOutputUID: String? {
        get { pinnedSystemOutputUID }
        set { pinnedSystemOutputUID = newValue }
    }

    func priority(for direction: AudioDirection) -> [String] {
        devices(for: direction).map(\.uid)
    }

    mutating func setPriority(_ priority: [String], for direction: AudioDirection) {
        switch direction {
        case .input:
            input = reordered(input, by: priority)
        case .output:
            output = reordered(output, by: priority)
        }
    }

    func knownDevice(uid: String, direction: AudioDirection) -> PriorityDevice? {
        devices(for: direction).first { $0.uid == uid }
    }

    mutating func upsert(_ device: PriorityDevice, direction: AudioDirection) {
        switch direction {
        case .input:
            if let index = input.firstIndex(where: { $0.uid == device.uid }) {
                input[index] = device
            } else {
                input.append(device)
            }
        case .output:
            if let index = output.firstIndex(where: { $0.uid == device.uid }) {
                output[index] = device
            } else {
                output.append(device)
            }
        }
    }

    mutating func remove(uid: String, direction: AudioDirection) {
        switch direction {
        case .input:
            input.removeAll { $0.uid == uid }
        case .output:
            output.removeAll { $0.uid == uid }
        }
    }

    private func reordered(_ devices: [PriorityDevice], by priority: [String]) -> [PriorityDevice] {
        let knownByUID = Dictionary(uniqueKeysWithValues: devices.map { ($0.uid, $0) })
        let ordered = priority.compactMap { knownByUID[$0] }
        let remaining = devices.filter { !priority.contains($0.uid) }
        return ordered + remaining
    }
}

extension DefaultSelector {
    var direction: AudioDirection? {
        switch self {
        case .input:
            return .input
        case .output, .systemOutput:
            return .output
        }
    }

    var label: String {
        switch self {
        case .input:
            return "input"
        case .output:
            return "output"
        case .systemOutput:
            return "alerts"
        }
    }
}

struct EndpointOverride: Equatable {
    let uid: String
    let direction: AudioDirection
}

struct ActiveOverrides: Equatable {
    var inputUID: String?
    var outputUID: String?
    var systemOutputUID: String?

    init(inputUID: String? = nil, outputUID: String? = nil, systemOutputUID: String? = nil) {
        self.inputUID = inputUID
        self.outputUID = outputUID
        self.systemOutputUID = systemOutputUID
    }

    func uid(for direction: AudioDirection) -> String? {
        switch direction {
        case .input:
            return inputUID
        case .output:
            return outputUID
        }
    }
}

struct EnginePolicies: Equatable {
    var newBluetoothInputMode: PriorityMode
    var newInputMode: PriorityMode
    var newOutputMode: PriorityMode

    static let `default` = EnginePolicies(
        newBluetoothInputMode: .never,
        newInputMode: .automatic,
        newOutputMode: .automatic
    )
}
