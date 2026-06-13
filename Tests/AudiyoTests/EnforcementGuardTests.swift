import XCTest
@testable import Audiyo

final class EnforcementGuardTests: XCTestCase {
    func testSuspendsAfterTooManyReassertionsInWindow() {
        var guardrail = EnforcementGuard()
        let now = Fixtures.baseDate

        XCTAssertNil(guardrail.recordReassertion(selector: .input, uid: Fixtures.soloCast.uid, at: now))
        XCTAssertNil(guardrail.recordReassertion(selector: .input, uid: Fixtures.soloCast.uid, at: now.addingTimeInterval(1)))
        XCTAssertNil(guardrail.recordReassertion(selector: .input, uid: Fixtures.soloCast.uid, at: now.addingTimeInterval(2)))

        let suspendedUntil = guardrail.recordReassertion(selector: .input, uid: Fixtures.soloCast.uid, at: now.addingTimeInterval(3))

        XCTAssertEqual(suspendedUntil, now.addingTimeInterval(33))
        XCTAssertTrue(guardrail.isSuspended(selector: .input, uid: Fixtures.soloCast.uid, at: now.addingTimeInterval(4)))
        XCTAssertEqual(guardrail.suspendedDefaults(at: now.addingTimeInterval(4))[.input], suspendedUntil)
    }

    func testOldAttemptsDoNotTripGuard() {
        var guardrail = EnforcementGuard()
        let now = Fixtures.baseDate

        XCTAssertNil(guardrail.recordReassertion(selector: .output, uid: Fixtures.accentumOutput.uid, at: now.addingTimeInterval(-30)))
        XCTAssertNil(guardrail.recordReassertion(selector: .output, uid: Fixtures.accentumOutput.uid, at: now))
        XCTAssertNil(guardrail.recordReassertion(selector: .output, uid: Fixtures.accentumOutput.uid, at: now.addingTimeInterval(1)))
        XCTAssertNil(guardrail.recordReassertion(selector: .output, uid: Fixtures.accentumOutput.uid, at: now.addingTimeInterval(2)))
    }
}
