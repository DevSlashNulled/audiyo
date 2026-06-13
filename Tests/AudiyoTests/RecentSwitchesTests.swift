import XCTest
@testable import Audiyo

final class RecentSwitchesTests: XCTestCase {
    func testKeepsNewestEntriesWithinLimit() {
        var switches = RecentSwitches(limit: 2)

        switches.record(RecentSwitch(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, date: Date(timeIntervalSince1970: 1), direction: .input, fromUID: nil, toUID: "a", reason: "first"))
        switches.record(RecentSwitch(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, date: Date(timeIntervalSince1970: 2), direction: .input, fromUID: "a", toUID: "b", reason: "second"))
        switches.record(RecentSwitch(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, date: Date(timeIntervalSince1970: 3), direction: .output, fromUID: "b", toUID: "c", reason: "third"))

        XCTAssertEqual(switches.entries.map(\.toUID), ["c", "b"])
    }
}
