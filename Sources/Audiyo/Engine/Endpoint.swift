import CoreAudio
import Foundation

enum AudioDirection: String, CaseIterable, Codable, Comparable {
    case input
    case output

    static func < (lhs: AudioDirection, rhs: AudioDirection) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension AudioDirection {
    var coreAudioScope: AudioObjectPropertyScope {
        switch self {
        case .input:
            return kAudioDevicePropertyScopeInput
        case .output:
            return kAudioDevicePropertyScopeOutput
        }
    }
}

enum TransportKind: String, Codable {
    case airPlay = "AirPlay"
    case bluetooth = "Bluetooth"
    case builtIn = "Built-in"
    case displayPort = "DisplayPort"
    case hdmi = "HDMI"
    case usb = "USB"
    case unknown = "Unknown"
}

struct Endpoint: Identifiable, Hashable, Codable, Comparable {
    var id: String { uid + ":" + direction.rawValue }

    let uid: String
    let direction: AudioDirection
    let transport: TransportKind
    let name: String
    let channels: Int
    let sampleRate: Double
    let isRunningSomewhere: Bool
    let deviceID: UInt32

    init(
        uid: String,
        direction: AudioDirection,
        transport: TransportKind,
        name: String,
        channels: Int,
        sampleRate: Double,
        deviceID: UInt32,
        isRunningSomewhere: Bool = false
    ) {
        self.uid = uid
        self.direction = direction
        self.transport = transport
        self.name = name
        self.channels = channels
        self.sampleRate = sampleRate
        self.deviceID = deviceID
        self.isRunningSomewhere = isRunningSomewhere
    }

    static func < (lhs: Endpoint, rhs: Endpoint) -> Bool {
        if lhs.direction != rhs.direction {
            return lhs.direction < rhs.direction
        }
        if lhs.name.localizedStandardCompare(rhs.name) != .orderedSame {
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        return lhs.uid < rhs.uid
    }
}

struct HALSnapshot: Equatable {
    let endpoints: [Endpoint]
    let defaultInputUID: String?
    let defaultOutputUID: String?
    let defaultSystemOutputUID: String?
    let createdAt: Date
    let error: String?
}
