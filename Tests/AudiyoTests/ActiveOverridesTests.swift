import XCTest
@testable import Audiyo

final class ActiveOverridesTests: XCTestCase {
    private let now = Fixtures.baseDate

    func testSelectionClearsAfterDeviceStaysDisconnectedForGracePeriod() {
        var overrides = ActiveOverrides(inputUID: Fixtures.accentumInput.uid, outputUID: Fixtures.accentumOutput.uid)

        XCTAssertNotNil(overrides.expire(connected: [Fixtures.soloCast, Fixtures.accentumOutput], now: now))
        let deadline = overrides.expire(connected: [Fixtures.soloCast, Fixtures.accentumOutput], now: now.addingTimeInterval(10))
        XCTAssertEqual(deadline, now.addingTimeInterval(ActiveOverrides.disconnectGracePeriod))
        XCTAssertEqual(overrides.inputUID, Fixtures.accentumInput.uid)

        XCTAssertNil(overrides.expire(connected: [Fixtures.soloCast, Fixtures.accentumOutput], now: now.addingTimeInterval(60)))
        XCTAssertNil(overrides.inputUID)
        XCTAssertEqual(overrides.outputUID, Fixtures.accentumOutput.uid)
    }

    func testReconnectingWithinGracePeriodKeepsSelection() {
        var overrides = ActiveOverrides(inputUID: Fixtures.accentumInput.uid)

        XCTAssertNotNil(overrides.expire(connected: [Fixtures.soloCast], now: now))
        XCTAssertNil(overrides.expire(connected: [Fixtures.soloCast, Fixtures.accentumInput], now: now.addingTimeInterval(30)))
        let deadline = overrides.expire(connected: [Fixtures.soloCast], now: now.addingTimeInterval(70))

        XCTAssertEqual(deadline, now.addingTimeInterval(70 + ActiveOverrides.disconnectGracePeriod))
        XCTAssertEqual(overrides.inputUID, Fixtures.accentumInput.uid)
    }

    func testClearedSelectionsMatchNoSelection() {
        var overrides = ActiveOverrides(outputUID: Fixtures.accentumOutput.uid)

        _ = overrides.expire(connected: [], now: now)
        _ = overrides.expire(connected: [], now: now.addingTimeInterval(ActiveOverrides.disconnectGracePeriod))

        XCTAssertEqual(overrides, ActiveOverrides())
    }
}
