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
    var isUserConfigured: Bool

    init(uid: String, name: String, transport: TransportKind, mode: PriorityMode = .automatic, lastSeen: Date? = nil, isUserConfigured: Bool = false) {
        self.uid = uid
        self.name = name
        self.transport = transport
        self.mode = mode
        self.lastSeen = lastSeen
        self.isUserConfigured = isUserConfigured
    }

    private enum CodingKeys: String, CodingKey {
        case uid, name, transport, mode, lastSeen, isUserConfigured
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(String.self, forKey: .uid)
        name = try container.decode(String.self, forKey: .name)
        transport = try container.decode(TransportKind.self, forKey: .transport)
        mode = try container.decode(PriorityMode.self, forKey: .mode)
        lastSeen = try container.decodeIfPresent(Date.self, forKey: .lastSeen)
        // Let legacy AirPlay history expire; preserve other existing priorities.
        isUserConfigured = try container.decodeIfPresent(Bool.self, forKey: .isUserConfigured) ?? (transport != .airPlay)
    }
}

struct PriorityConfig: Codable, Equatable {
    var version: Int = 1
    var input: [PriorityDevice]
    var output: [PriorityDevice]
    var pinnedSystemOutputUID: String?
    var masterAutoEnabled: Bool = true
    var notificationsEnabled: Bool = false
    var menuBarIconVisible: Bool = true
    var dockIconVisible: Bool = false

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
        case menuBarIconVisible
        case dockIconVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        input = try container.decodeIfPresent([PriorityDevice].self, forKey: .input) ?? []
        output = try container.decodeIfPresent([PriorityDevice].self, forKey: .output) ?? []
        pinnedSystemOutputUID = try container.decodeIfPresent(String.self, forKey: .pinnedSystemOutputUID)
        masterAutoEnabled = try container.decodeIfPresent(Bool.self, forKey: .masterAutoEnabled) ?? true
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
        menuBarIconVisible = try container.decodeIfPresent(Bool.self, forKey: .menuBarIconVisible) ?? true
        dockIconVisible = try container.decodeIfPresent(Bool.self, forKey: .dockIconVisible) ?? false
        ensureControlSurfaceVisible()
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

    func preferredDevices(for direction: AudioDirection) -> [PriorityDevice] {
        devices(for: direction).filter { $0.mode == .automatic }
    }

    func priority(for direction: AudioDirection) -> [String] {
        preferredDevices(for: direction).map(\.uid)
    }

    mutating func addToPriority(uid: String, direction: AudioDirection) {
        guard var device = knownDevice(uid: uid, direction: direction), device.mode != .automatic else { return }
        let order = priority(for: direction) + [uid]
        device.mode = .automatic
        device.isUserConfigured = true
        upsert(device, direction: direction)
        setPriority(order, for: direction)
    }

    mutating func removeFromPriority(uid: String, direction: AudioDirection) {
        guard var device = knownDevice(uid: uid, direction: direction) else { return }
        device.mode = .never
        device.isUserConfigured = true
        upsert(device, direction: direction)
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
            if pinnedSystemOutputUID == uid {
                pinnedSystemOutputUID = nil
            }
        }
    }

    mutating func setMenuBarIconVisible(_ visible: Bool) {
        if !visible && !dockIconVisible {
            dockIconVisible = true
        }
        menuBarIconVisible = visible
        ensureControlSurfaceVisible()
    }

    mutating func setDockIconVisible(_ visible: Bool) {
        if !visible && !menuBarIconVisible {
            menuBarIconVisible = true
        }
        dockIconVisible = visible
        ensureControlSurfaceVisible()
    }

    mutating func ensureControlSurfaceVisible() {
        if !menuBarIconVisible && !dockIconVisible {
            menuBarIconVisible = true
        }
    }

    private func reordered(_ devices: [PriorityDevice], by priority: [String]) -> [PriorityDevice] {
        let knownByUID = Dictionary(uniqueKeysWithValues: devices.map { ($0.uid, $0) })
        let ordered = priority.compactMap { knownByUID[$0] }
        let orderedUIDs = Set(ordered.map(\.uid))
        let remaining = devices.filter { !orderedUIDs.contains($0.uid) }
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
