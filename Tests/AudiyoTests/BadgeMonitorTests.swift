import XCTest
@testable import Audiyo

final class BadgeMonitorTests: XCTestCase {
    func testBluetoothInputRunningShowsWarning() {
        let state = BadgeMonitor().evaluate([
            BadgeEndpoint(uid: "bt-mic", direction: .input, transport: .bluetooth, sampleRate: 16_000, isRunningSomewhere: true)
        ])

        XCTAssertTrue(state.isHFPActive)
        XCTAssertEqual(state.reason, "bt-mic input is active")
    }

    func testBluetoothOutputCallModeRateShowsWarning() {
        let state = BadgeMonitor().evaluate([
            BadgeEndpoint(uid: "bt-out", direction: .output, transport: .bluetooth, sampleRate: 24_000, isRunningSomewhere: false)
        ])

        XCTAssertTrue(state.isHFPActive)
        XCTAssertEqual(state.reason, "bt-out output is in call-mode")
    }

    func testZeroRateDoesNotShowWarning() {
        let state = BadgeMonitor().evaluate([
            BadgeEndpoint(uid: "bt-out", direction: .output, transport: .bluetooth, sampleRate: 0, isRunningSomewhere: false)
        ])

        XCTAssertFalse(state.isHFPActive)
    }
}
