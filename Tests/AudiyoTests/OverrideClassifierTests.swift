import XCTest
@testable import Audiyo

final class OverrideClassifierTests: XCTestCase {
    private let classifier = OverrideClassifier()

    func testPendingSelfEventIsIgnored() {
        let now = Fixtures.baseDate
        let event = DefaultChangeEvent(selector: .input, endpoint: Fixtures.soloCast, occurredAt: now)
        let state = OverrideClassifierState(
            pendingSets: [
                PendingDefaultSet(selector: .input, deviceID: Fixtures.soloCast.deviceID, generation: 1, createdAt: now.addingTimeInterval(-0.5))
            ]
        )

        XCTAssertEqual(classifier.classify(event, state: state), .selfEvent)
    }

    func testNewlyAppearedDefaultIsMacOSAutoSwitch() {
        let now = Fixtures.baseDate
        let event = DefaultChangeEvent(selector: .input, endpoint: Fixtures.accentumInput, occurredAt: now)
        let state = OverrideClassifierState(appearedAtByUID: [Fixtures.accentumInput.uid: now.addingTimeInterval(-4)])

        XCTAssertEqual(classifier.classify(event, state: state), .macOSAutoSwitch)
    }

    func testRecentTopologyChangeIsMacOSAutoSwitch() {
        let now = Fixtures.baseDate
        let event = DefaultChangeEvent(selector: .output, endpoint: Fixtures.accentumOutput, occurredAt: now)
        let state = OverrideClassifierState(lastTopologyChangeAt: now.addingTimeInterval(-2))

        XCTAssertEqual(classifier.classify(event, state: state), .macOSAutoSwitch)
    }

    func testRecentWakeIsMacOSAutoSwitch() {
        let now = Fixtures.baseDate
        let event = DefaultChangeEvent(selector: .output, endpoint: Fixtures.accentumOutput, occurredAt: now)
        let state = OverrideClassifierState(lastWakeAt: now.addingTimeInterval(-9))

        XCTAssertEqual(classifier.classify(event, state: state), .macOSAutoSwitch)
    }

    func testOtherwiseHumanOverride() {
        let now = Fixtures.baseDate
        let event = DefaultChangeEvent(selector: .input, endpoint: Fixtures.builtInMic, occurredAt: now)

        XCTAssertEqual(
            classifier.classify(event, state: OverrideClassifierState()),
            .humanOverride(EndpointOverride(uid: Fixtures.builtInMic.uid, direction: .input))
        )
    }
}
