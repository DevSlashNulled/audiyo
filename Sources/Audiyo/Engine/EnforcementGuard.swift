import Foundation

struct EnforcementAttempt: Hashable {
    let selector: DefaultSelector
    let uid: String
}

struct EnforcementGuard {
    var maxAttempts = 3
    var window: TimeInterval = 10
    var suspension: TimeInterval = 30

    private var attempts: [EnforcementAttempt: [Date]] = [:]
    private var suspendedUntil: [EnforcementAttempt: Date] = [:]

    init() {}

    mutating func recordReassertion(selector: DefaultSelector, uid: String, at now: Date) -> Date? {
        let key = EnforcementAttempt(selector: selector, uid: uid)
        let activeAttempts = (attempts[key] ?? []).filter { now.timeIntervalSince($0) <= window } + [now]
        attempts[key] = activeAttempts

        guard activeAttempts.count > maxAttempts else { return nil }

        let priorSuspension = suspendedUntil[key].map { max(0, $0.timeIntervalSince(now)) } ?? 0
        let nextSuspension = priorSuspension > 0 ? max(suspension, priorSuspension * 2) : suspension
        let until = now.addingTimeInterval(nextSuspension)
        suspendedUntil[key] = until
        attempts[key] = []
        return until
    }

    func isSuspended(selector: DefaultSelector, uid: String, at now: Date) -> Bool {
        suspendedUntil[EnforcementAttempt(selector: selector, uid: uid)].map { $0 > now } == true
    }

    func suspendedDefaults(at now: Date) -> [AudioDirection: Date] {
        var result: [AudioDirection: Date] = [:]
        for (attempt, until) in suspendedUntil where until > now {
            guard let direction = attempt.selector.direction else { continue }
            if result[direction].map({ until > $0 }) ?? true {
                result[direction] = until
            }
        }
        return result
    }
}
