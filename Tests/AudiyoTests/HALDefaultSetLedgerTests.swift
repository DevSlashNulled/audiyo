import CoreAudio
import XCTest
@testable import Audiyo

final class HALDefaultSetLedgerTests: XCTestCase {
    func testConsumesMatchingPendingSetOnce() {
        var ledger = HALDefaultSetLedger()
        let now = Date()

        let recorded = ledger.record(selector: .input, deviceID: 42, now: now)

        XCTAssertEqual(recorded.selector, .input)
        XCTAssertEqual(recorded.deviceID, 42)
        XCTAssertEqual(ledger.pendingCount, 1)
        XCTAssertEqual(ledger.consume(selector: .input, deviceID: 42, now: now), recorded)
        XCTAssertNil(ledger.consume(selector: .input, deviceID: 42, now: now))
        XCTAssertEqual(ledger.pendingCount, 0)
    }

    func testDoesNotConsumeDifferentSelectorOrDevice() {
        var ledger = HALDefaultSetLedger()
        let now = Date()

        _ = ledger.record(selector: .output, deviceID: 7, now: now)

        XCTAssertNil(ledger.consume(selector: .systemOutput, deviceID: 7, now: now))
        XCTAssertNil(ledger.consume(selector: .output, deviceID: 8, now: now))
        XCTAssertEqual(ledger.pendingCount, 1)
        XCTAssertNotNil(ledger.consume(selector: .output, deviceID: 7, now: now))
    }

    func testReplacingSameSelectorAndDeviceKeepsLatestGeneration() {
        var ledger = HALDefaultSetLedger()
        let now = Date()

        _ = ledger.record(selector: .input, deviceID: 9, now: now)
        let latest = ledger.record(selector: .input, deviceID: 9, now: now.addingTimeInterval(0.1))

        XCTAssertEqual(ledger.pendingCount, 1)
        XCTAssertEqual(latest.generation, 2)
        XCTAssertEqual(ledger.consume(selector: .input, deviceID: 9, now: now), latest)
    }

    func testExpiresOldPendingSets() {
        var ledger = HALDefaultSetLedger(ttl: 1)
        let now = Date()

        _ = ledger.record(selector: .input, deviceID: 1, now: now)
        _ = ledger.record(selector: .output, deviceID: 2, now: now.addingTimeInterval(0.5))
        ledger.expire(now: now.addingTimeInterval(1.25))

        XCTAssertNil(ledger.consume(selector: .input, deviceID: 1, now: now.addingTimeInterval(1.25)))
        XCTAssertNotNil(ledger.consume(selector: .output, deviceID: 2, now: now.addingTimeInterval(1.25)))
    }
}
