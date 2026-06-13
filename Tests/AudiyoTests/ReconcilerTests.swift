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

    func testNewBluetoothInputsAreAddedAsNever() {
        let config = PriorityConfig()
        let snapshot = Fixtures.snapshot(endpoints: [Fixtures.accentumInput], defaultInputUID: Fixtures.accentumInput.uid)

        let decision = reconciler.reconcile(snapshot: snapshot, config: config)

        XCTAssertEqual(decision.configAmendments.input.first?.uid, Fixtures.accentumInput.uid)
        XCTAssertEqual(decision.configAmendments.input.first?.mode, .never)
        XCTAssertNil(decision.desiredInput)
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
