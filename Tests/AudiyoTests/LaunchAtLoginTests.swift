import XCTest
@testable import Audiyo

final class LaunchAtLoginTests: XCTestCase {
    func testStatusUnavailableWhenAppIsNotInstalledInApplications() {
        let status = LaunchAtLogin.resolve(serviceStatus: .enabled, isInstalledInApplications: false)

        XCTAssertEqual(status, .unavailable("Install Audiyo in /Applications before enabling Launch at Login."))
        XCTAssertFalse(status.isAvailable)
    }

    func testStatusMapsInstalledServiceStates() {
        XCTAssertEqual(LaunchAtLogin.resolve(serviceStatus: .enabled, isInstalledInApplications: true), .enabled)
        XCTAssertEqual(LaunchAtLogin.resolve(serviceStatus: .disabled, isInstalledInApplications: true), .disabled)
        XCTAssertEqual(LaunchAtLogin.resolve(serviceStatus: .requiresApproval, isInstalledInApplications: true), .requiresApproval)
        XCTAssertEqual(LaunchAtLogin.resolve(serviceStatus: .notFound, isInstalledInApplications: true), .disabled)
        XCTAssertEqual(LaunchAtLogin.resolve(serviceStatus: .unknown, isInstalledInApplications: true), .unavailable("Unknown login item status."))
    }

    func testInstalledNotFoundStatusIsToggleable() {
        let status = LaunchAtLogin.resolve(serviceStatus: .notFound, isInstalledInApplications: true)

        XCTAssertEqual(status, .disabled)
        XCTAssertTrue(status.isAvailable)
    }
}
