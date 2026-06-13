import Foundation

struct BadgeEndpoint: Equatable {
    var uid: String
    var direction: AudioDirection
    var transport: TransportKind
    var sampleRate: Double
    var isRunningSomewhere: Bool

    init(endpoint: Endpoint, isRunningSomewhere: Bool = false) {
        uid = endpoint.uid
        direction = endpoint.direction
        transport = endpoint.transport
        sampleRate = endpoint.sampleRate
        self.isRunningSomewhere = isRunningSomewhere
    }

    init(uid: String, direction: AudioDirection, transport: TransportKind, sampleRate: Double, isRunningSomewhere: Bool) {
        self.uid = uid
        self.direction = direction
        self.transport = transport
        self.sampleRate = sampleRate
        self.isRunningSomewhere = isRunningSomewhere
    }
}

struct BadgeMonitorState: Equatable {
    var isHFPActive: Bool
    var reason: String?
}

typealias BadgeState = ReconcileBadgeState

struct BadgeMonitor {
    func evaluate(_ endpoints: [BadgeEndpoint]) -> BadgeMonitorState {
        if let input = endpoints.first(where: { $0.transport == .bluetooth && $0.direction == .input && $0.isRunningSomewhere }) {
            return BadgeMonitorState(isHFPActive: true, reason: "\(input.uid) input is active")
        }

        if let output = endpoints.first(where: { $0.transport == .bluetooth && $0.direction == .output && $0.sampleRate > 0 && $0.sampleRate < 44_100 }) {
            return BadgeMonitorState(isHFPActive: true, reason: "\(output.uid) output is in call-mode")
        }

        return BadgeMonitorState(isHFPActive: false, reason: nil)
    }
}
