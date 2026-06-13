import XCTest
@testable import Audiyo

final class DiagnosticsReportTests: XCTestCase {
    func testRenderIncludesStatusDefaultsAndEndpoints() {
        let endpoint = Endpoint(
            uid: "speaker-uid",
            direction: .output,
            transport: .usb,
            name: "Desk Speakers",
            channels: 2,
            sampleRate: 48_000,
            deviceID: 42
        )
        var config = PriorityConfig(output: [
            PriorityDevice(uid: endpoint.uid, name: endpoint.name, transport: endpoint.transport)
        ])
        config.masterAutoEnabled = false
        config.notificationsEnabled = true
        config.alertOutputUID = endpoint.uid
        let report = DiagnosticsReport(
            generatedAt: Date(timeIntervalSince1970: 100),
            bundleURL: URL(fileURLWithPath: "/Applications/Audiyo.app"),
            appVersion: "0.1.0",
            buildNumber: "1",
            config: config,
            endpoints: [endpoint],
            defaultInputUID: nil,
            defaultOutputUID: endpoint.uid,
            defaultSystemOutputUID: endpoint.uid,
            recentSwitches: [],
            lastError: "none"
        ).render()

        XCTAssertTrue(report.contains("Audiyo Diagnostics"))
        XCTAssertTrue(report.contains("Version: 0.1.0 (1)"))
        XCTAssertTrue(report.contains("Bundle: /Applications/Audiyo.app"))
        XCTAssertTrue(report.contains("- Auto: disabled"))
        XCTAssertTrue(report.contains("- Notifications: enabled"))
        XCTAssertTrue(report.contains("- Output: speaker-uid"))
        XCTAssertTrue(report.contains("Desk Speakers"))
    }
}
