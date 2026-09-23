import XCTest
@testable import Audiyo

final class ConfigStoreTests: XCTestCase {
    func testLoadReturnsEmptyConfigWhenFileDoesNotExist() throws {
        let store = ConfigStore(url: temporaryURL())

        XCTAssertEqual(try store.load(), PriorityConfig())
    }

    func testSaveAndLoadRoundTripsConfig() throws {
        let store = ConfigStore(url: temporaryURL())
        let config = PriorityConfig(
            input: [PriorityDevice(uid: "mic", name: "Mic", transport: .usb, mode: .automatic, lastSeen: Date(timeIntervalSince1970: 10))],
            output: [PriorityDevice(uid: "speaker", name: "Speaker", transport: .builtIn)],
            pinnedSystemOutputUID: "speaker"
        )

        try store.save(config)

        XCTAssertEqual(try store.load(), config)
    }

    func testDisplayFlagsDefaultToMenuBarUtilityMode() throws {
        let data = Data(#"{"version":1,"input":[],"output":[]}"#.utf8)
        let config = try JSONDecoder().decode(PriorityConfig.self, from: data)

        XCTAssertTrue(config.menuBarIconVisible)
        XCTAssertFalse(config.dockIconVisible)
    }

    func testForgettingDeviceClearsOnlyItsOutputAlertPin() {
        var config = PriorityConfig(pinnedSystemOutputUID: "alerts")

        config.remove(uid: "alerts", direction: .input)
        XCTAssertEqual(config.pinnedSystemOutputUID, "alerts")
        config.remove(uid: "other", direction: .output)
        XCTAssertEqual(config.pinnedSystemOutputUID, "alerts")
        config.remove(uid: "alerts", direction: .output)
        XCTAssertNil(config.pinnedSystemOutputUID)
    }

    func testDisplayFlagsKeepAtLeastOneControlSurfaceVisible() {
        var config = PriorityConfig()

        config.setMenuBarIconVisible(false)

        XCTAssertFalse(config.menuBarIconVisible)
        XCTAssertTrue(config.dockIconVisible)

        config.setDockIconVisible(false)

        XCTAssertTrue(config.menuBarIconVisible)
        XCTAssertFalse(config.dockIconVisible)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("config.json")
    }
}
