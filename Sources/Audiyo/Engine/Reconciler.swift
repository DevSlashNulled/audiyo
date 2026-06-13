import Foundation

enum ReconcileBadgeState: Equatable {
    case normal
    case hfpWarning
    case suspended(until: Date)
}

struct DefaultChange: Equatable {
    let direction: AudioDirection
    let uid: String
}

struct ReconcileDecision: Equatable {
    var desiredInput: DefaultChange?
    var desiredOutput: DefaultChange?
    var desiredSystemOutputUID: String?
    var configAmendments: PriorityConfig
    var badgeState: ReconcileBadgeState

    var hasChanges: Bool {
        desiredInput != nil || desiredOutput != nil || desiredSystemOutputUID != nil
    }
}

struct Reconciler {
    func reconcile(
        snapshot: HALSnapshot,
        config: PriorityConfig,
        overrides: ActiveOverrides = ActiveOverrides(),
        policies: EnginePolicies = .default,
        masterAuto: Bool = true,
        suspendedDefaults: [AudioDirection: Date] = [:]
    ) -> ReconcileDecision {
        let amendedConfig = amend(config: config, with: snapshot.endpoints, policies: policies, now: snapshot.createdAt)
        let badgeState = badgeState(for: snapshot, suspendedDefaults: suspendedDefaults)

        guard masterAuto else {
            return ReconcileDecision(configAmendments: amendedConfig, badgeState: badgeState)
        }

        let desiredInput = desiredDefault(
            direction: .input,
            currentUID: snapshot.defaultInputUID,
            endpoints: snapshot.endpoints,
            config: amendedConfig,
            overrideUID: overrides.inputUID,
            suspendedUntil: suspendedDefaults[.input],
            now: snapshot.createdAt
        )
        let desiredOutput = desiredDefault(
            direction: .output,
            currentUID: snapshot.defaultOutputUID,
            endpoints: snapshot.endpoints,
            config: amendedConfig,
            overrideUID: overrides.outputUID,
            suspendedUntil: suspendedDefaults[.output],
            now: snapshot.createdAt
        )

        let desiredSystemOutput = desiredSystemOutput(
            snapshot: snapshot,
            config: amendedConfig,
            outputWillChangeTo: desiredOutput?.uid,
            overrideUID: overrides.systemOutputUID,
            suspendedUntil: suspendedDefaults[.output],
            now: snapshot.createdAt
        )

        return ReconcileDecision(
            desiredInput: desiredInput,
            desiredOutput: desiredOutput,
            desiredSystemOutputUID: desiredSystemOutput,
            configAmendments: amendedConfig,
            badgeState: badgeState
        )
    }

    private func desiredDefault(
        direction: AudioDirection,
        currentUID: String?,
        endpoints: [Endpoint],
        config: PriorityConfig,
        overrideUID: String?,
        suspendedUntil: Date?,
        now: Date
    ) -> DefaultChange? {
        guard suspendedUntil.map({ $0 > now }) != true else { return nil }
        let connected = endpoints.filter { $0.direction == direction }
        let connectedUIDs = Set(connected.map(\.uid))

        if let overrideUID, connectedUIDs.contains(overrideUID) {
            return overrideUID == currentUID ? nil : DefaultChange(direction: direction, uid: overrideUID)
        }

        guard let desiredUID = config.devices(for: direction).first(where: { device in
            device.mode != .never && connectedUIDs.contains(device.uid)
        })?.uid else {
            return nil
        }

        return desiredUID == currentUID ? nil : DefaultChange(direction: direction, uid: desiredUID)
    }

    private func desiredSystemOutput(
        snapshot: HALSnapshot,
        config: PriorityConfig,
        outputWillChangeTo: String?,
        overrideUID: String?,
        suspendedUntil: Date?,
        now: Date
    ) -> String? {
        guard suspendedUntil.map({ $0 > now }) != true else { return nil }
        let connectedOutputs = Set(snapshot.endpoints.filter { $0.direction == .output }.map(\.uid))
        let desiredUID = overrideUID ?? config.pinnedSystemOutputUID
        guard let desiredUID, connectedOutputs.contains(desiredUID) else { return nil }

        if desiredUID != snapshot.defaultSystemOutputUID {
            return desiredUID
        }

        if outputWillChangeTo != nil, desiredUID != outputWillChangeTo {
            return desiredUID
        }

        return nil
    }

    private func amend(config: PriorityConfig, with endpoints: [Endpoint], policies: EnginePolicies, now: Date) -> PriorityConfig {
        var config = config
        appendMissingDevices(direction: .input, endpoints: endpoints, config: &config, policies: policies, now: now)
        appendMissingDevices(direction: .output, endpoints: endpoints, config: &config, policies: policies, now: now)
        markSeenDevices(direction: .input, endpoints: endpoints, config: &config, now: now)
        markSeenDevices(direction: .output, endpoints: endpoints, config: &config, now: now)
        return config
    }

    private func appendMissingDevices(
        direction: AudioDirection,
        endpoints: [Endpoint],
        config: inout PriorityConfig,
        policies: EnginePolicies,
        now: Date
    ) {
        let knownUIDs = Set(config.devices(for: direction).map(\.uid))
        let missing = endpoints
            .filter { $0.direction == direction && !knownUIDs.contains($0.uid) }
            .sorted()
            .map { endpoint in
                PriorityDevice(
                    uid: endpoint.uid,
                    name: endpoint.name,
                    transport: endpoint.transport,
                    mode: defaultMode(for: endpoint, policies: policies),
                    lastSeen: now
                )
            }

        guard !missing.isEmpty else { return }
        switch direction {
        case .input:
            config.input.append(contentsOf: missing)
        case .output:
            config.output.append(contentsOf: missing)
        }
    }

    private func markSeenDevices(direction: AudioDirection, endpoints: [Endpoint], config: inout PriorityConfig, now: Date) {
        let connectedUIDs = Set(endpoints.filter { $0.direction == direction }.map(\.uid))
        switch direction {
        case .input:
            for index in config.input.indices where connectedUIDs.contains(config.input[index].uid) {
                config.input[index].lastSeen = now
            }
        case .output:
            for index in config.output.indices where connectedUIDs.contains(config.output[index].uid) {
                config.output[index].lastSeen = now
            }
        }
    }

    private func defaultMode(for endpoint: Endpoint, policies: EnginePolicies) -> PriorityMode {
        if endpoint.direction == .input && endpoint.transport == .bluetooth {
            return policies.newBluetoothInputMode
        }
        return endpoint.direction == .input ? policies.newInputMode : policies.newOutputMode
    }

    private func badgeState(for snapshot: HALSnapshot, suspendedDefaults: [AudioDirection: Date]) -> ReconcileBadgeState {
        if let latestSuspension = suspendedDefaults.values.filter({ $0 > snapshot.createdAt }).max() {
            return .suspended(until: latestSuspension)
        }

        let hasHFP = snapshot.endpoints.contains { endpoint in
            endpoint.transport == .bluetooth
                && ((endpoint.direction == .input && endpoint.isRunningSomewhere)
                    || (endpoint.direction == .output && endpoint.sampleRate > 0 && endpoint.sampleRate < 44_100))
        }

        return hasHFP ? .hfpWarning : .normal
    }
}

private extension ReconcileDecision {
    init(configAmendments: PriorityConfig, badgeState: ReconcileBadgeState) {
        self.init(
            desiredInput: nil,
            desiredOutput: nil,
            desiredSystemOutputUID: nil,
            configAmendments: configAmendments,
            badgeState: badgeState
        )
    }
}
