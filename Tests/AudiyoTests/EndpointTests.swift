import XCTest
@testable import Audiyo

final class EndpointTests: XCTestCase {
    func testEndpointSortsByDirectionThenName() {
        let output = Endpoint(uid: "2", direction: .output, transport: .usb, name: "B", channels: 2, sampleRate: 48_000, isRunningSomewhere: false, deviceID: 2)
        let input = Endpoint(uid: "1", direction: .input, transport: .usb, name: "A", channels: 1, sampleRate: 48_000, isRunningSomewhere: false, deviceID: 1)

        XCTAssertEqual([output, input].sorted().map(\.uid), ["1", "2"])
    }
}
