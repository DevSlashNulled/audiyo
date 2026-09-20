import XCTest
@testable import Audiyo

final class ReconcilerTests: XCTestCase {
    private let reconciler = Reconciler()

    func testStompsMacOSBluetoothMicGrabBackToPreferredInput() {
        let snapshot = Fixtures.snapshot(defaultInputUID: Fixtures.accentumInput.uid)

        let decision = reconciler.reconcile(snapshot: snapshot, config: Fixtures.config)

        XCTAssertEqual(decision.desiredInput, DefaultChange(direction: .input, uid: Fixtures.soloCast.uid))
    }

    func testNeverDeviceIsSkippedWhenPreferredInputDisconnected() {
        let snapshot = Fixtures.snapshot(
            endpoints: [Fixtures.builtInMic, Fixtures.accentumInput, Fixtures.accentumOutput],
            defaultInputUID: Fixtures.accentumInput.uid
        )

        let decision = reconciler.reconcile(snapshot: snapshot, config: Fixtures.config)

        XCTAssertEqual(decision.desiredInput, DefaultChange(direction: .input, uid: Fixtures.builtInMic.uid))
    }

    func testHumanOverrideWinsWhileEndpointIsConnected() {
        let snapshot = Fixtures.snapshot(defaultInputUID: Fixtures.soloCast.uid)
        let overrides = ActiveOverrides(inputUID: Fixtures.builtInMic.uid)
        let config = PriorityConfig(
            input: Fixtures.config.input,
            output: Fixtures.config.output,
            pinnedSystemOutputUID: Fixtures.config.pinnedSystemOutputUID
        )
        let connectedSnapshot = Fixtures.snapshot(
            endpoints: [Fixtures.soloCast, Fixtures.builtInMic, Fixtures.accentumOutput],
            defaultInputUID: Fixtures.soloCast.uid
        )

        let decision = reconciler.reconcile(snapshot: connectedSnapshot, config: config, overrides: overrides)

        XCTAssertEqual(decision.desiredInput, DefaultChange(direction: .input, uid: Fixtures.builtInMic.uid))
        XCTAssertNil(reconciler.reconcile(snapshot: snapshot, config: config, overrides: overrides).desiredInput)
    }

    func testMasterAutoOffOnlyAmendsConfig() {
        let snapshot = Fixtures.snapshot(defaultInputUID: Fixtures.accentumInput.uid)

        let decision = reconciler.reconcile(snapshot: snapshot, config: Fixtures.config, masterAuto: false)

        XCTAssertFalse(decision.hasChanges)
    }

    func testPinnedSystemOutputIsReassertedWhenOutputWillChange() {
        let snapshot = Fixtures.snapshot(
            defaultOutputUID: Fixtures.builtInSpeaker.uid,
            defaultSystemOutputUID: Fixtures.builtInSpeaker.uid
        )

        let decision = reconciler.reconcile(snapshot: snapshot, config: Fixtures.config)

        XCTAssertEqual(decision.desiredOutput, DefaultChange(direction: .output, uid: Fixtures.accentumOutput.uid))
        XCTAssertEqual(decision.desiredSystemOutputUID, Fixtures.builtInSpeaker.uid)
    }

    func testNewDevicesStayOutsidePriorityListsWithoutChangingMacOSDefaults() {
        let airPlay = Endpoint(uid: "new-airplay", direction: .output, transport: .airPlay, name: "AirPlay Speaker", channels: 2, sampleRate: 48_000, deviceID: 100)
        let endpoints = [Fixtures.soloCast, Fixtures.builtInMic, Fixtures.accentumInput, Fixtures.accentumOutput, Fixtures.builtInSpeaker, airPlay]
        let snapshot = Fixtures.snapshot(
            endpoints: endpoints,
            defaultInputUID: Fixtures.accentumInput.uid,
            defaultOutputUID: airPlay.uid
        )

        let decision = reconciler.reconcile(snapshot: snapshot, config: PriorityConfig())
        let discovered = decision.configAmendments.input + decision.configAmendments.output

        XCTAssertEqual(Set(discovered.map(\.uid)), Set(endpoints.map(\.uid)))
        XCTAssertTrue(decision.configAmendments.preferredDevices(for: .input).isEmpty)
        XCTAssertTrue(decision.configAmendments.preferredDevices(for: .output).isEmpty)
        for device in discovered {
            XCTAssertEqual(device.mode, .never, device.uid)
            XCTAssertFalse(device.isUserConfigured, device.uid)
            XCTAssertEqual(device.lastSeen, Fixtures.baseDate, device.uid)
        }
        XCTAssertFalse(decision.hasChanges)
    }

    func testTemporarySelectionOfOtherDeviceDoesNotAddItToPriorities() {
        let snapshot = Fixtures.snapshot(defaultInputUID: Fixtures.soloCast.uid)
        let originalPriority = Fixtures.config.priority(for: .input)
        let temporary = reconciler.reconcile(
            snapshot: snapshot,
            config: Fixtures.config,
            overrides: ActiveOverrides(inputUID: Fixtures.accentumInput.uid)
        )

        XCTAssertEqual(temporary.desiredInput, DefaultChange(direction: .input, uid: Fixtures.accentumInput.uid))
        XCTAssertEqual(temporary.configAmendments.priority(for: .input), originalPriority)
        XCTAssertEqual(temporary.configAmendments.knownDevice(uid: Fixtures.accentumInput.uid, direction: .input)?.mode, .never)
        XCTAssertEqual(temporary.configAmendments.knownDevice(uid: Fixtures.accentumInput.uid, direction: .input)?.isUserConfigured, false)

        let resumed = reconciler.reconcile(
            snapshot: Fixtures.snapshot(defaultInputUID: Fixtures.accentumInput.uid),
            config: temporary.configAmendments,
            overrides: ActiveOverrides()
        )

        XCTAssertEqual(resumed.desiredInput, DefaultChange(direction: .input, uid: Fixtures.soloCast.uid))
        XCTAssertEqual(resumed.configAmendments.priority(for: .input), originalPriority)
    }

    func testOfflinePrioritiesLeaveMacOSDefaultsAloneUntilTheyReconnect() {
        let config = PriorityConfig(
            input: [
                PriorityDevice(uid: Fixtures.soloCast.uid, name: Fixtures.soloCast.name, transport: .usb, mode: .automatic, isUserConfigured: true),
                PriorityDevice(uid: Fixtures.accentumInput.uid, name: Fixtures.accentumInput.name, transport: .bluetooth, mode: .never)
            ],
            output: [
                PriorityDevice(uid: Fixtures.accentumOutput.uid, name: Fixtures.accentumOutput.name, transport: .bluetooth, mode: .automatic, isUserConfigured: true),
                PriorityDevice(uid: Fixtures.builtInSpeaker.uid, name: Fixtures.builtInSpeaker.name, transport: .builtIn, mode: .never)
            ]
        )
        let offline = reconciler.reconcile(
            snapshot: Fixtures.snapshot(
                endpoints: [Fixtures.accentumInput, Fixtures.builtInSpeaker],
                defaultInputUID: Fixtures.accentumInput.uid,
                defaultOutputUID: Fixtures.builtInSpeaker.uid
            ),
            config: config
        )

        XCTAssertFalse(offline.hasChanges)
        XCTAssertEqual(offline.configAmendments.priority(for: .input), [Fixtures.soloCast.uid])
        XCTAssertEqual(offline.configAmendments.priority(for: .output), [Fixtures.accentumOutput.uid])

        let reconnected = reconciler.reconcile(
            snapshot: Fixtures.snapshot(
                defaultInputUID: Fixtures.accentumInput.uid,
                defaultOutputUID: Fixtures.builtInSpeaker.uid
            ),
            config: offline.configAmendments
        )

        XCTAssertEqual(reconnected.desiredInput, DefaultChange(direction: .input, uid: Fixtures.soloCast.uid))
        XCTAssertEqual(reconnected.desiredOutput, DefaultChange(direction: .output, uid: Fixtures.accentumOutput.uid))
    }

    func testDisconnectedDevicesExpireAtSevenDaysWithAutoOff() {
        let now = Fixtures.baseDate
        let cutoff = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let recentInput = PriorityDevice(uid: "recent-input", name: "Mic", transport: .usb, lastSeen: cutoff.addingTimeInterval(1))
        let firstOutput = PriorityDevice(uid: "first-output", name: "First", transport: .bluetooth, lastSeen: now)
        let secondOutput = PriorityDevice(uid: "second-output", name: "Second", transport: .airPlay, lastSeen: cutoff.addingTimeInterval(1))
        let config = PriorityConfig(
            input: [
                PriorityDevice(uid: "old-input", name: "Old Mic", transport: .usb, lastSeen: cutoff.addingTimeInterval(-1)),
                recentInput
            ],
            output: [
                firstOutput,
                PriorityDevice(uid: "old-airplay", name: "Old AirPlay", transport: .airPlay, lastSeen: cutoff),
                secondOutput,
                PriorityDevice(uid: "old-usb", name: "Old USB", transport: .usb, lastSeen: cutoff)
            ]
        )

        let decision = reconciler.reconcile(snapshot: Fixtures.snapshot(endpoints: [], at: now), config: config, masterAuto: false)

        XCTAssertEqual(decision.configAmendments.input, [recentInput])
        XCTAssertEqual(decision.configAmendments.output, [firstOutput, secondOutput])
        XCTAssertFalse(decision.hasChanges)
    }

    func testConnectedDevicesAreRefreshedBeforeCleanupForTheirDirection() {
        let now = Fixtures.baseDate
        let oldDate = now.addingTimeInterval(-8 * 24 * 60 * 60)
        let endpoint = Endpoint(uid: "shared", direction: .output, transport: .airPlay, name: "Speaker", channels: 2, sampleRate: 48_000, deviceID: 100)
        let recentOutput = PriorityDevice(uid: "recent", name: "Recent", transport: .usb, lastSeen: now)
        var connectedOutput = PriorityDevice(uid: endpoint.uid, name: endpoint.name, transport: endpoint.transport, lastSeen: oldDate)
        let config = PriorityConfig(
            input: [PriorityDevice(uid: endpoint.uid, name: "Mic", transport: .usb, lastSeen: oldDate)],
            output: [
                connectedOutput,
                recentOutput,
                PriorityDevice(uid: "stale-duplicate", name: endpoint.name, transport: .airPlay, lastSeen: oldDate)
            ]
        )

        let decision = reconciler.reconcile(snapshot: Fixtures.snapshot(endpoints: [endpoint], at: now), config: config)

        connectedOutput.lastSeen = now
        XCTAssertTrue(decision.configAmendments.input.isEmpty)
        XCTAssertEqual(decision.configAmendments.output, [connectedOutput, recentOutput])
    }

    func testFailedSnapshotDoesNotAmendRememberedDevices() {
        let oldDate = Fixtures.baseDate.addingTimeInterval(-8 * 24 * 60 * 60)
        let config = PriorityConfig(
            input: [PriorityDevice(uid: Fixtures.accentumInput.uid, name: Fixtures.accentumInput.name, transport: .bluetooth, lastSeen: oldDate)],
            output: [
                PriorityDevice(uid: "old-airplay", name: "Speaker", transport: .airPlay, lastSeen: oldDate),
                PriorityDevice(uid: "undated", name: "Undated", transport: .usb)
            ]
        )
        let snapshot = HALSnapshot(
            endpoints: [Fixtures.accentumInput, Fixtures.builtInSpeaker],
            defaultInputUID: nil,
            defaultOutputUID: nil,
            defaultSystemOutputUID: nil,
            createdAt: Fixtures.baseDate,
            error: "CoreAudio unavailable"
        )

        let decision = reconciler.reconcile(snapshot: snapshot, config: config)

        XCTAssertEqual(decision.configAmendments, config)
    }

    func testUndatedDevicesReceiveOnePersistedSevenDayGracePeriod() throws {
        let now = Fixtures.baseDate
        let config = PriorityConfig(output: [PriorityDevice(uid: "undated", name: "Speaker", transport: .airPlay)])
        let first = reconciler.reconcile(snapshot: Fixtures.snapshot(endpoints: [], at: now), config: config)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigStore(url: directory.appendingPathComponent("config.json"))

        XCTAssertEqual(first.configAmendments.output.first?.lastSeen, now)
        try store.save(first.configAmendments)
        let loaded = try store.load()
        let beforeExpiry = reconciler.reconcile(
            snapshot: Fixtures.snapshot(endpoints: [], at: now.addingTimeInterval(7 * 24 * 60 * 60 - 1)),
            config: loaded
        )

        XCTAssertEqual(beforeExpiry.configAmendments.output, first.configAmendments.output)
        let expired = reconciler.reconcile(
            snapshot: Fixtures.snapshot(endpoints: [], at: now.addingTimeInterval(7 * 24 * 60 * 60)),
            config: beforeExpiry.configAmendments
        )
        XCTAssertTrue(expired.configAmendments.output.isEmpty)
    }

    func testExpiredDeviceIsRediscoveredAsOtherWithoutChangingPriority() {
        let now = Fixtures.baseDate
        let oldDate = now.addingTimeInterval(-8 * 24 * 60 * 60)
        let endpoint = Endpoint(uid: "returning", direction: .output, transport: .airPlay, name: "Speaker", channels: 2, sampleRate: 48_000, deviceID: 100)
        let config = PriorityConfig(output: [
            PriorityDevice(uid: endpoint.uid, name: endpoint.name, transport: endpoint.transport, lastSeen: oldDate),
            PriorityDevice(uid: Fixtures.builtInSpeaker.uid, name: Fixtures.builtInSpeaker.name, transport: .builtIn, lastSeen: now)
        ])
        let cleaned = reconciler.reconcile(
            snapshot: Fixtures.snapshot(endpoints: [Fixtures.builtInSpeaker], defaultOutputUID: Fixtures.builtInSpeaker.uid, at: now),
            config: config
        )

        XCTAssertEqual(cleaned.configAmendments.output.map(\.uid), [Fixtures.builtInSpeaker.uid])
        let reconnectedAt = now.addingTimeInterval(1)
        let reconnected = reconciler.reconcile(
            snapshot: Fixtures.snapshot(endpoints: [endpoint, Fixtures.builtInSpeaker], defaultOutputUID: Fixtures.builtInSpeaker.uid, at: reconnectedAt),
            config: cleaned.configAmendments
        )

        XCTAssertEqual(reconnected.configAmendments.output.map(\.uid), [Fixtures.builtInSpeaker.uid, endpoint.uid])
        XCTAssertEqual(reconnected.configAmendments.output.last?.mode, .never)
        XCTAssertEqual(reconnected.configAmendments.output.last?.lastSeen, reconnectedAt)
        XCTAssertEqual(reconnected.configAmendments.output.last?.isUserConfigured, false)
        XCTAssertEqual(reconnected.configAmendments.priority(for: .output), [Fixtures.builtInSpeaker.uid])
        XCTAssertFalse(reconnected.hasChanges)
    }

    func testConfiguredAndPinnedDevicesKeepTheirPreferencesIndefinitely() throws {
        let now = Fixtures.baseDate
        let oldDate = now.addingTimeInterval(-365 * 24 * 60 * 60)
        let configuredInput = PriorityDevice(uid: "preferred-mic", name: "Mic", transport: .usb, lastSeen: oldDate, isUserConfigured: true)
        let configuredOutput = PriorityDevice(uid: "preferred-output", name: "Speaker", transport: .airPlay, mode: .never, lastSeen: oldDate, isUserConfigured: true)
        let pinnedOutput = PriorityDevice(uid: "alerts", name: "Alerts", transport: .airPlay, lastSeen: oldDate)
        let config = PriorityConfig(
            input: [
                configuredInput,
                PriorityDevice(uid: pinnedOutput.uid, name: "Unconfigured Mic", transport: .usb, lastSeen: oldDate)
            ],
            output: [
                configuredOutput,
                PriorityDevice(uid: "unconfigured-never", name: "Old Speaker", transport: .airPlay, mode: .never, lastSeen: oldDate),
                pinnedOutput
            ],
            pinnedSystemOutputUID: pinnedOutput.uid
        )
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigStore(url: directory.appendingPathComponent("config.json"))
        try store.save(config)
        let loaded = try store.load()

        XCTAssertEqual(loaded, config)
        let decision = reconciler.reconcile(snapshot: Fixtures.snapshot(endpoints: [], at: now), config: loaded)

        XCTAssertEqual(decision.configAmendments.input, [configuredInput])
        XCTAssertEqual(decision.configAmendments.output, [configuredOutput, pinnedOutput])
        XCTAssertEqual(decision.configAmendments.pinnedSystemOutputUID, pinnedOutput.uid)
    }

    func testNewAlertDeviceIsKeptAfterAnotherAlertDeviceIsChosen() {
        let endpoint = Fixtures.builtInSpeaker
        let decision = reconciler.reconcile(
            snapshot: Fixtures.snapshot(endpoints: [endpoint]),
            config: PriorityConfig(pinnedSystemOutputUID: endpoint.uid)
        )
        var config = decision.configAmendments
        XCTAssertEqual(config.output.first?.isUserConfigured, true)
        config.pinnedSystemOutputUID = nil

        let later = reconciler.reconcile(
            snapshot: Fixtures.snapshot(endpoints: [], at: Fixtures.baseDate.addingTimeInterval(365 * 24 * 60 * 60)),
            config: config
        )

        XCTAssertEqual(later.configAmendments.output, config.output)
    }

    func testHFPBadgeUsesRunningBluetoothInputOrLowBluetoothOutputRate() {
        let runningInput = Fixtures.snapshot(endpoints: [Fixtures.accentumRunningInput])
        let callModeOutput = Fixtures.snapshot(endpoints: [Fixtures.accentumCallModeOutput])
        let normalOutput = Fixtures.snapshot(endpoints: [Fixtures.accentumOutput])

        XCTAssertEqual(reconciler.reconcile(snapshot: runningInput, config: Fixtures.config).badgeState, .hfpWarning)
        XCTAssertEqual(reconciler.reconcile(snapshot: callModeOutput, config: Fixtures.config).badgeState, .hfpWarning)
        XCTAssertEqual(reconciler.reconcile(snapshot: normalOutput, config: Fixtures.config).badgeState, .normal)
    }
}
