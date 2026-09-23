import CoreAudio
import Foundation

enum HALDefaultSelector: Equatable, Hashable {
    case input
    case output
    case systemOutput
}

struct HALPendingDefaultSet: Equatable {
    let selector: HALDefaultSelector
    let deviceID: AudioDeviceID
    let generation: UInt64
    let createdAt: Date
}

struct HALDefaultSetLedger {
    private var generation: UInt64 = 0
    private var pendingSets: [HALPendingDefaultSet] = []
    private let ttl: TimeInterval

    init(ttl: TimeInterval = 2) {
        self.ttl = ttl
    }

    mutating func record(selector: HALDefaultSelector, deviceID: AudioDeviceID, now: Date = Date()) -> HALPendingDefaultSet {
        expire(now: now)
        generation += 1
        let set = HALPendingDefaultSet(selector: selector, deviceID: deviceID, generation: generation, createdAt: now)
        pendingSets.removeAll { $0.selector == selector && $0.deviceID == deviceID }
        pendingSets.append(set)
        return set
    }

    mutating func consume(selector: HALDefaultSelector, deviceID: AudioDeviceID, now: Date = Date()) -> HALPendingDefaultSet? {
        expire(now: now)
        guard let index = pendingSets.firstIndex(where: { $0.selector == selector && $0.deviceID == deviceID }) else {
            return nil
        }
        return pendingSets.remove(at: index)
    }

    mutating func expire(now: Date = Date()) {
        pendingSets.removeAll { now.timeIntervalSince($0.createdAt) > ttl }
    }

    var pendingCount: Int {
        pendingSets.count
    }
}

struct HALVolumeState: Equatable {
    let volume: Float?
    let isVolumeSettable: Bool
    let isMuted: Bool?
    let isMuteSettable: Bool
}
