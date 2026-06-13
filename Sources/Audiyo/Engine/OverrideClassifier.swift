import Foundation

enum DefaultSelector: Hashable {
    case input
    case output
    case systemOutput
}

struct PendingDefaultSet: Equatable {
    let selector: DefaultSelector
    let deviceID: UInt32
    let generation: Int
    let createdAt: Date
}

struct DefaultChangeEvent: Equatable {
    let selector: DefaultSelector
    let endpoint: Endpoint
    let occurredAt: Date
}

struct OverrideClassifierState: Equatable {
    var appearedAtByUID: [String: Date] = [:]
    var lastTopologyChangeAt: Date?
    var lastWakeAt: Date?
    var pendingSets: [PendingDefaultSet] = []

    init(
        appearedAtByUID: [String: Date] = [:],
        lastTopologyChangeAt: Date? = nil,
        lastWakeAt: Date? = nil,
        pendingSets: [PendingDefaultSet] = []
    ) {
        self.appearedAtByUID = appearedAtByUID
        self.lastTopologyChangeAt = lastTopologyChangeAt
        self.lastWakeAt = lastWakeAt
        self.pendingSets = pendingSets
    }
}

enum OverrideClassification: Equatable {
    case selfEvent
    case macOSAutoSwitch
    case humanOverride(EndpointOverride)
}

struct OverrideClassifier {
    var selfEventWindow: TimeInterval = 2
    var appearedWindow: TimeInterval = 5
    var topologyWindow: TimeInterval = 3
    var wakeWindow: TimeInterval = 10

    func classify(_ event: DefaultChangeEvent, state: OverrideClassifierState) -> OverrideClassification {
        if hasPendingSet(for: event, state: state) {
            return .selfEvent
        }

        if state.appearedAtByUID[event.endpoint.uid].map({ event.occurredAt.timeIntervalSince($0) <= appearedWindow }) == true {
            return .macOSAutoSwitch
        }

        if state.lastTopologyChangeAt.map({ event.occurredAt.timeIntervalSince($0) <= topologyWindow }) == true {
            return .macOSAutoSwitch
        }

        if state.lastWakeAt.map({ event.occurredAt.timeIntervalSince($0) <= wakeWindow }) == true {
            return .macOSAutoSwitch
        }

        return .humanOverride(EndpointOverride(uid: event.endpoint.uid, direction: event.endpoint.direction))
    }

    private func hasPendingSet(for event: DefaultChangeEvent, state: OverrideClassifierState) -> Bool {
        state.pendingSets.contains { pending in
            pending.selector == event.selector
                && pending.deviceID == event.endpoint.deviceID
                && event.occurredAt.timeIntervalSince(pending.createdAt) <= selfEventWindow
        }
    }
}
